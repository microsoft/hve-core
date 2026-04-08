---
title: 'LLM01: Prompt Injection'
description: OWASP LLM Top 10 reference for prompt injection vulnerabilities including direct and indirect injection attack patterns and mitigations
---

# 01 Prompt Injection

Identifier: LLM01:2025
Category: Input Integrity

## Description

A prompt injection vulnerability occurs when user prompts alter the LLM's behavior or output
in unintended ways. These inputs can affect the model even if they are imperceptible to humans,
as long as the content is parsed by the LLM.

Prompt injection vulnerabilities exist in how models process prompts, and how input may force
the model to incorrectly pass prompt data to other parts of the model, potentially causing
them to violate guidelines, generate harmful content, enable unauthorized access, or influence
critical decisions. Techniques like Retrieval Augmented Generation (RAG) and fine-tuning do
not fully mitigate prompt injection vulnerabilities.

Both prompt injection and jailbreaking are important concepts in LLM security. Jailbreaking
is designed to override the model's built-in safety alignment. Prompt injection uses crafted
or unexpected inputs to manipulate the model's responses, sometimes resulting in the bypassing
of safety mechanisms but not always.

Prompt injection can be classified into two types:

* **Direct Prompt Injection** occurs when user prompts directly change the behavior of the
  underlying model. This can be both intentional and unintentional. It acts as a direct input
  to the LLM, potentially leading to data exfiltration, social engineering, and other issues.
* **Indirect Prompt Injection** occurs when the LLM accepts input from external sources such
  as websites or files. The content may contain data that, when parsed by the LLM, changes
  its behavior. These injections can result in data exfiltration, social engineering, and
  harmful or unexpected results in agentic systems.

The rise of multimodal AI introduces additional prompt injection risks. Malicious instructions
may be embedded in images, audio, or other modalities that the model processes. As models
become capable of handling diverse inputs, traditional defenses may not cover all vectors, and
new prompt injection techniques may emerge by exploiting cross-modal interactions.

## Risk

* Disclosure of sensitive information through manipulated model outputs.
* Disclosure of AI system infrastructure details and system prompts.
* Content manipulation leading to inaccurate or biased outputs.
* Unauthorized access to functions and connected systems available to the LLM.
* Execution of arbitrary commands in connected systems.
* Manipulation of critical decision-making processes.
* Data exfiltration through indirect prompt injection via external content.
* Bypassing of safety guardrails and content filtering mechanisms.

## Vulnerability checklist

* User prompts are processed without input validation or filtering that could prevent model
  behavior alteration.
* External content from websites or files is processed by the LLM without segregation from
  user prompts.
* The LLM processes multimodal inputs without scanning for embedded malicious instructions.
* The LLM has access to privileged functions or backend systems without least privilege
  enforcement.
* High-risk actions can be performed by the LLM without human approval.
* No anomaly detection or monitoring is in place for LLM inputs and outputs.
* System prompts do not constrain model behavior with specific role and capability boundaries.
* Expected output formats are not defined or validated with clear specifications.
* Lesser-used languages or encoded text such as Base64 can bypass input filters.

## Prevention controls

1. Constrain model behavior with specific instructions about the model's role, capabilities,
   and limitations within the system prompt. Enforce strict context adherence, limit responses
   to specific tasks or topics, and instruct the model to ignore attempts to alter baseline
   instructions.
2. Define and validate expected output formats with clear specifications, detailed reasoning,
   and source citations. Use deterministic code to validate adherence to these formats.
3. Design input and output filtering with criteria for content in interactions. Apply filtering
   to both input from the user and output responses from the model.
4. Enforce privilege control and least privilege access to external systems with dedicated
   API tokens. Restrict the LLM to the minimum access level necessary for its operations.
5. Require human approval for high-risk actions with human-in-the-loop controls for privileged
   operations.
6. Segregate and identify external content to limit its influence on user prompts. Separate
   and clearly denote untrusted content.
7. Implement secure prompt engineering practices as a defense-in-depth strategy to make
   attacks more difficult.

## Example attack scenarios

### Scenario A — Direct injection on customer support

An attacker injects a prompt into a customer support chatbot, instructing it to ignore
previous guidelines, query private data stores, and exploit vulnerabilities in backend
systems, leading to unauthorized data access and privilege escalation.

### Scenario B — Indirect injection via webpage

A user employs an LLM to summarize a webpage that contains hidden instructions causing
the LLM to insert an image linking to a URL, which leads to exfiltration of the private
conversation.

### Scenario C — Unintentional injection via job description

A company includes a prompt in a job description to identify AI-generated applications. An
applicant, unaware of this, uses an LLM to optimize their resume, inadvertently triggering
the AI detection prompt and resulting in their application being rejected despite being
qualified and having submitted a genuine application.

### Scenario D — RAG content manipulation

An attacker modifies a document in a repository used by a RAG application. When a user's
query retrieves the modified content, the malicious instructions alter the LLM's output,
generating misleading results.

### Scenario E — Multi-modal injection

An attacker embeds a malicious prompt within an image that accompanies benign text. When
a multi-modal AI processes the image, it follows the hidden instructions, potentially
leading to unauthorized actions or data exposure.

### Scenario F — Payload splitting via resume

An attacker uploads a resume with split malicious prompts. When an LLM is used to evaluate
the candidate, the combined prompts manipulate the model's response, resulting in a positive
recommendation despite the actual resume contents.

### Scenario G — Adversarial suffix bypass

An attacker appends a seemingly meaningless string of characters to a prompt that serves as
an adversarial suffix, causing the LLM to disregard its safety guidelines and respond in
whatever way the attacker desires.

## Detection guidance

* Monitor LLM inputs and outputs regularly using anomaly detection to identify patterns
  indicative of prompt injection attempts.
* Use a separate LLM instance as a verifier to detect prompt injection attempts in user
  inputs.
* Review system prompt adherence by testing whether model responses deviate from defined
  role boundaries and output format specifications.
* Inspect external content sources for hidden instructions before they are processed by
  the LLM.
* Log and analyze all interactions for unusual patterns such as attempts to override system
  instructions or extract sensitive information.
* Test for prompt injection by submitting known injection payloads and evaluating model
  responses.

## Remediation

* Implement input and output filtering to block known injection patterns and enforce content
  criteria on all interactions.
* Enforce privilege control on all external systems accessible by the LLM, revoking any
  unnecessary access.
* Add human-in-the-loop controls for all high-risk operations that the LLM can trigger.
* Segregate and clearly denote all external content processed by the LLM to limit its
  influence on user prompts.
* Constrain model behavior through updated system prompts with specific role and capability
  boundaries.
* Deploy anomaly detection and monitoring on all LLM inputs and outputs to detect and
  respond to injection attempts.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
