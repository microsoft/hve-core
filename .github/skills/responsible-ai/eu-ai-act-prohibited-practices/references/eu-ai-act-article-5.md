# EU AI Act — Article 5 (Prohibited AI Practices)

This reference is a paraphrased overview of Article 5 of Regulation (EU) 2024/1689 (the Artificial Intelligence Act) intended for use by the RAI Planner agent. It does not reproduce the verbatim text of the Regulation. For the authoritative source, consult EUR-Lex.

## Authoritative source

* Regulation (EU) 2024/1689 of the European Parliament and of the Council of 13 June 2024 laying down harmonised rules on artificial intelligence (Artificial Intelligence Act).
* Official text: <https://eur-lex.europa.eu/eli/reg/2024/1689/oj>

## Scope of Article 5

Article 5(1) enumerates AI practices that are prohibited within the Union. Article 5(2)–(7) set out additional safeguards, conditions, and procedural requirements that apply specifically to the use of real-time remote biometric identification systems referenced in point (h). The principles encoded in this skill cover the eight points (a)–(h) of Article 5(1) and are surfaced by the RAI Planner during the Phase 2 Prohibited Uses Gate.

## Mapping to skill items

| Article 5(1) point | Skill item id        | Prohibition type                       |
| ------------------ | -------------------- | -------------------------------------- |
| (a)                | `eu-aia-pp-1`        | Manipulation                           |
| (b)                | `eu-aia-pp-2`        | Exploitation of vulnerability          |
| (c)                | `eu-aia-pp-3`        | Social scoring                         |
| (d)                | `eu-aia-pp-4`        | Predictive policing                    |
| (e)                | `eu-aia-pp-5`        | Biometric database scraping            |
| (f)                | `eu-aia-pp-6`        | Emotion recognition                    |
| (g)                | `eu-aia-pp-7`        | Biometric categorisation               |
| (h)                | `eu-aia-pp-8`        | Remote biometric identification        |

## Use guidance for agents

* Treat any item match as a hard halt for the planning workflow under the Prohibited Uses Gate; do not attempt to mitigate or score the prohibition.
* Always cite the EUR-Lex URL above when surfacing a prohibition determination to the user.
* Do not paraphrase, condense, or reuse any of the per-item summaries in agent output without retaining the corresponding `articleRef` and EUR-Lex citation.

## License posture

Paraphrased summaries in this skill are authored by the skill maintainers and licensed Apache-2.0 with the rest of the repository. The underlying Regulation is an EU institutional document; verbatim reproduction is intentionally avoided. Consumers requiring the legal text MUST consult EUR-Lex directly.
