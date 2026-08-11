---
title: Partner Workshop Publishing Follow-Up
description: Step-by-step follow-up for Azure Managed Application and Microsoft 365 Copilot Agent Store publication
sidebar_position: 11
author: Microsoft
ms.date: 2026-08-11
ms.topic: how-to
keywords:
  - Azure Managed Applications
  - Microsoft Marketplace
  - Partner Center
  - Microsoft 365 Copilot
  - Agent Store
estimated_reading_time: 15
---

Publication starts during the workshop as a readiness assessment and continues
afterward with authorized environments and human approvals. Certification and
tenant approval timelines are outside the two-hour agenda.

| Milestone | Workshop Expectation | Completion Owner |
|-----------|----------------------|------------------|
| Product and integration contract | Draft | Cross-role team |
| Managed Application package | Plan only | Technical team |
| Azure Application offer | Readiness checklist | Marketplace owner |
| Microsoft 365 agent package | Route and requirements | Agent engineering team |
| Agent Store or Marketplace release | Approval plan | Tenant admin and publisher |

## Choose The Two Products

Treat the Azure application and Microsoft 365 agent as separate products with a
documented integration contract.

1. Define what the Azure Managed Application deploys into a customer
   subscription.
2. Define what the Microsoft 365 agent presents to users.
3. Define the API, identity, permission, and data contract between them.
4. Define which product owns configuration, support, telemetry, and upgrades.
5. Define version compatibility and failure behavior.

## Publish An Azure Managed Application

### Phase 1: Confirm Publisher Readiness

1. Create or verify the organization's Partner Center account.
2. Complete publisher verification.
3. Enroll the publisher in the Microsoft Marketplace program.
4. Confirm the legal entity, tax, payout, support, and listing owners.
5. Confirm access to a non-production Azure subscription.
6. Register required resource providers.
7. Choose the Managed Application permission scenario.
8. Apply least privilege to publisher identities and customer operations.
9. Decide whether marketplace metered billing is required.

### Phase 2: Build And Validate The Package

1. Implement the Azure resources as Bicep or ARM templates.
2. Convert Bicep to ARM template JSON for the Managed Application package.
3. Name the deployment template `mainTemplate.json`.
4. Keep the ARM template on supported language version 1.0.
5. Create `createUiDefinition.json` for the Azure portal deployment experience.
6. Map every UI output to a parameter in `mainTemplate.json`.
7. Put both files at the root of `app.zip`.
8. Validate the ARM template.
9. Test `createUiDefinition.json` in the Azure portal CreateUiDefinition Sandbox.
10. Scan templates and application components for secrets and vulnerabilities.
11. Review RBAC assignments, deny assignments, network exposure, data handling,
    diagnostics, regional availability, quotas, and cost.
12. Deploy the package into a non-production subscription.
13. Test create, update, failure recovery, support access, and deletion.
14. Test with identities that represent both publisher and customer roles.

Follow the official
[Azure Managed Application service catalog quickstart](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/publish-service-catalog-app)
for an internal test before external publication.

### Phase 3: Create The Marketplace Offer

