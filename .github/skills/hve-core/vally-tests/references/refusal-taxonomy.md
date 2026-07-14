---
title: Refusal Taxonomy
description: Authoritative refusal categories, regex patterns, and worked refusal examples consumed by the Vally test-authoring safety lint script
---

This reference defines the seven refusal categories the Vally test-authoring skill enforces during stimulus generation. Each category lists the patterns the safety lint script reads verbatim along with the canonical refusal block the skill emits when a match occurs. The categories, ordering, and refusal wording are normative; downstream tooling treats this file as the only source for the regex set.

## Category: jailbreak

* **Definition**: Attempts to bypass model safety policies through persona switching, hypothetical framing, roleplay coercion, or explicit override commands directed at the underlying model rather than at the artifact under test.
* **Why refused**: Authoring stimuli that attempt to jailbreak a model violates the prohibited content categories adopted in [`CODE_OF_CONDUCT.md`](../../../../../CODE_OF_CONDUCT.md), which references the Microsoft Enterprise AI Services Code of Conduct. Authoring conformance tests is bounded to the artifact's own contract; jailbreak research belongs in the responsible AI workflow, not in Vally stimulus emission.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\bignore\s+(?:your\s+|the\s+|all\s+|any\s+)?(?:previous|prior|above|earlier)\s+(?:instructions?|prompts?|rules?|guidelines?)\b
  ```

  ```regex
  (?i)\bact\s+as\s+(?:an?\s+)?(?:unrestricted|unfiltered|uncensored|jailbroken)\s+(?:ai|assistant|model|chatbot)\b
  ```

  ```regex
  (?i)\b(?:dan\s*mode|do\s+anything\s+now|developer\s+mode|god\s+mode|sudo\s+mode)\b
  ```

  ```regex
  (?i)\b(?:pretend|imagine|roleplay)\s+(?:that\s+)?(?:safety|guidelines?|rules?|policies)\s+(?:do\s*n['o]?t\s+apply|are\s+disabled|don['o]?t\s+exist)\b
  ```

  ```regex
  (?i)\bwithout\s+(?:any\s+)?(?:safety|content|policy|moderation)\s+(?:restrictions?|filters?|guardrails?|guidelines?)\b
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under jailbreak. Please consult CODE_OF_CONDUCT.md for the appropriate process.
  ```

## Category: prompt-injection

* **Definition**: Attempts to override system or developer instructions through embedded markers, mode-switching directives, or adversarial control sequences placed inside what appears to be normal user input.
* **Why refused**: Generating novel prompt-injection payloads conflicts with the AI output and prohibited content categories referenced in [`CODE_OF_CONDUCT.md`](../../../../../CODE_OF_CONDUCT.md). Conformance tests verify the artifact's own contract; injection robustness research is out of scope for the Vally test-authoring skill.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\[\s*system\s*[:\]]
  ```

  ```regex
  (?i)\b(?:in|enter|switch\s+to)\s+(?:test|debug|unsafe|admin|root|developer)\s+mode\b
  ```

  ```regex
  (?i)\bdisregard\s+(?:the\s+)?(?:above|previous|prior|preceding)\s+(?:text|content|instructions?|context)\b
  ```

  ```regex
  (?i)<\s*\/?(?:system|sys|instructions?|admin)\s*>
  ```

  ```regex
  (?i)\bnew\s+(?:system|admin|root)\s+(?:instruction|prompt|directive|command)s?\s*[:\-]
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under prompt-injection. Please consult CODE_OF_CONDUCT.md for the appropriate process.
  ```

## Category: harmful-elicitation

