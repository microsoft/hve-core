---
description: 'Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.'
applyTo: '**/.copilot-tracking/mural/**, **/.github/skills/experimental/mural/**, **/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md, **/.github/instructions/experimental/mural/**'
---

## Mural Log Hygiene

Mural traffic carries credential material at every hop: the OAuth authorization flow, the localhost browser callback, the `Authorization: Bearer …` header on every authenticated API call, and Azure Blob SAS query strings returned by asset-upload responses. None of that material may be echoed into chat, transcripts, planning artifacts, work items, screenshots, or pasted shell output. Mural is the durable record of human conversation (see [mural-human-record.instructions.md](mural-human-record.instructions.md)); the operator is the second line of defense behind the skill's `_redact` and is responsible for what leaves the terminal.

## Sensitive Material Inventory

| Material                              | Surface where it appears                                             |
|---------------------------------------|----------------------------------------------------------------------|
| OAuth bearer token (`access_token`)   | Token-exchange responses, refresh responses, in-memory profile cache |
| OAuth refresh token (`refresh_token`) | Token-exchange responses, refresh responses, profile cache           |
| PKCE verifier (`code_verifier`)       | Local PKCE state, token-exchange request body                        |
| PKCE challenge (`code_challenge`)     | Authorization URL query string                                       |
| Client secret (`client_secret`)       | Token-exchange request body, environment variables                   |
| Authorization header                  | Every authenticated Mural API call (`Authorization: Bearer …`)       |
| Azure Blob SAS query string           | Asset-upload responses and follow-on PUT URLs (`?sig=…&se=…&sp=…`)   |
| Authorization code (`code`)           | Browser callback URL, token-exchange request body                    |

## Skill Guarantees (defense-in-depth backstop)

The skill provides a single `_redact(text)` helper that masks the items in the inventory above wherever they appear in JSON bodies, form-encoded bodies, `Authorization` headers, or Azure Blob SAS query strings. Coverage is verified by `.github/skills/experimental/mural/tests/test_redaction.py` and documented in `.github/skills/experimental/mural/SECURITY.md` §B4 Information Disclosure.

`_redact` is a backstop, not a license:

* It only protects log output that is actually routed through it. Bare `LOGGER.*` and `print(*)` sites bypass it.
* The mask pattern set drifts as new endpoints, new headers, and new credential shapes are added. A passing test suite at one revision is not a guarantee at the next.
* Operators must never assume a log line is safe just because it appears to come from the skill. Re-evaluate every line that quotes a URL, header, request body, or response body before it leaves the terminal.

## Operator Contract

* Never paste raw Mural API URLs into chat, transcripts, or planning artifacts. Truncate query strings or sanitize before quoting.
* Never echo a token, refresh token, PKCE value, authorization code, or `Authorization` header back to the user, even to confirm a value the user just provided.
* When citing skill log lines as evidence, copy the `_redact`-masked form. Never reconstruct, paraphrase, or fill in the masked portion.
* Treat any artifact that captures network requests (HAR exports, mitmproxy dumps, `curl -v` output, browser devtools exports, `fetch` traces) as compromised until manually scrubbed against the inventory above.
* Never propose code that adds a `LOGGER.*` or `print(*)` site emitting a URL, header, request body, or response body without first wrapping the value through `_redact`.

## Cross-references

* #file:.github/instructions/experimental/mural/mural-human-record.instructions.md
* #file:.github/instructions/experimental/mural/mural-writeback-hygiene.instructions.md
* #file:.github/skills/experimental/mural/SECURITY.md
* #file:.github/skills/experimental/mural/scripts/mural/_transport.py

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
