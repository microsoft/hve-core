---
title: "Clause 12: Documentation and Support Services"
description: "Clause 12 of EN 301 549 V3.2.1 extends accessibility obligations beyond the ICT product itself and onto the documentation that accompanies it and the support services that customers rely on when so..."
---

# Clause 12: Documentation and Support Services

Clause 12 of EN 301 549 V3.2.1 extends accessibility obligations beyond the ICT product itself and onto the documentation that accompanies it and the support services that customers rely on when something goes wrong. Sub-clauses under 12.1 govern product documentation (what features must be described and what accessibility properties the documentation itself must satisfy), and sub-clauses under 12.2 govern the support channel (what accessibility information support agents must surface, how the support channel must accommodate users with disabilities, and what accessibility properties any documentation handed out through support must satisfy).

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 12, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-12-1-1

**12.1.1 Accessibility and compatibility features**

Product documentation shall describe the accessibility and compatibility features that the ICT exposes, including how to activate each feature, the configuration options it offers, any known limitations, and the assistive technologies the product has been tested with. The description shall be discoverable rather than buried as a footnote, so a user evaluating the product can locate the accessibility coverage without prior knowledge of the feature names.

**Applies to**: Feature documentation that ships with the product (printed manuals, in-product help, online documentation portals, release notes, conformance reports).

**WCAG cross-reference**: n/a (documentation-content requirement; not a UI behaviour rule).

**Assessment heuristics**:

* Inventory every accessibility feature the product exposes and confirm each one is documented with activation steps, configuration options, and limitations.
* Verify the documentation lists the assistive technologies the product has been validated against and the platform versions used during validation.
* Confirm the accessibility section is discoverable from the documentation entry points (table of contents, search index, on-product help launcher).
* Cross-check the documentation against the product accessibility conformance report so that no feature claimed in conformance is missing from user-facing documentation.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-12-1-2

**12.1.2 Accessible documentation**

The product documentation itself shall meet accessibility requirements equivalent to those that apply to the product. Web-delivered help shall meet the Clause 9 web requirements, downloadable documents shall meet the Clause 10 non-web document requirements, and in-product software help shall meet the Clause 11 software requirements. Inaccessible-only delivery (for example, scanned-image PDFs or video tutorials without captions and transcripts) does not satisfy the clause.

**Applies to**: Help content in every form the product ships it (HTML help portals, downloadable PDFs, embedded software help, printed manuals with electronic counterparts, video tutorials, in-product tooltips, getting-started guides).

**WCAG cross-reference**: n/a (clause defers to Clauses 9, 10, and 11 by reference rather than naming a specific WCAG SC).

**Assessment heuristics**:

* Pick the documentation delivery medium (web, document, software) and apply the corresponding clause group's reference file as the assessment checklist.
* Confirm video tutorials carry captions, transcripts, and audio descriptions where the visual track conveys information.
* Verify downloadable PDFs are tagged, contain real text rather than scanned images, and pass a tagged-PDF accessibility check.
* Confirm in-product help is reachable by keyboard, exposed to platform accessibility APIs, and respects user-configured text size and contrast settings.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-12-2-2

**12.2.2 Information on accessibility and compatibility features**

Support services shall be able to surface the same accessibility and compatibility feature information that Clause 12.1.1 places in product documentation. A user who contacts support shall be able to obtain a description of the available accessibility features, activation procedures, known limitations, and supported assistive technologies through the support channel rather than being redirected to documentation they may not be able to read.

**Applies to**: Support information surfaces (help-desk scripts, knowledge-base articles consumed by agents, chatbot responses, support portal landing pages, FAQ entries).

**WCAG cross-reference**: n/a (support-content requirement; not a UI behaviour rule).

**Assessment heuristics**:

* Confirm front-line support agents have a knowledge-base entry that summarises every accessibility feature with activation steps and known limitations.
* Verify the support portal lists the supported assistive technologies and links into the conformance report.
* Spot-check support transcripts to confirm accessibility questions receive substantive answers rather than redirects.
* Confirm that automated support channels (chatbots, IVR menus) recognise accessibility-related intents and route them to the correct knowledge entry or agent.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-12-2-3

**12.2.3 Effective communication**

Support services shall accommodate the communication needs of users with disabilities so that a user can request and receive support through a channel they can actually operate. The provider shall offer alternatives to voice-only telephony — for example, real-time text, TTY, video relay or sign-language interpretation, web chat, and email — and shall accept calls placed through telecommunications relay services without dropping or restricting them.

**Applies to**: Live support channels (telephone help desks, video support, web chat, email queues, in-person support counters) and the routing logic that delivers user contacts to those channels.

**WCAG cross-reference**: n/a (service-delivery requirement; not a UI behaviour rule).

**Assessment heuristics**:

* Confirm support is reachable through at least one text-based channel (web chat, email, SMS, or RTT) in addition to voice telephony.
* Verify support phone lines accept inbound relay-service calls and that agents are trained on relay protocol.
* Confirm video support offers captioning and, where the product market includes sign-language users, a sign-language interpretation option.
* Compare response-time service levels across channels and confirm the accessible channels are not deprioritised.
* Train support agents on accessibility-aware communication (plain language, willingness to repeat or rephrase, awareness of assistive-technology constraints).

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-12-2-4

**12.2.4 Accessible documentation**

Documentation handed to users through the support channel — knowledge-base articles, troubleshooting guides, follow-up emails, attachments, recorded training sessions — shall itself meet the accessibility requirements of the medium in which it is delivered. Web-delivered support content shall meet Clause 9, downloadable attachments shall meet Clause 10, and software-embedded help shall meet Clause 11; the support channel does not get a documentation accessibility exemption that the product documentation does not also enjoy.

**Applies to**: Support-delivered materials in every form (web knowledge-base articles, PDF guides emailed to users, screenshots and diagrams attached to tickets, recorded webinars and tutorials, transcripts).

**WCAG cross-reference**: n/a (clause defers to Clauses 9, 10, and 11 by reference rather than naming a specific WCAG SC).

**Assessment heuristics**:

* Apply the relevant clause-group reference file (9, 10, or 11) to every documentation artefact the support team distributes.
* Confirm that screenshots and diagrams attached to tickets carry alt text or are accompanied by a text description.
* Verify recorded webinars carry captions and that transcripts are offered alongside on-demand recordings.
* Confirm follow-up emails are sent as accessible HTML or plain text rather than as image-only graphics, and that any attached PDFs are tagged.
* Audit the support knowledge base on a regular cadence using the same accessibility tooling applied to the main product documentation.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
