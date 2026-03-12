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

Prompt injection can be classified into two types:

* **Direct Prompt Injection** occurs when user prompts directly change the behavior of the
  underlying model. This can be both intentional and unintentional.
* **Indirect Prompt Injection** occurs when the LLM accepts input from external sources such
  as websites or files. The content may contain data that, when parsed by the LLM, changes
  its behavior.

The rise of multimodal AI introduces additional prompt injection risks. Malicious instructions
may be embedded in images, audio, or other modalities that the model processes.

## Common examples

1. An attacker injects a prompt into a customer support chatbot, instructing it to ignore
   previous guidelines and query private data stores.
2. A user employs an LLM to summarize a webpage that contains hidden instructions causing
   the LLM to exfiltrate private conversation data via an image link.
3. A company includes a prompt in a job description to identify AI-generated applications,
   inadvertently penalizing legitimate applicants who used an LLM to optimize their resume.
4. An attacker modifies a document in a RAG repository to alter the LLM's output with
   misleading results.
5. An attacker exploits an LLM-powered email assistant via prompt injection to access
   sensitive information and manipulate email content.
6. An attacker uploads a resume with split malicious prompts that, when combined by the LLM,
   manipulate the evaluation response.
7. An attacker embeds a malicious prompt within an image processed by a multi-modal AI,
   leading to unauthorized actions or data exposure.
8. An attacker appends adversarial suffix characters to bypass safety guidelines.
9. An attacker uses lesser-used languages or Base64 encoding to bypass filters.

## Attack scenarios

### Scenario A — Direct injection on customer support

An attacker injects a prompt into a customer support chatbot, instructing it to ignore
previous guidelines, query private data stores, and exploit vulnerabilities in backend
systems, leading to unauthorized data access and privilege escalation.

### Scenario B — Indirect injection via webpage

A user employs an LLM to summarize a webpage that contains hidden instructions causing
the LLM to insert an image linking to a URL, which leads to exfiltration of the private
conversation.

### Scenario C — RAG content manipulation

An attacker modifies a document in a repository used by a RAG application. When a user's
query retrieves the modified content, the malicious instructions alter the LLM's output,
generating misleading results.

### Scenario D — Multi-modal injection

An attacker embeds a malicious prompt within an image that accompanies benign text. When
a multi-modal AI processes the image, it follows the hidden instructions, potentially
leading to unauthorized actions or data exposure.

## Prevention and mitigation

1. Constrain model behavior with specific instructions about the model's role, capabilities,
   and limitations within the system prompt.
2. Define and validate expected output formats with clear specifications, detailed reasoning,
   and source citations.
3. Design input and output filtering with criteria for content in interactions.
4. Enforce privilege control and least privilege access to external systems with dedicated
   API tokens.
5. Require human approval for high-risk actions with human-in-the-loop controls.
6. Segregate and identify external content to limit its influence on user prompts.
7. Monitor LLM inputs and outputs regularly using anomaly detection.
8. Implement secure prompt engineering practices as a defense-in-depth strategy.
9. Use a separate LLM instance as a verifier to detect prompt injection attempts.

## References

* [AML.T0051.000 - LLM Prompt Injection: Direct](https://atlas.mitre.org/techniques/AML.T0051.000) — MITRE ATLAS
* [AML.T0051.001 - LLM Prompt Injection: Indirect](https://atlas.mitre.org/techniques/AML.T0051.001) — MITRE ATLAS
* [AML.T0054 - LLM Jailbreak Injection: Direct](https://atlas.mitre.org/techniques/AML.T0054) — MITRE ATLAS
