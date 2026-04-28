Accessibility planning, surface assessment, conformance mapping, and prioritized backlog generation against WCAG 2.2, ARIA Authoring Practices Guide, and cognitive accessibility standards.

> [!CAUTION]
> The accessibility agents and instructions in this collection are **assistive tools only**. They do not provide legal, regulatory, or compliance advice and do not replace professional accessibility review boards, WCAG conformance auditors, certified accessibility specialists, legal counsel, or other qualified human reviewers. All AI-generated accessibility artifacts **must** be reviewed and validated by qualified accessibility professionals before use. AI outputs may contain inaccuracies, miss critical conformance gaps, or produce recommendations that are incomplete or inappropriate for your environment.

This collection includes agents and instructions for:

- **Accessibility Planning** - Six-phase conversational workflow producing surface assessment, standards mapping, gap analysis, and dual-format backlog handoff
- **WCAG 2.2 Conformance Mapping** - Map active surfaces to applicable Success Criteria with conformance-level scoping (A, AA, AAA)
- **ARIA Pattern Adoption** - Identify custom widget patterns from the ARIA Authoring Practices Guide and emit per-pattern requirements
- **Cognitive Accessibility** - Apply COGA-derived guidance for plain language, predictable navigation, and reduced cognitive load
- **VPAT Skeleton Emission** - Generate VPAT 2.5 skeletons keyed to the active conformance target
- **Active Rules Export** - Emit `active-rules.json` for downstream consumption by UX, PRD, code review, and documentation agents

Supporting subagents included:

- **Accessibility Researcher Subagent** - Research subagent for accessibility-specific evidence gathering across surface inventories, framework manifests, and external WCAG/ARIA references

Framework Skills included (Wave 1):

- **WCAG 2.2** - W3C Web Content Accessibility Guidelines 2.2 Success Criteria as machine-readable per-criterion YAML
- **ARIA APG** - W3C ARIA Authoring Practices Guide patterns and widget conformance criteria
- **Cognitive Accessibility** - COGA-derived cognitive accessibility guidance for plain-language, predictability, and low-friction interaction
- **Capability Inventory: Web** - Web surface capability inventory consumed by the Accessibility Planner during surface assessment, gap analysis, and backlog generation
- **Capability Inventory: Content** - Document and content surface capability inventory consumed by the Accessibility Planner during surface assessment, gap analysis, and backlog generation
- **Framework Skill** - Authoring guide for Framework Skills — host-agent-neutral packaging format for framework specifications