1. Sign in to [Partner Center](https://partner.microsoft.com/dashboard/home).
2. Open **Marketplace offers**.
3. Select **New offer** and then **Azure Application**.
4. Enter a permanent, unique offer ID using lowercase letters, numbers, hyphens,
   or underscores.
5. Enter the internal offer alias.
6. Select the verified publisher account.
7. Complete offer setup and optional lead management.
8. Complete properties, categories, industries, legal terms, and contracts.
9. Complete the customer-facing listing, search terms, images, support, privacy,
   and documentation links.
10. Add a preview audience using controlled test accounts.
11. Create a plan and choose the appropriate Azure Application plan type.
12. Configure pricing, markets, availability, and technical package details.
13. Provide Microsoft Entra tenant and application IDs only when required for
    metered billing authentication.
14. Upload the validated Managed Application package.
15. Save the draft and resolve validation errors.

Use the official
[Azure Application offer instructions](https://learn.microsoft.com/partner-center/marketplace-offers/azure-app-offer-setup)
as the source of truth because Partner Center fields can change.

### Phase 4: Preview, Certify, And Go Live

1. Submit the offer for preview.
2. Wait for automated validation and certification feedback.
3. Resolve every blocking issue and resubmit when needed.
4. Ask preview users to deploy the offer into clean test subscriptions.
5. Verify deployment, billing, identity, telemetry, support, upgrades, and
   deletion from the customer perspective.
6. Obtain security, privacy, accessibility, legal, support, and business owner
   approval.
7. Select the Partner Center action to make the certified offer live.
8. Monitor acquisition, deployment failures, support contacts, and health.
9. Maintain a tested update and rollback process for future versions.

## Publish A Microsoft 365 Copilot Agent

### Phase 1: Choose A Supported Route

1. Choose **Microsoft 365 Copilot Agent Builder** for a declarative agent shared
   within one organization.
2. Choose **Microsoft 365 Agents Toolkit** for a packaged declarative or custom
   engine agent that can target an organizational catalog or Microsoft
   Marketplace.
3. Choose **Copilot Studio** when its capabilities and supported distribution
   options match the product.
4. Confirm whether the goal is personal testing, organizational Agent Store, or
   public commercial marketplace distribution.

> [!NOTE]
> Agent Builder supports organizational catalog submission but not Microsoft
> Commercial Marketplace submission. Agents Toolkit supports organizational
> catalog and commercial marketplace paths. Copilot Studio support varies by
> agent type and distribution route. Verify the current
> [Microsoft 365 Copilot publishing matrix](https://learn.microsoft.com/microsoft-365-copilot/extensibility/publish)
> before implementation.

### Phase 2: Build And Test The Agent

1. Create the agent in the selected tool.
2. Add the reviewed name, description, instructions, conversation starters, and
   approved knowledge sources.
3. Connect the Azure application through an authenticated API or supported
   action.
4. Apply delegated or application permissions according to least privilege.
5. Add authorization checks in the Azure service, not only in agent prompts.
6. Add citations, uncertainty behavior, feedback, and human escalation.
7. Prepare the Microsoft 365 app package, manifest, icons, and required agent
   files when using Agents Toolkit.
8. Run manifest and Responsible AI validation.
9. Sideload into a test tenant with administrator approval.
10. Test expected prompts, prohibited prompts, unauthorized access, missing
    content, dependency failures, prompt injection, and harmful output handling.
11. Complete security, privacy, accessibility, Responsible AI, and support
    reviews.

### Phase 3A: Publish To An Organizational Agent Store

1. Confirm the tenant allows custom app or agent submissions.
2. Submit the agent to the organizational catalog from the selected tool.
3. Ask the Microsoft 365 or Teams administrator to review the submission.
4. Provide test evidence, data handling details, permission rationale, support
   information, and the intended audience.
5. Ask the administrator to approve and publish the agent.
6. Confirm the agent appears in the Agent Store under **Built by your org**.
7. Assign or enable the agent for a pilot group.
8. Verify installation and usage with a non-maker account.

### Phase 3B: Publish Through Microsoft Marketplace

1. Confirm the agent type supports commercial marketplace submission.
2. Enroll the verified Partner Center publisher in the **Microsoft 365 and
   Copilot** program.
3. Review Microsoft Commercial Marketplace certification policies.
4. Review Microsoft 365 Store validation guidelines for agents.
5. Complete Responsible AI validation checks.
6. Prepare customer-facing descriptions, icons, privacy policy, terms, support,
   setup instructions, and test credentials when required.
7. In Partner Center, create the offer type **Apps and agents for Microsoft 365
   and Copilot**.
8. Upload the validated Microsoft 365 app package.
9. Complete listing, availability, technical, and certification information.
10. Submit the offer for validation.
11. Resolve certification findings and resubmit.
12. After approval, coordinate IT enablement in a customer tenant.
13. Confirm the enabled agent appears in the Microsoft 365 Copilot Agent Store.

## Final Release Gate

Do not release either product until accountable humans confirm:

1. Requirements and architecture are approved.
2. Threat modeling and security testing are complete.
3. Privacy, data residency, retention, and deletion are documented.
4. Accessibility checks are complete.
5. Responsible AI risks, evaluation results, and mitigations are reviewed.
6. Customer and publisher permissions follow least privilege.
7. Cost, metering, licensing, support, incident response, and service ownership
   are defined.
8. Preview deployments and pilot agent installations succeeded.
9. Rollback, update, monitoring, and customer communication plans exist.
10. Partner Center and tenant administrators have granted required approvals.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
