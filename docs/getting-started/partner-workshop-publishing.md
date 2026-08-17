---
title: Partner Workshop Publishing Follow-Up
description: Frame publication readiness for Azure Managed Application and Microsoft 365 Copilot Agent Store as a workshop handoff
sidebar_position: 11
author: Microsoft
ms.date: 2026-08-17
ms.topic: how-to
keywords:
  - Azure Managed Applications
  - Microsoft Marketplace
  - Partner Center
  - Microsoft 365 Copilot
  - Agent Store
estimated_reading_time: 12
---

## Workshop Agenda

| Item | Activity | Mode | Output |
|------|----------|------|--------|
| 1 | HVE and RPI overview | Shared | Common vocabulary and scenario |
| 2 | Environment setup and verification | Shared | Working HVE Core All installation |
| 3 | Scenario framing | Shared | Initial problem statement |
| 4 | Role exercises | Breakout | Context, requirements, experience, architecture inputs |
| 5 | Artifact integration | Shared | Requirements, backlog, and Azure diagram |
| 6 | Publication readiness | Shared | Managed App and Agent Store checklists |
| 7 | Playback and next actions | Shared | Owners, gaps, and follow-up plan |

Use this guide during the publication-readiness portion of the workshop. The goal is to turn the workshop outputs into a clear follow-up plan for the right publication path rather than to complete every certification step in-session.

## Objective

Capture the minimum work needed to make the solution reviewable and eligible for publication through Microsoft Marketplace and Microsoft 365 Copilot Agent Store.

## Suggested workshop outcome

By the end of the session, the team should be able to answer:

* Which publication path is being targeted first?
* What needs to be owned by engineering, product, security, or operations?
* What remains unresolved before a real submission can happen?

## Start with the product split

Treat the Azure application and Microsoft 365 agent as separate products with a documented integration contract.

1. Define what the Azure Managed Application deploys into a customer subscription.
2. Define what the Microsoft 365 agent presents to users.
3. Define the API, identity, permission, and data contract between them.
4. Define who owns configuration, support, telemetry, and upgrades.
5. Define version compatibility and failure behavior.

## Commercial readiness and publication planning

Before building the offer package, capture the commercial and go-to-market context that will affect Marketplace and agent-store review.

1. Define the product brand, messaging, and primary value proposition for both the Azure offer and the Microsoft 365 agent experience.
2. Confirm the initial geographic coverage, target customer segment, and any launch limitations such as language or regional compliance constraints.
3. Define the monetization model, billing approach, and taxation expectations early so the offer plan and support model are aligned.
4. Capture a simple Lean Business Canvas summary with customer segments, problem, solution, channels, revenue, cost, partners, and differentiators.
5. For Azure IP Cosell on Marketplace, complete a Partner Center Admin checklist that covers publisher setup, legal entity and tax readiness, offer metadata, support contacts, pricing plan, and technical package validation.
6. For a Copilot Agent Store add-on, verify the supported agent type, packaging path, tenant admin approvals, consent boundaries, and whether the agent should be listed as a standalone offer or an add-on to the Azure offer.

> [!NOTE]
> Treat any commercial route, offer type, or add-on limitation as a verification item until current Microsoft guidance confirms the supported path. The policy matrix can change by agent type and distribution route.

## Publication readiness checklists

### Marketplace publishing checklist

Use this checklist when the team is preparing an Azure Managed Application or related offer for Microsoft Marketplace.

* [ ] Confirm the target offer type is correct for the scenario.
* [ ] Create or verify the Partner Center publisher account and ensure it is enrolled for the intended Marketplace program.
* [ ] Confirm the legal entity, tax profile, payout setup, and support contacts are complete.
* [ ] Define the offer name, short description, long description, categories, and search terms.
* [ ] Prepare product screenshots, architecture diagrams, documentation links, privacy links, and support links.
* [ ] Define the pricing model, billing plan, and any metered billing or plan-level requirements.
* [ ] Validate that the Azure deployment package is built correctly and that the package files are in the expected structure.
* [ ] Test the deployment experience in a non-production environment before submission.
* [ ] Capture the preview audience, planned launch geography, and any regional or language limitations.
* [ ] Record the owner for security, privacy, legal, support, and technical review before submission.

