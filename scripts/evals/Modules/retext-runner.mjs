// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: MIT
//
// retext-runner.mjs
//
// Runs alex.js (inclusive-language linter) and retext-profanities against
// stimulus prompt text supplied via a JSON manifest on stdin. Emits a JSON
// report on stdout and exits with code 1 when any message is flagged.
//
// Manifest schema:
//   [{ "spec": "<rel-path>", "stimulus": "<name>", "text": "<prompt>" }, ...]
//
// Report schema:
//   { "results": [ { spec, stimulus, source, messages: [{rule, message, line, column}] } ] }

import { stdin as input, stdout as output, stderr } from 'node:process';
import { text as alexText } from 'alex';
import { unified } from 'unified';
import retextEnglish from 'retext-english';
import retextProfanities from 'retext-profanities';
import retextStringify from 'retext-stringify';

// Phrase-aware allowlist keyed by rule ID. When a rule fires, the ±60-char
// window around the match is tested against each regex. A match suppresses
// the message, so bare uses ("abuse") still flag while established technical
// bigrams ("token abuse", "penetration test") pass through.
const PHRASE_ALLOWLIST = {
    execution: [
        /\b(code|command|remote|arbitrary|script|query|task|job|pipeline|workflow|test|order|parallel|sequential|tool|function|program|process|step)[\s-]+execution\b/i,
        /\bexecution\s+(context|environment|order|mode|model|engine|plan|policy|time|path|trace|step|flow|phase)\b/i,
    ],
    execute: [
        /\b(can|may|will|to|cannot|must|shall|should|able\s+to|allowed\s+to|attempts?\s+to|tries\s+to)\s+execute\b/i,
        /\bexecute\s+(the|a|an|this|that|code|commands?|scripts?|queries|query|tests?|workflows?|steps?|actions?|tools?)\b/i,
    ],
    executes: [/\bexecutes?\s+(the|a|an|in|on|when|once|after|before|with|via|inside|against)\b/i],
    executed: [
        /\b(is|was|been|gets?|being|are|were)\s+executed\b/i,
        /\bexecuted\s+(by|in|on|when|with|via|against|successfully|inside)\b/i,
    ],
    attack: [/\battack\s+(surface|vector|tree|chain|path|pattern|scenario|model|simulation|graph)\b/i],
    attacks: [/\b(injection|replay|phishing|brute[- ]?force|dos|ddos|mitm|csrf|xss|sql|prompt|side[- ]?channel|timing|downgrade|impersonation)\s+attacks?\b/i],
    failure: [
        /\bfailure\s+(modes?|points?|rate|domain|recovery|handling|scenarios?|injection)\b/i,
        /\b(single\s+point\s+of|point\s+of|build|test|deployment|pipeline|silent|graceful|hardware|network|system|cascading|partial|validation)\s+failure\b/i,
    ],
    failures: [/\b(test|build|pipeline|deployment|validation|cascading|silent|partial|transient)\s+failures\b/i],
    failed: [
        /\b(test|build|step|job|request|attempt|validation|check|deployment|login|authentication)\s+failed\b/i,
        /\bfailed\s+(to|with|because|due|tests?|requests?|attempts?|jobs?|builds?|logins?)\b/i,
    ],
    abuse: [
        /\b(token|privilege|api|rate[- ]?limit|resource|trust|process|permission|credential|service|account|session|workflow|pipeline|cache|memory|tool|prompt|model|context|chain|insider|lateral|optimization|reservation|scalper|automated)[\s-]+abuse\b/i,
        /\bbusiness\s+logic\s+abuse\b/i,
        /\babuse\s+(of\s+)?(tokens?|privileges?|apis?|rate[- ]?limits?|resources?|trust|processes?|permissions?|credentials?|services?|accounts?|sessions?|tools?)\b/i,
        /\babuse\s+(prevention|scenarios?|the\s+\w+)\b/i,
        /\b(to|of|for|against|from|by|contain|prevent|reduce|stop|mitigate|deter|resist|combat|enable|enables|enabling|allow|allows|allowing|cause|causes|causing|make|makes|making|trigger|triggers|triggering|detect|detects|detecting|report|reports|reporting|monitor|monitors|monitoring|investigate|investigates|investigating|susceptible\s+to|vulnerable\s+to|prone\s+to|subject\s+to|protect\s+against|guard\s+against|safeguard\s+against|defend\s+against)\s+abuse\b/i,
    ],
    abuses: [/\babuses\s+(permissions?|trust|tokens?|credentials?|rate[- ]?limits?|access)\b/i],
    penetration: [
        /\bpen(etration)?[- ]?test(ing|er|ers|s)?\b/i,
        /\b(renewable|market|grid|water|gas|oil|broadband|internet|solar|wind)\s+penetration\b/i,
    ],
    invalid: [
        /\binvalid\s+(input|token|argument|arguments?|request|signature|state|format|payload|configuration|key|certificate|hash|json|yaml|xml|url|uri|path|response|reference|operation|character|syntax|schema|type|value|parameter|option|credential|claim|header|message|field|entry|record|file|user|session|cursor)\b/i,
    ],
    'host-hostess': [
        /\b(http|https|host|virtual|bastion|jump|docker|container|kubernetes|kube|vm|web|database|build|target|source|remote|local|origin|destination|build|runner|agent)\s+host\b/i,
        /\bhost\s+(header|name|names|file|key|machine|machines|os|process|system|environment|configuration|address|port|computer)\b/i,
    ],
    'hostesses-hosts': [
        /\bhosts?\s+(file|header|key|name|configuration|environment)\b/i,
        /\b(virtual|build|target|remote|local|allowed|trusted|known)\s+hosts\b/i,
    ],
    white: [
        /\bwhite[- ]?list(ed|ing|s)?\b/i,
        /\bwhite[- ]?paper\b/i,
        /\bwhite[- ]?box\b/i,
        /\bwhite[- ]?hat\b/i,
        /\bwhite[- ]?spac(e|es|ing)\b/i,
        /\bwhite\s+(background|text|fill|colou?r)\b/i,
        /\bblack[- ]?and[- ]?white\b/i,
        /\bplain\s+white\b/i,
        /\bWHITE\b/,
        /\btext\s+(is\s+)?white\b/i,
    ],
    premature: [/\bpremature\s+(optimization|optimisation|return|exit|termination|closure|abort|completion)\b/i],
    remains: [/\bremains?\s+(valid|stable|consistent|the\s+same|unchanged|active|available|open|closed|empty|in|at|on)\b/i],
    color: [
        /\b(syntax|terminal|theme|background|foreground|text|font|highlight|border|accent|primary|secondary|css|hex|rgb|rgba|hsl|ansi)\s+colou?rs?\b/i,
        /\bcolou?rs?\s+(scheme|theme|palette|code|codes|map|space|picker|wheel|value|values)\b/i,
    ],
    colors: [/\b(syntax|terminal|theme|background|foreground|text|font|highlight|border|accent|primary|secondary|css|hex|rgb|rgba|hsl|ansi)\s+colou?rs\b/i],
    period: [/\b(time|grace|trial|retention|warm[- ]?up|cool[- ]?down|warranty|notice|review|incubation|sampling|polling|wait|sleep|sla)\s+period\b/i],
    periods: [/\b(time|grace|trial|retention|sampling|polling)\s+periods\b/i],
    uk: [/\b(uk|u\.k\.)\s+(government|gov|english|spelling|date|locale|user|users|region|usage)\b/i],
    australian: [/\baustralian\s+(english|spelling|locale|date|user|users|region)\b/i],
    cracks: [
        /\b(password|hash|encryption|crypto|code)\s+crack(s|ing|ed|er)?\b/i,
        /\bcrack(s|ing|ed)?\s+(the\s+)?(password|hash|code|encryption|cipher)\b/i,
        /\bfall(s|ing)?\s+through\s+the\s+cracks\b/i,
    ],
    crack: [
        /\b(password|hash|encryption|crypto|code)\s+crack(s|ing|ed|er)?\b/i,
        /\b(guess|brute[- ]?force)\s+or\s+crack\b/i,
    ],
    threeway: [/\bthree[- ]?way\s+(handshake|merge|join|sync|comparison|matching|reconciliation)\b/i],
    black: [
        /\bblack[- ]?box\b/i,
        /\bblack[- ]?list(ed|ing|s)?\b/i,
        /\bblack[- ]?hat\b/i,
        /\bBlack\s+(formatter|format|compatible)\b/,
        /\bBlack\s+Friday\b/i,
    ],
    trap: [
        /\b(trap[- ]?door|trap\s+handler|trap\s+event|debug\s+trap|signal\s+trap|stack\s+trap|error\s+trap)\b/i,
        /\b(common|easy|classic|usual|interface|design|prompt|mockup|fidelity)\W+trap\b/i,
        /\b(keyboard|focus|tab|mouse|character[- ]key)\s+trap\b/i,
        /\bno\s+keyboard\s+trap\b/i,
        /\bfocus[- ]trap\b/i,
        /\btrap\s+(focus|pages?|the\s+user|zone)\b/i,
        /\b(break|order)\s+or\s+trap\b/i,
        /\bmaintenance\s+trap\b/i,
        /\|\s*Trap\s*\|/,
    ],
    traps: [
        /\b(keyboard|focus|tab|mouse|character[- ]key)\s+traps\b/i,
        /\btraps\s+(keyboard\s+)?focus\b/i,
    ],
    devils: [/\bdevil['\u2019]s\s+advocate\b/i],
    god: [/\bgod[- ]?(object|class(es)?|mode|method(s)?|node(s)?)\b/i],
    drug: [
        /\bdrug[- ]drug\b/i,
        /\bdrug\s+(data|dosage|administration|trial|interaction|safety|protocol|delivery|works?|for|provide|application|development|discovery|candidate|product|pricing|class|target|efficacy|approval|label|repurposing|substance|molecule|pipeline|formulation|company|maker|manufacturer|incentives?)\b/i,
        /\b(new|orphan|investigational|approved|existing|better|active|single[- ]pathway|generic|branded|prescription|specialty|biologic|small[- ]molecule|a|the|novel|psychiatric|oncology|cardiovascular)\s+drugs?\b/i,
    ],
    drugs: [
        /\b(new|orphan|investigational|approved|existing|better|active|single[- ]pathway|generic|branded|prescription|specialty|biologic|small[- ]molecule|the|novel|psychiatric|oncology|cardiovascular|of)\s+drugs\b/i,
        /\bdrugs\s+(already|exist|and|or|are|were|that|which|for|in|to)\b/i,
    ],
    sexual: [/\bsexual\s+(dysfunction|health|function|activity|behaviou?r|orientation|wellbeing|well[- ]being|side[- ]effects?)\b/i],
    gross: [/\bgross\s+(margin|profit|revenue|sales|income|weight|domestic|product|value|amount|booking|bookings)\b/i],
    fu: [/\bxin\s+fu\b/i],
    ass: [/\bAS['\u2019]s\b/],
};

const CONTEXT_RADIUS = 60;

function messageOffsets(message) {
    const place = message.place ?? message.position;
    const start = place?.start?.offset;
    const end = place?.end?.offset ?? start;
    return start == null ? null : { start, end };
}

function isAllowedByPhrase(message, text) {
    const patterns = PHRASE_ALLOWLIST[message.ruleId];
    if (!patterns || patterns.length === 0) {
        return false;
    }
    const offsets = messageOffsets(message);
    if (!offsets) {
        return false;
    }
    const windowStart = Math.max(0, offsets.start - CONTEXT_RADIUS);
    const windowEnd = Math.min(text.length, offsets.end + CONTEXT_RADIUS);
    const window = text.slice(windowStart, windowEnd);
    return patterns.some((re) => re.test(window));
}

async function readStdin() {
    let data = '';
    input.setEncoding('utf8');
    for await (const chunk of input) {
        data += chunk;
    }
    return data;
}

function normalizeMessage(message, source) {
    return {
        source,
        rule: message.ruleId ?? message.source ?? source,
        message: message.reason ?? String(message),
        line: message.line ?? null,
        column: message.column ?? null,
    };
}

async function runAlex(text) {
    const vfile = alexText(text);
    return (vfile.messages ?? [])
        .filter((m) => !isAllowedByPhrase(m, text))
        .map((m) => normalizeMessage(m, 'alex'));
}

const profanityProcessor = unified()
    .use(retextEnglish)
    .use(retextProfanities, { sureness: 1 })
    .use(retextStringify);

async function runProfanities(text) {
    const file = await profanityProcessor.process(text);
    return (file.messages ?? [])
        .filter((m) => !isAllowedByPhrase(m, text))
        .map((m) => normalizeMessage(m, 'retext-profanities'));
}

async function main() {
    const raw = await readStdin();
    if (!raw.trim()) {
        output.write(JSON.stringify({ results: [] }) + '\n');
        process.exitCode = 0;
        return;
    }

    let manifest;
    try {
        manifest = JSON.parse(raw);
    } catch (err) {
        stderr.write(`retext-runner: failed to parse manifest JSON — ${err.message}\n`);
        process.exitCode = 2;
        return;
    }

    if (!Array.isArray(manifest)) {
        stderr.write('retext-runner: manifest must be a JSON array\n');
        process.exitCode = 2;
        return;
    }

    const results = [];
    let flagged = 0;

    for (const item of manifest) {
        const spec = item?.spec ?? '<unknown>';
        const stimulus = item?.stimulus ?? '<unknown>';
        const text = typeof item?.text === 'string' ? item.text : '';
        if (!text.trim()) {
            continue;
        }

        const [alexMessages, profMessages] = await Promise.all([
            runAlex(text),
            runProfanities(text),
        ]);
        const messages = [...alexMessages, ...profMessages];
        if (messages.length > 0) {
            flagged += messages.length;
            results.push({ spec, stimulus, messages });
        }
    }

    output.write(JSON.stringify({ results }) + '\n');
    process.exitCode = flagged > 0 ? 1 : 0;
}

main().catch((err) => {
    stderr.write(`retext-runner: unexpected error — ${err.stack ?? err.message}\n`);
    process.exitCode = 2;
});
