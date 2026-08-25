---
title: Outlook Draft Distribution
description: Capability detection, draft creation, traceability, and stop rules for optional Outlook distribution.
ms.date: 2026-08-24
ms.topic: reference
---

## Distribution outcome

Create one Outlook draft containing the user-approved report. Never send the
message.

## Preconditions

Continue only when:

* `distribution.outlook_draft.enabled` is `true`
* The user approved the final report
* After the report was saved, the user separately approved Outlook draft
  creation
* WorkIQ exposes `create_entity` or an equivalent draft-create capability
* Recipient fields and subject substitutions are valid

If a precondition fails, record `Distribution skipped` and continue report
completion.

## Draft creation

1. Resolve the configured subject template using customer, engagement, date,
   and report type
2. Read recipients from the configured `to`, `cc`, and `bcc` lists
3. Convert the approved report from Markdown to HTML while preserving tables
   and lists
4. Exclude working-file references and unapproved evidence appendices
5. When WorkIQ `create_entity` is available, create the draft directly with:
   * `parentUrl`: `/me/messages`
   * `jsonBody`: a JSON-encoded Message with this shape:

     ```json
     {
       "subject": "Resolved subject",
       "body": {
         "contentType": "HTML",
         "content": "<p>Approved report HTML</p>"
       },
       "toRecipients": [
         {
           "emailAddress": {
             "address": "recipient@example.com"
           }
         }
       ],
       "ccRecipients": [],
       "bccRecipients": []
     }
     ```

   Convert every configured email string into an
   `{ "emailAddress": { "address": "..." } }` recipient object. An empty
   configured list becomes an empty recipient array.
6. Do not run schema discovery before this standard path
7. If the standard call fails specifically because the exposed interface or
   payload shape differs, inspect the schema once and retry once
8. Do not read generated schema files, enumerate unrelated Message operations,
   or perform a second report-validation pass
9. Do not invoke `sendMail`, a send action, or any equivalent operation

The workflow uses the draft-create operation only. It does not register or rely
on a hook, and it does not inspect or invoke transmission operations.

## Error handling

For the first interface-shape or payload-validation failure, perform the single
schema-assisted retry described above. Stop after the second shape or
validation failure.

Retry once for a transient connectivity failure. Stop immediately for a
permission failure. For terminal or repeated failures:

* Stop draft creation
* Do not fall back to sending
* Record a non-sensitive failure category in
  `.working/{date}-{report-type}/distribution.md`
* Complete the reporting workflow

Do not copy raw tool payloads or error responses into the distribution record.
Do not narrate schema inspection, payload validation, or draft-write mechanics
to the user. Report only `Draft created`, `Distribution skipped`, or the
specific action the user must take.

## Traceability

Record:

* Creation timestamp
* Draft-created status
* Recipient counts for `to`, `cc`, and `bcc`
* Approved report path
* Confirmation that the draft was not sent

Do not persist recipient addresses, subject text, draft identifiers, or Outlook
web links. Return the draft link transiently to the user when the tool provides
one, then tell the user to review and send the draft from Outlook.