### Microsoft 365 Copilot Agent Store checklist

Use this checklist when the team is preparing a Microsoft 365 agent or Copilot experience for the Agent Store.

* [ ] Confirm the agent type is supported for commercial publication through the current Microsoft 365 and Copilot publishing guidance.
* [ ] Verify the selected packaging path, such as Microsoft 365 Agents Toolkit or another supported packaging approach.
* [ ] Review the agent name, description, instructions, conversation starters, and approved knowledge sources.
* [ ] Verify the agent connects to the Azure service through an authenticated and least-privilege path.
* [ ] Confirm the service enforces authorization checks, not only prompt-level behavior.
* [ ] Add citations, uncertainty handling, feedback capture, and a human escalation path.
* [ ] Validate privacy, security, accessibility, and Responsible AI requirements for the experience.
* [ ] Prepare the app package, manifest, icons, screenshots, and any required support or setup documentation.
* [ ] Confirm tenant admin approvals, consent boundaries, and any required preview or pilot audience setup.
* [ ] Record the owner for validation, support, and post-launch monitoring.

### Partner Center admin checklist

Use this checklist for the administrative and offer-readiness review that usually happens before submission.

* [ ] Verify the publisher identity, tenant access, and required admin roles are available.
* [ ] Confirm the legal entity, tax information, payment profile, and billing setup are complete.
* [ ] Add or verify support contacts, escalation contacts, and listing owners.
* [ ] Review the offer metadata, terms, privacy statement, and support documentation links.
* [ ] Confirm the pricing plan, plan type, and billing expectations are documented and approved.
* [ ] Ensure the technical package has been validated and uploaded successfully.
* [ ] Confirm the offer has a test or preview path with controlled users or subscriptions.
* [ ] Review dependencies, access requirements, and customer onboarding steps.
* [ ] Confirm that security, privacy, accessibility, and Responsible AI review feedback has been addressed.
* [ ] Capture the final submission owner and the date by which each remaining issue must be resolved.

## Azure Managed Application path

### Phase 1: Confirm publisher readiness

1. Verify or create the publisher account in Partner Center.
2. Complete publisher verification and Marketplace enrollment.
3. Confirm the legal entity, tax, payout, support, and listing owners.
4. Confirm access to a non-production Azure subscription.
5. Register required resource providers.
6. Choose the Managed Application permission scenario.
7. Apply least privilege to publisher identities and customer operations.
8. Decide whether metered billing is required.

### Phase 2: Build and validate the package

1. Create a simple working folder for the package and keep the files organized before you start.
2. Define the minimum Azure resources first, such as the app service, storage account, key vault, or other required resources for the scenario.
3. Implement the deployment in Bicep if possible, because it is easier to read and maintain than raw ARM JSON.
4. Validate the Bicep locally with the Azure tooling you have available and fix any syntax or parameter issues before packaging.
5. Export or convert the validated Bicep into ARM template JSON for the Managed Application package.
6. Name the deployment template `mainTemplate.json` and keep it at the supported ARM template language version 1.0.
7. Create `createUiDefinition.json` so the portal has a guided experience for entering deployment values.
8. Map every UI field in `createUiDefinition.json` to a parameter in `mainTemplate.json` so the portal and template stay in sync.
9. Place both files at the root of `app.zip` with no extra nesting that could break the package structure.
10. Validate the ARM template and the package structure before uploading anything.
11. Test the portal experience in the CreateUiDefinition sandbox with sample values to confirm the UI behaves correctly.
12. Review secrets, vulnerabilities, RBAC, network exposure, data handling, diagnostics, quotas, and cost.
13. Deploy the package to a non-production subscription and confirm the deployment succeeds.
14. Test create, update, failure recovery, support access, and deletion from the customer experience.
15. Record any issues found during validation and fix them before the offer is submitted.

### Phase 3: Create the Marketplace offer

