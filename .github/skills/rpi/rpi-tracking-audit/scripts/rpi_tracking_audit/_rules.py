# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Rule table, vocabularies, and patterns for the RPI tracking audit.

Each rule names its title, severity, the control the remediation plan groups it under,
why it matters, what to verify, and the fix. The vocabularies mirror the RPI skill
templates and the rpi skill state contract that ship with this skill.
"""

from __future__ import annotations

import re
from typing import NamedTuple

TRACKING_DIR = ".copilot-tracking"
SESSIONS_AREA = "rpi-sessions"

SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2, "info": 3}
SEV_LABEL = {"high": "High", "medium": "Medium", "low": "Low", "info": "Info"}
LIST_CAP = 5
SECRET_HITS_CAP = 5
MAX_SCAN_DEPTH = 6
LONG_LINE = 2000
SLUG_MAX = 60

SKIP_DIRS = {
    ".git",
    "node_modules",
    ".venv",
    "venv",
    "dist",
    "build",
    "__pycache__",
    ".tox",
    ".mypy_cache",
    "out",
    "target",
}
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
DATE_DIR = re.compile(r"^\d{4}-\d{2}-\d{2}$")
# the RPI Workflow canvas reads a marker only when it fills its line and is written
# `id=`
MARKER = re.compile(
    r"<!--\s*rpi:(phase|task|critique|review)\s+id=([A-Za-z0-9-]+)\s*-->"
)
# a marker-shaped comment the canvas cannot read: spaces around `=`, or text beside it
MARKER_LOOSE = re.compile(
    r"<!--\s*rpi:(phase|task|critique|review)\s+id\s*=\s*([A-Za-z0-9-]+)\s*-->"
)
FENCE = re.compile(r"^(`{3,}|~{3,})(.*)$")
# C0 and C1 controls, the Unicode line separators, and the Unicode spaces (no-break,
# thin, ideographic, and the rest), which all become an ordinary space
CONTROL_CHARS = re.compile(
    "[\x00-\x08\x0b-\x1f\x7f-\x9f\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f"
    "\u3000]"
)
# a terminal control sequence, as in pasted coloured output: ESC [ parameters and a
# final letter. It is reduced to its ESC, which is then handled like any other control
ANSI_ESCAPE = re.compile("(?:\x1b\\[|\x9b)[0-?]{0,64}[ -/]{0,8}[A-HJKSTfhlmsu]")
# controls that are not white space of any kind. One inside a credential would leave
# two halves once it became a space, so the text is also scanned with them removed
HARD_CONTROLS = re.compile("[\x00-\x08\x0e-\x1b\x7f-\x84\x86-\x9f]")
# characters that take no space: the soft hyphen, zero-width space, joiners, word
# joiner, invisible operators, variation selectors, blank fillers, byte order mark, tag
# characters, and the bidirectional marks, overrides, and isolates that can reorder a
# line. They are removed, so a token split by one is whole
# again when it is redacted
INVISIBLE_CHARS = re.compile(
    "[\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180f\u200b-\u200f"
    "\u202a-\u202e\u2060-\u2064\u2066-\u206f\u2800\u3164\ufe00-\ufe0f\ufeff"
    "\uffa0\ufff9-\ufffb\U0001bca0-\U0001bca3\U0001d173-\U0001d17a"
    "\U000e0000-\U000e007f\U000e0100-\U000e01ef]"
)
# CommonMark pairs backtick runs by length; the report only ever pairs single ones
BACKTICK_RUN = re.compile(r"`{2,}")
HTML_TAG_START = re.compile(r"<(?=[A-Za-z/!?])")
# inside a code span only an element can matter; a quoted `<!-- marker -->` stays whole
CODE_TAG_START = re.compile(r"<(?=[A-Za-z/])")
ZERO_WIDTH_SPACE = "\u200b"


# a negation word up to three words before a value ("not yet ready"); a hyphen joins
# words only when unspaced, so "No findings - Pass" is not negated, and `non` negates
# only the word it is attached to, so "non-blocking clarification" is not negated
# a negation reaches the next few words and stops at a contrast: "not blocked but
# pending" leaves `pending` standing
def _negation_before(words: str, stops: str = "") -> re.Pattern[str]:
    return re.compile(
        r"(?:\b(?:" + words + r")\b|n['’]t\b)"
        r"(?:(?:\s+|-)(?!(?:but|while|until|once|except|though|although|however|and"
        + stops
        + r")\b)[\w'’]+){0,3}\s*$"
        r"|\bnon\s*$",
        re.I,
    )


NEGATION_BEFORE = _negation_before("no|not|never|cannot|without|nothing|none")
# "cannot be ready without the pending decision" names what is pending, and "no staging
# access so blocked" gives a reason, so review readiness is read more narrowly
READINESS_NEGATION = _negation_before("no|not|never|nothing|none", "|so|yet|still")
# a vocabulary word that is qualified away: "unable to complete", "partially complete"
QUALIFIED_BEFORE = re.compile(
    r"\b(?:unable to|fail(?:ed|s|ing)? to|yet to|could not|partially|partly|nearly"
    r"|almost|mostly|hardly|barely|half|far from|close to|to be)"
    r"(?:\s+(?:be|fully|completely|entirely|quite))?(?:\s+|-)$",
    re.I,
)
# a decision word that describes an earlier state: "accepted (was deferred in RD-001)"
SUPERSEDED_BEFORE = re.compile(
    r"(?:\((?:was|were)|\b(?:previously|formerly|originally|earlier))\s+"
    r"(?:[\w'’]+\s+)?$",
    re.I,
)
SURROGATES = re.compile("[\ud800-\udfff]")
PHASE_ID = re.compile(r"^P\d{2}$")
TASK_ID = re.compile(r"^P\d{2}-T\d{2}$")
ANY_PLAN_ID = re.compile(r"\bP\d{2}(?:-T\d{2})?\b")
TASK_ID_IN_TEXT = re.compile(r"\bP\d{2}-T\d{2}\b")
# closing hashes and trailing blanks are stripped in code: a pattern that does it
# backtracks
# cubically on long runs of spaces
HEADING = re.compile(r"^(#{1,6})[ \t]+(.*)$")
ID_HEADING = re.compile(
    r"^(#{2,6})\s+(?:\[( "
    r"|x|X)\]\s+)?((?:PC|RV)-\d{3}|P\d{2}(?:-T\d{2})?)\b(?:\s*\[([A-Za-z]+)\])?"
)
PLACEHOLDER = re.compile(r"\{\{[^{}\n]{0,200}\}\}")
LINE_REF_TOKEN = re.compile(
    r"^[\w./-]{1,200}\.(?:py|ts|tsx|js|md|cs|rs|go|java|yml|yaml|json|ps1|sh|bicep|tf)"
    r":\d+[,.;:)]*$",
    re.I,
)
LINE_REF_ANCHOR = re.compile(r"#L\d+\b")
LINE_REF_PHRASE = re.compile(r"\blines?\s+\d+(?:\s*(?:-|to)\s*\d+)?\b", re.I)
FILE_DIRECTIVE = re.compile(r"#file:")
LABEL_BLOCK = re.compile(
    r"^(Goals|Requirements|Details|Guidance|References|Dependencies)\s*:\s*$"
)
CHANGES_IN_MAP = re.compile(r"^Changes in the map\s*:", re.I)
BULLET_FIELD = re.compile(r"^\s*[*-]\s+([^:]+?)\s*:\s*(.*)$")
BOLD_WRAP = re.compile(r"(\*\*|__)")
MD_LINK = re.compile(r"\[([^\]\n]{0,500})\]\(([^)\s]{1,1000})\)")
REQ_DEF = re.compile(r"^[ \t]*[*-][ \t]+((?:N)?FR)-(\d{3})[ \t]*:", re.M)
REQ_CITE = re.compile(r"\b((?:N)?FR-\d{3})\b")
# a requirement cited from another document: `PRD-2026-004 FR-012 (docs/prd.md)`
EXTERNAL_REQ_CITE = re.compile(
    r"\[?\b(?:PRD|BRD|ADR)[ -][\w-]{1,40}\]?(?:\([^)\s]{1,300}\))?:?[ \t]+"
    r"(?:(?:N)?FR-\d{3}(?:[ \t]*(?:,|;|&|\band\b)[ \t]*)?)+",
    re.I,
)
PHASE_DIAGRAM = re.compile(
    r"^(?:`{3,}|~{3,})\s*mermaid\b|^\W{0,3}highlighted work\W", re.I
)
# Planning Decisions and Feedback statuses; the earliest one that is not negated counts
PLAN_DECISION_WORDS = re.compile(
    r"\b(confirmed|resolved|decided|accepted|proposed|unresolved|deferred"
    r"|input requested|needs input)\b",
    re.I,
)
PLAN_DECISION_OPEN = ("proposed", "unresolved", "input requested", "needs input")
# Decision History statuses by stem, most specific first; the first that is not negated
# names the decision
DECISION_STEMS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("skipped", re.compile(r"\bskip", re.I)),
    ("deferred", re.compile(r"\bdefer", re.I)),
    ("rejected", re.compile(r"\breject", re.I)),
    ("accepted", re.compile(r"\baccept", re.I)),
    ("changed", re.compile(r"\bchang", re.I)),
    ("resolved", re.compile(r"\b(?:resolv|fixed\b|closed\b)", re.I)),
)
# a status that records the item without deciding it
NOT_A_DECISION = re.compile(
    r"^\W*(?:pending|proposed|awaiting|undecided|open|tbd)\b", re.I
)
# a rejected row that records a walkthrough Skip in a later cell: the whole cell, or the
# word beside the walkthrough or the route; "the test is skipped on Windows" is not one
SKIP_NOTE = re.compile(
    r"^\W*skip(?:ped)?\W*$"
    r"|\bskip(?:ped)?\b[^.;|]{0,40}\b(?:walkthrough|route)\b"
    r"|\b(?:walkthrough|user chose|user selected)\b[^.;|]{0,40}\bskip(?:ped)?\b",
    re.I,
)
# a bullet that records nothing: `None`, `None - all cleared in P02`, `Not applicable`,
# `N/A`, `Nothing yet`, or `No blockers`; "No access to the staging database" and
# "None of the tests can run" are real entries, and so is "None, except the staging
# credential is missing"
EMPTY_BULLET = re.compile(
    r"^(?:none(?:\s+(?:yet|recorded|identified|found|remaining|so far))?"
    # after punctuation, only a closing remark with no second clause
    r"(?:\s*[.!;:,(\u2013\u2014-]\s*(?:(?:all\s+)?(?:(?:were|was|are|is|been)\s+)?"
    r"(?:cleared|resolved|closed|done|fixed|addressed|completed|removed)"
    r"(?:\s+(?:in|by|on|during|with|at|after|before)\s+[\w./#-]+(?:\s+[\w./#-]+){0,3})?"
    r"|n/a|not applicable|yet|so far|ready for review)\s*[.!)]*|[.!]?)"
    r"|(?:not applicable|n/a|nothing(?:\s+(?:yet|recorded|remaining|pending))?"
    # any one or two describing words, but not a phrase such as "reply on"
    r"|no\s+(?:(?!(?:on|for|to|from|with|about|in|of|at|by|until|before|after)\b)"
    r"[\w/-]+\s+){0,2}(?:blockers?|issues?|items?|follow-ups?|work|changes"
    r"|findings|questions|risks|gaps|concerns)"
    r"(?:\s+\(?(?:yet|recorded|identified|found|remaining|remain|so far)\)?)?)[.!]?)$",
    re.I,
)
# the readiness line says review must wait: not ready, blocked, pending, or ready only
# on a condition
REVIEW_BLOCKED = re.compile(
    r"\bnot\s+(?:yet\s+|quite\s+)?ready\b|n['\u2019]t\s+(?:yet\s+|quite\s+)?ready\b"
    r"|\b(?:nearly|almost)\s+ready\b|\bblocked\b|\bpending\b"
    r"|\bready\b[^.;]{0,80}?\b(?:once|when|after|if|unless|until|waiting|awaiting)\b",
    re.I,
)
DESTINATION_VARIANT = re.compile(
    r"\b(rpi|follow)[_ ](implement|plan|research|up)\b", re.I
)
EVIDENCE_DEF = re.compile(r"^\|?[ \t]*([CW]\d+)[ \t]*\|", re.M)
EVIDENCE_CITE = re.compile(r"\b([CW]\d+)\b")
EVIDENCE_LINE = re.compile(r"^\s*[*-]\s+(?:\*\*)?Evidence(?:\*\*)?\s*:", re.I)
EVIDENCE_CELL = re.compile(r"^[CW]\d+(?:\s*[,;]\s*[CW]\d+)*$")
RV_ID = re.compile(r"\bRV-\d{3}\b")
PC_ID = re.compile(r"\bPC-\d{3}\b")
RD_ID = re.compile(r"\bRD-\d{3}\b")
CHECKBOX = re.compile(r"^[ \t]*(?:[*-]|#{2,6})[ \t]+\[( |x|X)\]\s", re.M)
TABLE_SEP = re.compile(r"^:?-+:?$")

# a value that documentation writes in place of a password: `<password>`,
# `{your_password}`, `$DB_PASSWORD`, `PERSONAL_ACCESS_TOKEN`, `password`, `changeme`,
# `********`. A real password may start with `$` or `<`, so the whole value is tested
_NOT_PLACEHOLDER = (
    r"(?!(?:<[^>\s]{0,60}>|\{\{?[^}\s]{0,60}\}?\}|\$\{[^}\s]{0,60}\}|\$[A-Za-z_]{1,60}"
    r"|\$(?-i:[A-Z_][A-Z0-9_]{0,60})"
    r"|%[A-Za-z_]\w{0,60}%|\[[^\]\s]{0,60}\]|(?-i:[A-Z][A-Z_]{2,60})"
    # an identifier such as FR-001, a rule such as 12-character, a date or timestamp
    r"|(?-i:[A-Z]{1,8}-\d{1,6})|(?-i:\d{1,3}-[a-z]{2,}(?:-[a-z]{2,}){0,4})"
    r"|\d{4}-\d{2}-\d{2}(?:T[\d:.]{0,20}(?:Z|[+-]\d{2}:?\d{2})?)?"
    # a reference in code: self.config.password2, settings.db_password1
    r"|(?:self|this|config|cfg|conf|settings|env|os|process|secrets|vars|params"
    r"|options|args|ctx|context|request|req|app)(?:\.[A-Za-z_]\w{0,60}){1,6}"
    r"|[A-Za-z_]\w{0,60}(?:\.[A-Za-z_]\w{0,60}){2,6}"
    r"|(?:your|my|the|db)?[_-]?(?:password|passwd|pass|pwd|secret)"
    r"|changeme|required|redacted|example|x{3,}|\*{3,}|\.{3,})(?:[;@\"'`\s),(]|$))"
)
# `=` or `:` between a label and its value, with any Markdown bold marks around it
_ASSIGN = r"\*{0,2}[ \t]*[=:]\*{0,2}[ \t]*"
_SECRET_WORD = (
    r"(?:pat|token|password|passwd|secret|api[_ -]?key|client[_ -]?secret"
    r"|access[_ -]?key)"
)
PRIVATE_KEY_BEGIN = re.compile(
    r"-----BEGIN (?:(?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY"
    r"|PGP PRIVATE KEY BLOCK)-----"
)
SECRET_PATTERNS = (
    (
        "AWS access key",
        re.compile(r"(?<![A-Za-z0-9])(?:AKIA|ASIA)[0-9A-Z]{16}(?![A-Za-z0-9])"),
    ),
    (
        "GitHub token",
        # the body stops where another token starts, so two in a row are both found
        re.compile(r"(?:gh[pousr]_(?:(?!gh[pousr]_)[A-Za-z0-9]){36,})+(?![A-Za-z0-9])"),
    ),
    (
        "GitHub fine-grained token",
        re.compile(r"github_pat_[A-Za-z0-9_]{60,}(?![A-Za-z0-9])"),
    ),
    ("private key block", PRIVATE_KEY_BEGIN),
    (
        "Slack token",
        re.compile(r"(?<![A-Za-z0-9])xox[abprs]-[A-Za-z0-9-]{10,}(?![A-Za-z0-9])"),
    ),
    (
        "JSON web token",
        re.compile(
            r"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{0,60}?eyJ[A-Za-z0-9_-]{10,}\."
            r"(?:eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*"
            r"|[A-Za-z0-9_-]{10,}(?:\.[A-Za-z0-9_-]{10,}){3})"
        ),
    ),
    (
        # the token has a digit, is not a path or a placeholder, and stops before
        # another `Bearer`, so two in a row are both found
        "bearer token",
        re.compile(
            r"(?i)Bearer[ \t]+(?!/)"
            + _NOT_PLACEHOLDER
            + r"(?=[A-Za-z0-9._~+/-]{0,400}\d)"
            r"(?:(?!Bearer[ \t])[A-Za-z0-9._~+/-]){20,}=*"
        ),
    ),
    ("Azure storage account key", re.compile(r"(?i)\bAccountKey=[A-Za-z0-9+/]{20,}=*")),
    (
        "shared access signature",
        re.compile(r"(?i)\b(?:SharedAccessSignature|sig)=[A-Za-z0-9%+/]{20,}=*"),
    ),
    (
        "quoted token or password assignment",
        re.compile(
            r"(?i)(?<![\w-])[\w-]{0,40}?"
            + _SECRET_WORD
            + _ASSIGN
            + r"['\"][A-Za-z0-9+/_.~\-]{20,}['\"]"
        ),
    ),
    (
        "token or password assignment",
        re.compile(
            r"(?i)(?<![\w-])[\w-]{0,40}?"
            + _SECRET_WORD
            + _ASSIGN
            + r"`?(?!/|~/|\.{1,2}/)"
            r"(?=[A-Za-z0-9+/_.~\-]{0,200}\d)(?=[A-Za-z0-9+/_.~\-]{0,200}[A-Za-z])"
            r"[A-Za-z0-9+/_.~\-]{24,}"
        ),
    ),
    (
        # `Password=...;` in a connection string, `password=...` in a keyword list or an
        # environment file, `DB password: ...` in notes. The value has a letter and a
        # digit, ends at a separator, and is not a call or a path
        "password assignment",
        re.compile(
            # not a variable's default, `${DB_PASSWORD:-x}`, and `pwd` before a folder
            # name without digits, as in `pwd: src/auth`, is the working folder
            r"(?i)(?<![\w-])(?<!\$\{)[\w-]{0,40}?"
            r"(?:password|passwd|pwd(?![ \t]*[=:][ \t]*[A-Za-z_.-]{1,60}/))"
            # `=`, `:`, or the space after a `--password` option, then an opening quote
            r"(?:"
            + _ASSIGN
            + r"|(?<=--password)[ \t]+)[\"'`]?"
            + _NOT_PLACEHOLDER
            + r"(?!/|~/|\.{1,2}/)(?=[^;\s\"'(`]{0,256}\d)(?=[^;\s\"'(`]{0,256}[A-Za-z])"
            r"[^;\s\"'(`]{8,256}(?=[;\s\"'\])>,<`|]|$)"
        ),
    ),
    (
        # scheme://user:password@host, where the password has a letter and a digit; a
        # port, a placeholder, a path, or a query is not one
        "URL with embedded password",
        re.compile(
            # `:__` is what `://` becomes in a file name
            r"(?i):(?://|__)(?:[^\s:/@?#]{0,100}:"
            + _NOT_PLACEHOLDER
            + r"(?:(?=[^\s/@?#]{0,200}\d)(?=[^\s/@?#]{0,200}[A-Za-z])[^\s/@?#]{8,200}"
            # or a long number
            r"|\d{8,200})"
            # a token alone in the user part, as in a clone URL; a name made of
            # several hyphenated words, such as a storage bucket, is not one
            r"|(?=[A-Za-z0-9_-]{0,200}\d)(?=[A-Za-z0-9_-]{0,200}[A-Za-z])"
            r"(?![A-Za-z0-9_]{0,200}-[A-Za-z0-9_]{0,200}-)[A-Za-z0-9_-]{24,200})@"
        ),
    ),
    (
        "quoted key token or password (JSON)",
        re.compile(
            r"(?i)\"[\w-]{0,60}"
            + _SECRET_WORD
            + r"\"[ \t]*:[ \t]*\"[A-Za-z0-9+/_.~\-]{20,}\""
        ),
    ),
)
# key names whose string values are replaced whole: camelCase, snake_case, and
# kebab-case
SECRET_KEY = re.compile(
    r"(?i)(?:^|[_-])pat$|token|secret|passw|api[_-]?key|private[_-]?key|access[_-]?key"
    r"|credential|conn(?:ection)?[_-]?str|signature"
)
PRIVATE_KEY_END = re.compile(r"-----END [A-Z ]{0,20}PRIVATE KEY(?: BLOCK)?-----")
# an END line further away than this belongs to something else, such as a second mention
PRIVATE_KEY_SPAN = 20_000
# the key material after a BEGIN line that has no END line: optional armor headers, then
# runs of base64 or base64url text joined by whitespace, quote marks, or escaped
# newlines
PRIVATE_KEY_TAIL = re.compile(
    r"(?:(?:\s|>|\\n|<br>)*(?:Proc-Type|DEK-Info|Comment|Version):[^\n]{0,200})*"
    r"(?:(?:\s|>|\\n|<br>)*(?:(?!-----)[A-Za-z0-9+/=_-]){16,})*"
)

# area -> (kind, file name pattern)
AREAS: dict[str, tuple[str, re.Pattern[str]]] = {
    "research": ("research", re.compile(r"^(?P<slug>.+?)-research\.md$")),
    "plans": ("plan", re.compile(r"^(?P<slug>.+?)-plan\.md$")),
    "reviews/plans": (
        "critique",
        re.compile(r"^(?P<slug>.+?)-plan-critique(?:-(?P<n>\d+))?\.md$"),
    ),
    "changes": ("changes", re.compile(r"^(?P<slug>.+?)-changes\.md$")),
    "reviews/logs": (
        "review",
        re.compile(r"^(?P<slug>.+?)-review(?:-(?P<n>\d+))?\.md$"),
    ),
    "challenges": ("challenge", re.compile(r"^(?P<slug>.+?)-challenge\.md$")),
    "walkthroughs": ("walkthrough", re.compile(r"^(?P<slug>.+?)-decisions\.md$")),
}
# Retired Task Planner layout: area -> (subkind, file name pattern)
LEGACY_AREAS: dict[str, tuple[str, re.Pattern[str]]] = {
    "research/subagents": (
        "subagent research",
        re.compile(r"^(?P<slug>.+?)-research\.md$"),
    ),
    "plans/logs": ("planning log", re.compile(r"^(?P<slug>.+?)-log\.md$")),
    "details": ("implementation details", re.compile(r"^(?P<slug>.+?)-details\.md$")),
    "reviews/rpi": (
        "validation output",
        re.compile(r"^(?P<slug>.+?)(?:-plan)?-\d{3}-validation\.md$"),
    ),
    "reviews": ("review log", re.compile(r"^(?P<slug>.+?)(?:-plan)?-review\.md$")),
}
# files other hve-core skills and agents write into the RPI areas: pattern on the path
# below .copilot-tracking/, and the key they are counted under in the other-areas list
OTHER_OWNER_FILES: tuple[tuple[re.Pattern[str], str], ...] = (
    (
        re.compile(r"^research/[^/]+-research-topic\.md$"),
        "research/*-research-topic.md",
    ),
    (
        re.compile(r"^research/subagents/(?:[^/]+/)?[^/]+-mcsb\.md$"),
        "research/subagents/*-mcsb.md",
    ),
    (
        re.compile(r"^plans/\d{4}-\d{2}-\d{2}-network-isa95-assessment\.md$"),
        "plans/*-network-isa95-assessment.md",
    ),
)
LEGACY_PLAN = re.compile(r"^(?P<slug>.+?)-plan\.instructions\.md$")
LEGACY_HINTS = (
    "## Implementation Checklist",
    "Implementation Phase ",
    "<!-- parallelizable",
    "## Context Summary",
    "## Objectives",
    "-plan.instructions.md",
    ".copilot-tracking/details/",
)
LEGACY_DISTINCTIVE = {
    "research": ("Planning Readiness and Next Step", "Research Record"),
    "changes": ("Execution Status", "Return-to-Caller State", "Completed Work"),
}
STATE_FILE = re.compile(r"^(?P<slug>.+?)-state\.json$")

KIND_ORDER = [
    "research",
    "plan",
    "critique",
    "changes",
    "review",
    "challenge",
    "walkthrough",
]
KIND_LABEL = {
    "research": "research",
    "plan": "plan",
    "critique": "plan critique",
    "changes": "changes record",
    "review": "review record",
    "challenge": "challenge session",
    "walkthrough": "decisions-and-changes ledger",
}
SUFFIX_BY_KIND = {
    "research": "-research.md",
    "plan": "-plan.md",
    "critique": "-plan-critique.md",
    "changes": "-changes.md",
    "review": "-review.md",
    "challenge": "-challenge.md",
    "walkthrough": "-decisions.md",
}
# a later work reuses earlier research, so the newest kind decides which task a state
# tracks
STATE_JOIN_ORDER = ("review", "changes", "critique", "plan", "research")
STATE_CONTRACT_FIELDS = (
    "task_id",
    "task_slug",
    "session_name",
    "parent_task",
    "child_tasks",
    "mode",
    "active_phase",
    "status",
    "session_status",
    "artifact_paths",
    "documents",
    "confirmed_decisions",
    "blockers",
    "next_action",
    "prioritized_follow_ups",
)
MAX_STATE_BYTES = 5_000_000
KNOWN_OTHER_AREAS = {
    "hve-builder": "HVE Builder stage evidence",
    "proposal-responses": "proposal-response evidence",
    "prompts": "prompt tracking",
    "research/*-research-topic.md": "dt-rpi-integration skill handoffs",
    "research/subagents/*-mcsb.md": "mcsb skill",
    "plans/*-network-isa95-assessment.md": "Network ISA-95 Planner",
    "architecture-diagrams": "architecture-diagrams skill",
    "mural": "mural skill",
    "performance-plans": "performance-slo-planner skill",
    "quality": "requirements-author quality reports",
    "security-audits": "security-planning skill",
    "reviews/code-reviews": "Code Review agent reports",
    "reviews/architecture": "architecture-review skill",
    "rpi-sessions": "RPI session state",
    "security-plans": "Security Planner",
    "security": "Security Reviewer",
    "sssc-plans": "SSSC Planner",
    "sssc-reviews": "SSSC Reviewer",
    "privacy-plans": "Privacy Planner",
    "privacy-reviews": "Privacy Reviewer",
    "accessibility": "Accessibility Planner and Reviewer",
    "rai-plans": "RAI Planner",
    "rai-reviews": "RAI Reviewer",
    "adr-plans": "ADR Creator",
    "prd-sessions": "PRD Builder",
    "brd-sessions": "BRD Builder",
    "workitems": "Functional Planner and Backlog Manager",
    "github-issues": "Backlog Manager",
    "jira-issues": "Backlog Manager",
    "dt": "DT Coach",
    "ux-artifacts": "ux-artifacts skill",
    "ux-coaching": "ux-coaching skill",
    "ds": "Data Science and Engineering Coach",
    "mve": "Experiment Designer",
    "ppt": "PowerPoint Builder (retired)",
    "demo-material": "HVE Demo Material Builder",
    "pr": "pull-request skill",
    "documentation": "Documentation agent",
}

PLAN_READINESS = ("Not ready", "Not applicable", "Ready", "Blocked")
EXECUTION = ("Complete", "Partial", "Blocked")
STARTED = "started"
CRITIQUE_EXECUTION = (*EXECUTION, "Not produced", STARTED)
REVIEW_EXECUTION = (*EXECUTION, STARTED)
OUTCOMES = (
    "Conformant with justified divergence",
    "Conformant",
    "Defects found",
    "Residual work",
    "Not accepted",
)
VERDICTS = ("Pass", "Revise", "Blocked", "unavailable")
DESTINATIONS = ("rpi-implement", "rpi-plan", "rpi-research", "follow-up")
RESEARCH_DISPOSITIONS = ("executed", "reused", "satisfied-and-skipped")
ALIGNMENT_VALUES = (
    "clarification",
    "divergence-confirmed",
    "source-gap",
    "pending-decision",
)
PLAN_REQUIRED_SECTIONS = (
    "Task Metadata",
    "Executive Summary",
    "Phase Checklist",
    "User Decisions and Requirements",
    "Planning Readiness and Next Step",
    "Critique Disposition",
    "Artifact Self-Check",
    "Follow-Up Items",
    "Handoff",
)
CHANGES_REQUIRED_SECTIONS = (
    "Metadata",
    "Execution Status",
    "Completed Work",
    "Validation Record",
    "Return-to-Caller State",
)
REVIEW_REQUIRED_SECTIONS = (
    "Executive Summary",
    "Findings and Proposed Routes",
    "Parent Decision Record",
    "Review Record",
)
RESEARCH_REQUIRED_SECTIONS = (
    "Executive Summary",
    "Findings",
    "Planning Readiness and Next Step",
    "Research Record",
)
CRITIQUE_REQUIRED_SECTIONS = (
    "Metadata",
    "Verdict",
    "Findings",
    "Recommended Next Action",
)
REQUIRED_BY_KIND = {
    "plan": PLAN_REQUIRED_SECTIONS,
    "changes": CHANGES_REQUIRED_SECTIONS,
    "review": REVIEW_REQUIRED_SECTIONS,
    "research": RESEARCH_REQUIRED_SECTIONS,
    "critique": CRITIQUE_REQUIRED_SECTIONS,
}
STATE_FIELDS = {"task_slug", "active_phase", "artifact_paths"}
PHASES = ("Research", "Plan", "Implement", "Review", "Follow-up")


class Rule(NamedTuple):
    """One audit rule as listed in references/rule-catalog.md."""

    title: str
    severity: str
    control: str
    why: str
    verify: str
    fix: str


LAYOUT = "Folder layout"
TEMPLATE = "Template completion"
MARKERS = "Plan markers and headings"
EVIDENCE = "Completion evidence"
LINKS = "Cross-artifact links"
GATES = "Decisions and gates"
STATE = "Session state"
SECRETS = "Secrets"

RULES: dict[str, Rule] = {
    # Layout
    "LY1": Rule(
        "Tracking folder not git-ignored",
        "medium",
        LAYOUT,
        "tracking artifacts can be committed, and the hve-core install guide tells you "
        "to add the ignore line for every install route",
        "the root .gitignore",
        "add a `.copilot-tracking/` line to the root .gitignore",
    ),
    "LY2": Rule(
        "Tracking folder below the workspace root",
        "medium",
        LAYOUT,
        "the RPI skills look for .copilot-tracking/ at the codebase root and do not "
        "find or "
        "resume from a nested one; the audit lists a nested folder and does not read "
        "it",
        "the nested folder's path",
        "move the artifacts to the root .copilot-tracking/ and keep one folder",
    ),
    "LY3": Rule(
        "Artifact not directly under a YYYY-MM-DD folder of its area",
        "low",
        LAYOUT,
        "artifacts are addressed by date folder; a different shape is not found by the "
        "documented paths",
        "the folder path",
        "move the file to {area}/{YYYY-MM-DD}/",
    ),
    "LY4": Rule(
        "File name does not match the area's convention",
        "low",
        LAYOUT,
        "the skills resolve `{slug}-plan.md`, `{slug}-changes.md`, and the other "
        "documented "
        "names; anything else is invisible to them and is not modeled by this audit",
        "the file name against the area",
        "rename to the documented suffix for the area",
    ),
    "LY5": Rule(
        "Task slug is not lower-kebab-case or exceeds 60 characters",
        "low",
        LAYOUT,
        "the slug names every tracking file and is reused in every command; other "
        "characters "
        "break the match, and the 60-character cap keeps paths within Windows path "
        "limits",
        "the slug",
        "rename the artifacts of the task to one lower-kebab-case slug of at most 60 "
        "characters",
    ),
    "LY6": Rule(
        "Generated artifact does not start with the markdownlint disable comment",
        "info",
        TEMPLATE,
        "the tracking convention exempts generated tracking Markdown from lint through "
        "this "
        "first line",
        "line 1 of the file",
        "no action unless the repository lints tracking files",
    ),
    "LY7": Rule(
        "Line-number reference in a tracking artifact",
        "low",
        TEMPLATE,
        "tracking artifacts are navigated by IDs, markers, and headings; line numbers "
        "go stale "
        "on the first edit",
        "the quoted text",
        "replace with a path plus heading or symbol",
    ),
    "LY8": Rule(
        "#file: directive in a tracking artifact",
        "low",
        TEMPLATE,
        "the tracking convention forbids #file: directives in generated tracking "
        "Markdown",
        "the quoted text",
        "use a plain path or a Markdown link",
    ),
    "LY9": Rule(
        "Artifact in the retired Task Planner format",
        "info",
        LAYOUT,
        "written by the retired Task Researcher, Task Planner, Task Implementor, or "
        "Task "
        "Reviewer agents; the current RPI skills do not read this layout, and no "
        "converter exists",
        "the file and the hve-core version that wrote it",
        "re-plan with `/rpi-plan task=<slug> draft=<old plan path>`, citing the old "
        "research and "
        "changes as context",
    ),
    "LY10": Rule(
        "Empty, unreadable, or unrecognized artifact",
        "medium",
        TEMPLATE,
        "the file carries none of the sections the current RPI skills write and read, "
        "so no "
        "phase can resume from it",
        "the file",
        "recreate it from the phase skill, or remove it if it is scratch",
    ),
    # Plan
    "PL1": Rule(
        "Phase or task marker has no matching heading",
        "high",
        MARKERS,
        "rpi-implement navigates the plan by marker; a marker that does not precede "
        "its heading "
        "leaves the item unreachable or mis-attributed",
        "the marker line and the next heading",
        "place `<!-- rpi:task id=Pxx-Txx -->` immediately before `#### [ ] Pxx-Txx: "
        "...`",
    ),
    "PL2": Rule(
        "Phase or task heading has no marker",
        "medium",
        MARKERS,
        "the item is readable, but `/rpi-implement` navigates a plan by its markers "
        "and has only the heading to find this one by",
        "the heading",
        "add the marker on the line before the heading",
    ),
    "PL3": Rule(
        "Duplicate phase or task ID",
        "high",
        MARKERS,
        "implementation and review cannot tell which item a marker, changes entry, or "
        "command "
        "refers to",
        "both headings",
        "renumber one item and reconcile the changes record and review",
    ),
    "PL4": Rule(
        "Task ID does not belong to its enclosing phase",
        "medium",
        MARKERS,
        "the task is counted under one phase and numbered for another; phase "
        "completion rules "
        "misfire",
        "the task heading and the phase above it",
        "renumber the task to its phase prefix or move it",
    ),
    "PL5": Rule(
        "Phase checked while one of its tasks is unchecked",
        "medium",
        EVIDENCE,
        "rpi-implement checks a phase only when every task in it is checked; a resume "
        "reads the "
        "phase as done and skips the task",
        "the phase heading and its task headings",
        "uncheck the phase or finish and check the task",
    ),
    "PL6": Rule(
        "Task checked without a changes-record entry",
        "medium",
        EVIDENCE,
        "completion is the checked marker plus the changes record; a checked task with "
        "no entry "
        "has no evidence of what changed or whether validation ran",
        "the changes record for the task",
        "add the completed-work entry naming the task, or uncheck it",
    ),
    "PL7": Rule(
        "Task block missing a labeled block",
        "low",
        TEMPLATE,
        "every task carries Goals, Requirements, Details, References, and "
        "Dependencies; the "
        "implementer and critique read those blocks",
        "the task body",
        "add the missing block, even as `* none`",
    ),
    "PL8": Rule(
        "Phase block missing Goals, Dependencies, or Changes in the map",
        "low",
        TEMPLATE,
        "phase order and dependency readiness are read from these blocks, and the plan "
        "self-check requires a `Changes in the map:` line on every phase",
        "the phase body",
        "add the block or line",
    ),
    "PL9": Rule(
        "Unfilled template placeholder",
        "medium",
        TEMPLATE,
        "a `{{placeholder}}` left in a handoff artifact is read by the next phase as "
        "content; in "
        "a plan it reaches the implementer",
        "the quoted placeholder",
        "fill or delete the placeholder",
    ),
    "PL10": Rule(
        "Required section missing",
        "low",
        TEMPLATE,
        "the phase skills read fixed sections (readiness, critique disposition, "
        "follow-up items, "
        "handoff, decision record)",
        "the heading list",
        "add the section from the phase skill's template",
    ),
    "PL11": Rule(
        "Follow-Up Items not immediately before Handoff",
        "low",
        TEMPLATE,
        "the planning reference fixes this position so implementation-time discoveries "
        "are found",
        "the last two H2 headings",
        "move `## Follow-Up Items` directly before `## Handoff`",
    ),
    "PL12": Rule(
        "Requirement not cited by any task",
        "low",
        GATES,
        "the plan self-check requires every FR-nnn and NFR-nnn to be cited by a task's "
        "Requirements block, otherwise nothing implements it",
        "the task Requirements blocks",
        "cite it in the task that satisfies it, or remove it",
    ),
    "PL13": Rule(
        "Task cites a requirement the plan does not define",
        "low",
        GATES,
        "the critique and review compare tasks against the requirement catalog; an "
        "undefined ID "
        "cannot be checked",
        "the Functional and Non-Functional Requirements sections",
        "define the requirement or fix the citation",
    ),
    "PL14": Rule(
        "Critique recorded in the plan but no critique file found",
        "medium",
        LINKS,
        "the plan claims a critique result that cannot be read; readiness may rest on "
        "it",
        "the reviews/plans folder for the task",
        "restore the critique, correct the path, or record `skipped` with provenance",
    ),
    "PL15": Rule(
        "Planning Readiness is Ready without a critique result or an explicit skip",
        "medium",
        GATES,
        "a critique that returned no result is never a Pass, so readiness stays Not "
        "ready until "
        "a result exists or the critique is skipped",
        "Critique Disposition and the critique file",
        "run `/rpi-plan task=<slug>` so the planner runs the critique and records its "
        "result, or `/rpi-plan task=<slug> critique=skip` to record the skip",
    ),
    "PL16": Rule(
        "Open planning decision",
        "info",
        GATES,
        "a decision with status proposed, unresolved, or input requested blocks the "
        "tasks it "
        "names; a deferred decision is listed and does not block",
        "the Planning Decisions and Feedback table",
        "resolve it before implementing the affected tasks",
    ),
    "PL17": Rule(
        "Task slug in the plan differs from the file name",
        "low",
        LINKS,
        "the slug is the join key across research, critique, changes, and review",
        "Task Metadata",
        "align the metadata and the file name",
    ),
    "PL18": Rule(
        "Critique finding without a disposition in the plan",
        "medium",
        GATES,
        "the plan disposes of every PC-xxx (resolved, superseded, accepted with risk, "
        "or open); "
        "an undisposed finding is unresolved critique input",
        "the Critique Disposition table",
        "add the row with the disposition and the resolving evidence",
    ),
    "PL19": Rule(
        "Plan marked Not ready or Blocked",
        "info",
        GATES,
        "implementation confirms with the user before acting on affected tasks",
        "Planning Readiness and Next Step",
        "clear the blocker named there",
    ),
    # Critique
    "PC1": Rule(
        "Critique finding marker and heading disagree or repeat",
        "medium",
        MARKERS,
        "the plan's Critique Disposition keys on PC-xxx; a repeated or unmarked ID "
        "cannot be "
        "disposed",
        "the Findings section",
        "give every finding one `<!-- rpi:critique id=PC-xxx -->` marker and heading",
    ),
    "PC2": Rule(
        "Critique verdict missing or outside Pass, Revise, Blocked, unavailable",
        "medium",
        GATES,
        "the planner reads the verdict to set readiness",
        "the Verdict section",
        "record one of the four values",
    ),
    "PC3": Rule(
        "Critique points at a plan file that does not exist",
        "medium",
        LINKS,
        "the critique cannot be matched to its plan on resume",
        "the Metadata Plan line",
        "correct the path",
    ),
    "PC4": Rule(
        "Follow-up critique without Earlier Finding Reconciliation",
        "low",
        TEMPLATE,
        "a numbered follow-up marks each earlier finding resolved, still open, or "
        "superseded",
        "the section list",
        "add the reconciliation table",
    ),
    "PC5": Rule(
        "Critique execution missing or outside started, Complete, Partial, Blocked, "
        "Not produced",
        "low",
        TEMPLATE,
        "execution is recorded apart from the verdict; a missing value hides an "
        "interrupted run",
        "the Metadata Critique execution line",
        "record the execution status",
    ),
    "PC6": Rule(
        "Critique started and not finished",
        "info",
        GATES,
        "the critique record is written before the first lens runs and leaves "
        "`started` only "
        "when complete; a record still `started` is running or was interrupted",
        "the Lens Assessments table and the Metadata Critique execution line",
        "let the running critique finish, or rerun it through `/rpi-plan task=<slug>`",
    ),
    # Changes
    "CH1": Rule(
        "Changes record names a task the plan does not define",
        "medium",
        LINKS,
        "the entry cannot be matched to plan work; review treats it as unassessed",
        "the plan's task IDs",
        "correct the ID or add the task to the plan as an implementation-time update",
    ),
    "CH2": Rule(
        "Changes record completes a task whose plan marker is unchecked",
        "medium",
        EVIDENCE,
        "the plan is stale; rpi-implement resumes from the first unchecked item and "
        "may redo "
        "the work",
        "the plan heading for the task",
        "check the marker in the plan, or correct the changes record",
    ),
    "CH3": Rule(
        "Execution status missing or outside Complete, Partial, Blocked",
        "low",
        TEMPLATE,
        "the caller and review read this field first",
        "Execution Status",
        "record one of the three values",
    ),
    "CH4": Rule(
        "Status Complete for the full plan while plan markers remain unchecked",
        "medium",
        EVIDENCE,
        "full-plan completion requires every marker to have completion evidence",
        "the plan checklist",
        "set Partial and list the remaining markers, or finish the work",
    ),
    "CH5": Rule(
        "Completed-work entry without a validation line",
        "low",
        EVIDENCE,
        "each entry records passed, failed, skipped, or unavailable; review needs it",
        "the entry",
        "add `* Validation:` with the result or reason",
    ),
    "CH6": Rule(
        "Changes record points at a plan file that does not exist",
        "medium",
        LINKS,
        "the changes record cannot be matched to its plan on resume",
        "the Metadata Related plan line",
        "correct the link",
    ),
    "CH7": Rule(
        "Business Alignment entry pending a decision",
        "medium",
        GATES,
        "a `pending-decision` alignment blocks review readiness until the user decides",
        "the Business Alignment section",
        "record the user decision and the resulting alignment value",
    ),
    "CH8": Rule(
        "Changes record reports a blocker",
        "info",
        GATES,
        "implementation is paused on the named item",
        "the Blockers section",
        "clear the blocker named there",
    ),
    "CH9": Rule(
        "Review readiness ready while blockers or remaining work are listed",
        "low",
        EVIDENCE,
        "the pre-review reconciliation contradicts itself; review may start on an "
        "incomplete scope",
        "Pre-Review Reconciliation, Blockers, Remaining Work",
        "set not ready with the reason, or clear the lists",
    ),
    "CH10": Rule(
        "Validation failed or unavailable",
        "info",
        EVIDENCE,
        "a failed or unavailable check is carried into review as a limitation",
        "the Validation Record",
        "rerun or record the reason",
    ),
    # Review
    "RV1": Rule(
        "Review finding marker and heading disagree or repeat",
        "medium",
        MARKERS,
        "decisions in the Parent Decision Record key on RV-xxx",
        "the Findings section",
        "give every finding one `<!-- rpi:review id=RV-xxx -->` marker and heading",
    ),
    "RV2": Rule(
        "Review finding without a proposed destination",
        "medium",
        GATES,
        "every finding routes to rpi-implement, rpi-plan, rpi-research, or follow-up; "
        "without "
        "it the parent cannot dispose of it",
        "the finding's Proposed destination line",
        "add one of the four destinations",
    ),
    "RV3": Rule(
        "Review execution or assessed outcome missing or outside the vocabulary",
        "low",
        TEMPLATE,
        "execution (Complete, Partial, Blocked) and outcome (Conformant, Conformant "
        "with "
        "justified divergence, Defects found, Residual work, Not accepted) are "
        "separate fields",
        "the Executive Summary",
        "record both values",
    ),
    "RV4": Rule(
        "Review finding with no decision event",
        "medium",
        GATES,
        "a finding without a deciding RD event is undecided; the final outcome stays "
        "pending and nothing is routed",
        "the Decision History table",
        "append the RD event with the disposition and destination",
    ),
    "RV5": Rule(
        "Review points at a plan or changes file that does not exist",
        "medium",
        LINKS,
        "the review cannot be matched to its evidence on resume",
        "Scope and Evidence",
        "correct the paths",
    ),
    "RV6": Rule(
        "Conformant outcome while a Critical or High finding is undecided, deferred, "
        "or skipped",
        "medium",
        GATES,
        "material skipped or deferred findings prevent a Conformant outcome",
        "the finding and its RD events",
        "record the decision or change the outcome",
    ),
    "RV7": Rule(
        "Final outcome pending in the Parent Decision Record",
        "info",
        GATES,
        "the Executive Summary's assessed outcome is the reviewer's proposal; "
        "acceptance is "
        "recorded only in Current Disposition",
        "Current Disposition under Parent Decision Record",
        "decide the findings and refresh Current Disposition",
    ),
    "RV8": Rule(
        "Review started and not finished",
        "info",
        GATES,
        "the review record is saved while execution stays `started`; its finding set "
        "is "
        "complete only once execution leaves `started`",
        "the Review Record's Review execution line",
        "let the running review finish, or resume it with `/rpi-review`",
    ),
    # Research
    "RS1": Rule(
        "Planning Readiness missing or outside Ready, Not ready, Not applicable, "
        "Blocked",
        "low",
        GATES,
        "the planner reads this row to decide whether planning can start",
        "Planning Readiness and Next Step",
        "record one of the four values",
    ),
    "RS2": Rule(
        "Evidence ID cited but not defined in the Evidence Log",
        "low",
        TEMPLATE,
        "findings cite C# and W# IDs; a citation without a row cannot be checked",
        "the Evidence Log",
        "add the row or fix the citation",
    ),
    "RS3": Rule(
        "Research disposition missing or outside executed, reused, "
        "satisfied-and-skipped",
        "low",
        TEMPLATE,
        "the value tells the parent whether research ran",
        "Planning Readiness and Next Step",
        "record the value",
    ),
    "RS4": Rule(
        "Research not ready for planning",
        "info",
        GATES,
        "planning does not start until readiness is Ready or an explicit parent "
        "records adequacy",
        "Planning Readiness",
        "re-enter research on the named gap",
    ),
    # Task-level
    "TK1": Rule(
        "Changes record without a plan",
        "medium",
        LINKS,
        "implementation evidence exists for a plan the folder does not hold; nothing "
        "can be "
        "resumed or reviewed against it",
        "the plans folder",
        "restore the plan or record where it lives",
    ),
    "TK2": Rule(
        "Review without a changes record",
        "medium",
        LINKS,
        "a review compares the changes record with the plan; without one its findings "
        "have no "
        "implementation evidence",
        "the changes folder",
        "restore the changes record",
    ),
    "TK3": Rule(
        "Critique without a plan",
        "medium",
        LINKS,
        "a critique of a plan the folder does not hold cannot be disposed",
        "the plans folder",
        "restore the plan",
    ),
    "TK4": Rule(
        "Task ID differs across the task's artifacts",
        "medium",
        LINKS,
        "one stable task ID joins plan, critique, changes, and review; a mismatch "
        "breaks resume "
        "and review",
        "the Metadata of each artifact",
        "align the Task ID in every artifact",
    ),
    "TK5": Rule(
        "Several artifacts of one kind for one slug",
        "info",
        LINKS,
        "the newest dated file is treated as current; older ones may be superseded or "
        "a renamed "
        "task",
        "the dates and contents",
        "confirm which is current and consider removing the rest",
    ),
    "TK6": Rule(
        "Open task without a change for longer than the stale threshold",
        "info",
        LAYOUT,
        "an abandoned task keeps appearing as resumable; modification times reset when "
        "a folder "
        "is copied",
        "the latest modification date",
        "finish, hand over, or delete the task's artifacts",
    ),
    "TK7": Rule(
        "Session state points at an artifact that does not exist",
        "medium",
        STATE,
        "an RPI session reconciles state against artifact_paths and documents on "
        "recovery; a "
        "missing file is a recovery blocker",
        "artifact_paths and documents in the state file",
        "correct the path or restore the file",
    ),
    "TK8": Rule(
        "Session state phase disagrees with the artifacts",
        "medium",
        STATE,
        "`/rpi` resumes the recorded phase; if the artifacts the phase needs are "
        "missing, "
        "recovery fails or restarts",
        "active_phase, next_action, and the task's artifacts",
        "reconcile the state with the artifacts before resuming",
    ),
    "TK9": Rule(
        "Session state marks the task completed while plan markers remain unchecked",
        "low",
        STATE,
        "task status completed follows a complete review or full-plan implementation",
        "status and the plan checklist",
        "reconcile",
    ),
    "TK10": Rule(
        "Research exists but planning has not started",
        "info",
        GATES,
        "a fact for the task board",
        "the task's artifacts",
        "run `/rpi-plan` when readiness is Ready",
    ),
    "TK11": Rule(
        "Session state file outside its session folder",
        "low",
        STATE,
        "an RPI session matches state in "
        ".copilot-tracking/rpi-sessions/{date}/{session}/"
        "{task_slug}-state.json and moves a state file it finds elsewhere on the next "
        "resume",
        "the state file path",
        "let `/rpi` move it on the next resume, or move it to "
        "rpi-sessions/{YYYY-MM-DD}/{session_slug}/{task_slug}-state.json",
    ),
    "TK12": Rule(
        "Parent or child state link is broken",
        "medium",
        STATE,
        "parent_task.state_path and child_tasks[].state_path join the loops of a "
        "session; the "
        "session records a blocker when a link cannot be reconciled",
        "parent_task and child_tasks in both state files",
        "correct the state_path, or restore the linked state file",
    ),
    "TK13": Rule(
        "Current artifact path missing from the documents list",
        "low",
        STATE,
        "an RPI session appends every new document to `documents` and points "
        "`artifact_paths` at "
        "it; a path missing from the list hides the document's history from the canvas "
        "and "
        "other readers",
        "artifact_paths and documents in the state file",
        "append the path to that kind's documents list",
    ),
    "TK14": Rule(
        "Session state file cannot be read as state",
        "medium",
        STATE,
        "`/rpi` and the RPI Workflow canvas look for state in the session folder; a "
        "file that "
        "is not valid JSON or lacks task_slug, active_phase, or artifact_paths cannot "
        "be "
        "recovered, and a failed state write is a recovery blocker",
        "the file named in the finding",
        "restore the file from the artifacts it should point at, or remove it and let "
        "`/rpi` "
        "rebuild the state on the next resume",
    ),
    # Hygiene
    "HY1": Rule(
        "Possible credential in a tracking artifact",
        "high",
        SECRETS,
        "tracking files are pasted into chats and reports, and the research self-check "
        "requires "
        "that no secrets are recorded",
        "the line named in the finding",
        "remove the value and rotate it if it is real",
    ),
    "HY2": Rule(
        "Non-Markdown file in an RPI area",
        "info",
        LAYOUT,
        "RPI artifacts are Markdown; JSON here is usually session state, anything else "
        "is "
        "unexpected",
        "the file",
        "none unless the file is not expected",
    ),
}

CONTROL_ORDER = [SECRETS, MARKERS, EVIDENCE, LINKS, GATES, STATE, TEMPLATE, LAYOUT]
STATE_RULES = ("TK7", "TK8", "TK9", "TK11", "TK12", "TK13")
WORKSPACE_RULES = ("LY1", "LY2", "HY2", "TK14")
CROSS_ARTIFACT_RULES = (
    "PL6",
    "PL14",
    "PL18",
    "PC3",
    "CH1",
    "CH2",
    "CH4",
    "CH6",
    "RV5",
    *(f"TK{i}" for i in range(1, 14)),
)