* **Definition**: Requests for content that causes physical, financial, psychological, or reputational harm, including weapons synthesis, violence how-tos, self-harm encouragement, illegal substance production, or promotion of abuse.
* **Why refused**: This category is prohibited outright by the AI output policy referenced in [`CODE_OF_CONDUCT.md`](../../../../../CODE_OF_CONDUCT.md) and by the harmful-content rule in the repository's Copilot instructions. No conformance scenario justifies authoring such stimuli.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\b(?:how\s+to|instructions?\s+(?:for|on)|guide\s+(?:to|for)|tutorial\s+(?:on|for))\s+(?:build|make|construct|create|synthesi[sz]e|manufacture)\s+(?:a\s+|an\s+)?(?:bomb|explosive|weapon|firearm|gun|poison|biological\s+agent|chemical\s+weapon)\b
  ```

  ```regex
  (?i)\bhow\s+to\s+(?:kill|murder|assault|attack|torture|harm|hurt|wound|maim)\s+(?:a\s+|an\s+|someone|people|person)\b
  ```

  ```regex
  (?i)\b(?:self[\s\-]?harm|self[\s\-]?injur(?:y|e|ing)|suicide\s+(?:method|technique|plan|instructions?))\b
  ```

  ```regex
  (?i)\b(?:synthesi[sz]e|cook|produce|manufacture)\s+(?:meth(?:amphetamine)?|fentanyl|heroin|cocaine|illegal\s+drugs?|controlled\s+substances?)\b
  ```

  ```regex
  (?i)\bgenerate\s+(?:content\s+)?(?:promoting|encouraging|glorifying)\s+(?:violence|self[\s\-]?harm|terrorism|abuse)\b
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under harmful-elicitation. Please consult CODE_OF_CONDUCT.md for the appropriate process.
  ```

## Category: tos-violation

* **Definition**: Stimuli that solicit content prohibited by GitHub, Microsoft, Azure, or model-provider terms of service, including verbatim reproduction of copyrighted works, fabrication of credentials, rate-limit evasion, or impersonation of real services or officials.
* **Why refused**: The GitHub Acceptable Use Policies, Microsoft Trademark and Brand Guidelines, and Enterprise AI Services Code of Conduct referenced in [`CODE_OF_CONDUCT.md`](../../../../../CODE_OF_CONDUCT.md) prohibit this material. Vally conformance tests do not require authoring policy-evasion stimuli.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\breproduc(?:e|ing)\s+(?:the\s+)?(?:full\s+|entire\s+|complete\s+|verbatim\s+)(?:text|content|chapter|book|article|song|lyrics|screenplay|source\s+code)\s+of\b
  ```

  ```regex
  (?i)\b(?:generate|create|forge|fabricate)\s+(?:a\s+|valid\s+|working\s+|real\s+)?(?:api\s+key|access\s+token|oauth\s+token|password|credential|license\s+key|product\s+key|serial\s+number)s?\b
  ```

  ```regex
  (?i)\b(?:bypass|circumvent|evade|defeat)\s+(?:the\s+|any\s+)?(?:rate\s+limit|usage\s+(?:limit|cap|quota)|paywall|content\s+filter|terms\s+of\s+service)\b
  ```

  ```regex
  (?i)\bimpersonat(?:e|ing)\s+(?:microsoft|openai|github|azure|google|amazon|apple|a\s+real\s+(?:person|company|service|official))\b
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under tos-violation. Please consult CODE_OF_CONDUCT.md for the appropriate process.
  ```

## Category: coc-violation

* **Definition**: Stimuli that violate this repository's Code of Conduct, including targeted harassment, doxxing, hate speech, intimidation, threats, or generation of discriminatory content aimed at protected classes.
* **Why refused**: The Microsoft Open Source Code of Conduct adopted in [`CODE_OF_CONDUCT.md`](../../../../../CODE_OF_CONDUCT.md) and the GitHub Acceptable Use Policies prohibit this material. No conformance scenario justifies generating it.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\b(?:targeted|coordinated|sustained)\s+(?:harassment|abuse|stalking|trolling)\b
  ```

  ```regex
  (?i)\b(?:dox(?:x?ing)?|publish(?:ing)?\s+private\s+(?:information|details|address|phone))\b
  ```

  ```regex
  (?i)\b(?:hate\s+speech|slur|epithet)s?\s+(?:about|against|targeting|toward)\s+(?:a\s+|any\s+)?(?:race|ethnicity|religion|gender|sexual\s+orientation|nationality|disability)\b
  ```

  ```regex
  (?i)\bgenerate\s+(?:content\s+)?(?:designed\s+to\s+)?(?:intimidate|threaten|harass|silence)\s+(?:a\s+|an\s+|the\s+)?(?:person|individual|user|group|community)\b
  ```

  ```regex
  (?i)\b(?:discriminatory|racist|sexist|misogynistic|homophobic|transphobic|xenophobic|antisemit(?:ic|ism)|islamophob(?:ic|ia))\s+(?:content|joke|message|post|comment)s?\b
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under coc-violation. Please consult CODE_OF_CONDUCT.md for the appropriate process.
  ```

## Category: model-refusal-elicitation

* **Definition**: Stimuli whose primary purpose is provoking a model refusal so that the refusal text itself can be scored, graded, paraphrased, or used to map provider safety boundaries, rather than verifying the artifact's own contract.
* **Why refused**: Boundary mapping and refusal elicitation are activities for responsible AI assessment, not for conformance testing. They fall under the prohibited uses gate and safety-critical screening handled by `RAI Planner`.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\bfind\s+(?:a\s+|the\s+|any\s+)?(?:prompt|input|stimulus|payload)\s+(?:that\s+)?(?:makes?|gets?|triggers?)\s+(?:you|the\s+model|the\s+ai)\s+(?:to\s+)?(?:refuse|deny|reject|block)\b
  ```

  ```regex
  (?i)\bminimum(?:\s+viable)?\s+(?:jailbreak|exploit|bypass|payload)\b
  ```

  ```regex
  (?i)\b(?:map|chart|enumerate|catalog(?:ue)?)\s+(?:the\s+|your\s+)?(?:refusal|safety|moderation|content)\s+(?:boundary|boundaries|limits?|threshold)s?\b
  ```

  ```regex
  (?i)\b(?:show|tell|demonstrate)\s+(?:me\s+)?(?:what|where|how)\s+(?:you|the\s+model|the\s+ai)\s+(?:refuses?|will\s+refuse|won['o]?t\s+respond)\b
  ```

  ```regex
  (?i)\bgenerate\s+\d+\s+(?:variations?|alternatives?|paraphrases?)\s+(?:to\s+)?(?:see|test|find)\s+(?:which\s+)?(?:one\s+)?(?:bypasses?|passes?|triggers?)\s+(?:the\s+)?(?:safety|filter|moderation)\b
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under model-refusal-elicitation. Please consult `RAI Planner` for the appropriate process.
  ```