1. Sign in to [Partner Center](https://partner.microsoft.com/dashboard/home).
2. Open **Marketplace offers**.
3. Select **New offer** and then **Azure Application**.
4. Enter a permanent, unique offer ID.
5. Select the verified publisher account.
6. Complete offer setup, properties, categories, legal terms, and contracts.
7. Complete the listing content, search terms, images, support, privacy, and documentation links.
8. Add a preview audience using controlled test accounts.
9. Create a plan and choose the appropriate Azure Application plan type.
10. Upload the validated Managed Application package.
11. Save the draft and resolve validation errors.

### Phase 4: Preview, certify, and go live

1. Submit the offer for preview.
2. Resolve validation and certification feedback.
3. Ask preview users to deploy the offer into clean test subscriptions.
4. Verify deployment, billing, identity, telemetry, support, upgrades, and deletion from the customer perspective.
5. Obtain approval from security, privacy, accessibility, legal, support, and business owners.
6. Make the offer live once certification is complete.

## Microsoft 365 Copilot Agent path

### Phase 1: Offer commercialization

1. Choose **Microsoft 365 Agents Toolkit** for a packaged declarative or custom engine agent that can target Microsoft Marketplace.

> [!NOTE]
> Verify the current [Microsoft 365 Copilot publishing matrix](https://learn.microsoft.com/microsoft-365-copilot/extensibility/publish) before implementation because support varies by agent type and route.

### Phase 2: Build and test the agent

1. Create the agent in the selected tool.
2. Add the reviewed name, description, instructions, conversation starters, and approved knowledge sources.
3. Connect the Azure application through an authenticated API or supported action.
4. Apply delegated or application permissions according to least privilege.
5. Add authorization checks in the Azure service, not only in agent prompts.
6. Add citations, uncertainty behavior, feedback, and human escalation.
7. Prepare the Microsoft 365 app package, manifest, icons, and required files when using Agents Toolkit.
8. Run manifest and Responsible AI validation.
9. Sideload into a test tenant with administrator approval.
10. Test expected prompts, prohibited prompts, unauthorized access, missing content, dependency failures, prompt injection, and harmful output handling.
11. Complete security, privacy, accessibility, Responsible AI, and support reviews.

### Phase 3: Publish through Microsoft Marketplace

1. Confirm the agent type supports commercial marketplace submission.
2. Enroll the verified Partner Center publisher in the **Microsoft 365 and Copilot** program.
3. Review Microsoft Commercial Marketplace certification policies.
4. Review Microsoft 365 Store validation guidelines for agents.
5. Complete Responsible AI validation checks.
6. Prepare customer-facing descriptions, icons, privacy policy, terms, support, setup instructions, and test credentials when required.
7. In Partner Center, create the offer type **Apps and agents for Microsoft 365 and Copilot**.
8. Upload the validated Microsoft 365 app package.
9. Submit the offer for validation and resolve certification findings.

## Final release gate

Do not release either product until accountable humans confirm:

1. The customer problem is documented and validated.
2. The solution meets its business outcome and first-release criteria.
3. Technical, data, and identity boundaries are documented.
4. Accessibility checks are complete.
5. Responsible AI risks, evaluation results, and mitigations are reviewed.
6. Customer and publisher permissions follow least privilege.
7. Cost, metering, licensing, support, incident response, and service ownership are defined.
8. Preview deployments and pilot agent installations succeeded.
9. Rollback, update, monitoring, and customer communication plans exist.
10. Partner Center and tenant administrators have granted required approvals.

## Playback and next steps

Use this section to close the workshop with a clear handoff.

1. Ask each role to summarize the key decision, dependency, or risk it surfaced.
2. Confirm which publication route is the first target: Azure Managed Application, Microsoft 365 Copilot agent, or both.
3. Record the primary owners for engineering, product, security, privacy, support, and publishing operations.
4. Capture the top three blockers that must be resolved before submission.
5. Assign a follow-up owner and a target date for each remaining action.
6. Keep the output as a draft until a responsible human reviewer confirms it.

## Working session reminder

Keep the output concise and action-oriented. Do not wait for perfect information. The goal is to produce a reviewed draft that the team can refine after the workshop.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
