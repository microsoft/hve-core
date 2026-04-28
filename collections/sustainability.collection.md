Sustainability planning, workload assessment, standards mapping, gap analysis, and prioritized backlog generation against Green Software Foundation SCI/Patterns/Principles, Sustainable Web Design, Web Sustainability Guidelines, and the Azure Well-Architected Sustainability pillar.

> [!CAUTION]
> The sustainability agents and instructions in this collection are **assistive tools only**. They produce directional sustainability estimates, not audited disclosures. They do not provide legal, regulatory, or compliance advice and do not replace qualified sustainability professionals or applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067). Requests to generate text for CSRD or ESRS disclosures, SEC climate filings, GHG Protocol corporate inventories, TCFD reports, or ISO 14064/ISO 14067 attestations fall outside this planner's scope. All AI-generated sustainability artifacts **must** be reviewed by a qualified sustainability professional before external use.

This collection includes agents and instructions for:

- **Sustainability Planning** - Six-phase conversational workflow producing workload assessment, standards mapping, gap analysis, and dual-format backlog handoff
- **SCI Estimation** - Capture deterministic, estimated, heuristic, and user-declared inputs to the Software Carbon Intensity formula and emit `sci-budgets/*.yml` skeletons keyed to active workloads
- **Green Software Adoption** - Map active workloads to GSF Principles and to the Azure Well-Architected Sustainability pillar
- **Web Sustainability Mapping** - Cross-walk web surfaces against Sustainable Web Design (SWD) and Web Sustainability Guidelines (WSG) controls
- **Active Controls Export** - Emit `active-controls.json` for downstream consumption by Security, SSSC, RAI, and code-review agents
- **Out-of-Band Disclosure Refusal** - Halt and redirect any request to generate CSRD/ESRS/SEC/GHG/TCFD/ISO 14064/14067 disclosure text

Supporting subagents included:

- **Sustainability Researcher Subagent** - Research subagent for license interrogation and standards-discovery topics across GSF, SWD, WSG, and Azure Well-Architected references

Framework Skills included:

- **GSF SCI** - Green Software Foundation Software Carbon Intensity specification (ISO 21031 reference-only) packaged as machine-readable per-control YAML
- **GSF Principles** - Green Software Foundation core principles as machine-readable items
- **GSF Principles** - Green Software Foundation Principles as per-principle controls
- **Sustainable Web Design (SWD)** - SWD v4 controls for low-carbon web design and content delivery
- **Web Sustainability Guidelines (WSG)** - W3C Web Sustainability Guidelines as per-guideline controls
- **Azure Well-Architected Sustainability** - Azure WAF Sustainability pillar recommendation groups
- **Sustainability Capability Inventory** - Workload capability inventory consumed by the Sustainability Planner during workload assessment, gap analysis, and backlog generation
- **Framework Skill** - Authoring guide for Framework Skills — host-agent-neutral packaging format for framework specifications