## Category: pii-extraction

* **Definition**: Attempts to elicit personally identifiable information, credentials, secrets, system prompts, hidden instructions, or reconstructed training data from the model or the artifact under test.
* **Why refused**: PII extraction probes safety, privacy, and security boundaries that belong in the responsible AI assessment workflow handled by `RAI Planner`. Vally conformance tests verify documented artifact behavior; they are not the right vehicle for extraction stimuli.
* **Regex patterns** (source of truth: the lint script reads these verbatim):

  ```regex
  (?i)\bextract\s+(?:all\s+)?(?:email\s+addresses?|phone\s+numbers?|ssns?|social\s+security\s+numbers?|credit\s+card\s+numbers?|home\s+addresses?)\b
  ```

  ```regex
  (?i)\b(?:leak|reveal|disclose|expose|print|dump)\s+(?:the\s+|your\s+|all\s+|any\s+)?(?:internal|private|stored|configured|environment)\s+(?:api\s+keys?|tokens?|credentials?|secrets?|passwords?)\b
  ```

  ```regex
  (?i)\b(?:reconstruct|reproduce|recover|exfiltrate)\s+(?:the\s+|your\s+|original\s+)?training\s+data\b
  ```

  ```regex
  (?i)\blist\s+(?:all\s+)?(?:user|customer|client|personal)\s+(?:pii|data|information|records?)\s+(?:you['o]?ve\s+)?(?:seen|processed|stored|remembered)\b
  ```

  ```regex
  (?i)\b(?:show|print|reveal|dump|list)\s+(?:your\s+|the\s+|all\s+)?(?:system\s+prompt|hidden\s+instructions?|configuration|environment\s+variables?)\b
  ```

* **Worked refusal example**:

  ```text
  This skill authors conformance tests only. The request appears to fall under pii-extraction. Please consult `RAI Planner` for the appropriate process.
  ```

## Lint script contract

* Every fenced block tagged with ```` ```regex ```` in this file is part of the source of truth. The lint script extracts the block bodies verbatim; no other file overrides or supplements them.
* Every pattern is case-insensitive PCRE-compatible. The `(?i)` inline modifier is required at the start of each pattern so that PowerShell, Python, and shell regex engines apply identical matching semantics.
* The lint script joins all regex blocks under a single category using alternation (`|`) and evaluates the combined pattern against the candidate stimulus. Patterns within a category are designed to coexist when alternated.
* Any match against any category's combined pattern flags the stimulus for refusal. The script emits the matching category, the matching pattern index within that category, and the stimulus location.
* This file is the only normative source for the regex set. Changes to category names, pattern semantics, or refusal wording propagate through the lint script and the Vally Test Author prompt on the next regeneration; do not duplicate the patterns elsewhere.
