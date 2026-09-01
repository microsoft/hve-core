---
title: Outlook Draft Distribution
description: Capability detection, draft creation, traceability, and stop rules for optional Outlook distribution.
ms.date: 2026-09-01
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
* The Engagement Report Outlook Drafter and the WorkIQ Mail MCP server's
  dedicated `CreateDraftMessage` capability are available
* Recipient fields and subject substitutions are valid

If a precondition fails, record `Distribution skipped` and continue report
completion.

## Draft creation

1. Resolve the configured subject template using customer, engagement, date,
   and report type
2. Read recipients from the configured `to`, `cc`, and `bcc` lists
3. Render the approved Markdown body to HTML inline while preserving headings,
   links, ordered and unordered lists, bold, italic, and table markup
4. Stop distribution if faithful conversion is unavailable. Do not manually
   flatten Markdown or fall back to `contentType: "Text"`.
5. Inspect the rendered body before draft creation. When the Markdown contains
   a table, conversion succeeds only when the output contains `<table>`.
6. Exclude working-file references and unapproved evidence appendices from the
   approved Markdown before conversion
7. Make one WorkIQ Mail `CreateDraftMessage` attempt with this shape:

   ```json
   {
     "to": ["recipient@example.com"],
     "cc": [],
     "bcc": [],
     "subject": "Resolved subject",
     "body": "<p>Approved report HTML</p>",
     "contentType": "HTML"
   }
   ```

   Pass configured email strings directly in the matching recipient arrays. An
   empty configured list becomes an empty array. The `body` is the rendered
   HTML and `contentType` is always `HTML`.
8. Before draft creation, verify the payload still contains
   `"contentType": "HTML"` and, for a tabular report, `<table>`. Stop when either
   invariant is missing.
9. Do not run schema discovery, enumerate unrelated mail operations, or perform
   a second report-validation pass
10. Do not retry draft creation after any response or connectivity failure; a
   failed response does not prove that the service did not create the draft
11. Do not invoke `sendMail`, a send action, or any equivalent operation

The Outlook Drafter is granted only the dedicated draft-create operation. It
does not register or rely on a hook, and it cannot inspect or invoke
transmission operations.

## Error handling

Conversion and structure-validation failures are terminal. Do not create a
draft with flattened or plain-text content.

After an ambiguous response or connectivity failure, record `Draft status
unknown` and require the user to inspect Outlook before authorizing any later
attempt. Stop immediately for a permission failure. For terminal failures:

* Stop draft creation
* Do not fall back to sending
* Record a non-sensitive failure category in
  `.working/{date}-{report-type}/distribution.md`
* Complete the reporting workflow

Do not copy raw tool payloads or error responses into the distribution record.
Do not narrate schema inspection, payload validation, or draft-write mechanics
to the user. Report only `Draft created`, `Draft status unknown`, `Distribution skipped`, or
the specific action the user must take.

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
