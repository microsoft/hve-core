# 09 Misinformation

Identifier: LLM09:2025
Category: Output Reliability

## Description

Misinformation from LLMs poses a core vulnerability for applications relying on these models.
Misinformation occurs when LLMs produce false or misleading information that appears credible.
This vulnerability can lead to security breaches, reputational damage, and legal liability.

One of the major causes of misinformation is hallucination — when the LLM generates content
that seems accurate but is fabricated. Hallucinations occur when LLMs fill gaps in their
training data using statistical patterns without truly understanding the content.

A related issue is overreliance, where users place excessive trust in LLM-generated content,
failing to verify its accuracy. This exacerbates the impact of misinformation, as users may
integrate incorrect data into critical decisions without adequate scrutiny.

## Common examples

1. The model produces incorrect statements leading users to make decisions based on false
   information, as demonstrated by Air Canada's chatbot providing misinformation to
   travelers, resulting in legal action.
2. The model generates baseless assertions, harmful in sensitive contexts such as healthcare
   or legal proceedings, as seen with ChatGPT fabricating fake legal cases.
3. The model gives the illusion of understanding complex topics, misleading users regarding
   its level of expertise, such as chatbots misrepresenting health-related issue complexity.
4. The model suggests insecure or non-existent code libraries that introduce vulnerabilities
   when integrated into software systems.

## Attack scenarios

### Scenario A — Malicious package hallucination

Attackers experiment with coding assistants to find commonly hallucinated package names.
They publish malicious packages with those names to widely used repositories. Developers
unknowingly integrate these poisoned packages, leading to unauthorized access, malicious
code injection, or backdoors.

### Scenario B — Unreliable medical chatbot

A company provides a chatbot for medical diagnosis without ensuring sufficient accuracy.
The chatbot provides poor information, leading to harmful consequences for patients. The
company is successfully sued for damages without any active attacker being involved.

## Prevention and mitigation

1. Use Retrieval-Augmented Generation (RAG) to enhance output reliability by retrieving
   verified information from trusted external databases during response generation.
2. Enhance the model with fine-tuning or embeddings to improve output quality using
   techniques such as parameter-efficient tuning (PET) and chain-of-thought prompting.
3. Encourage users to cross-check LLM outputs with trusted external sources and implement
   human oversight and fact-checking processes for critical information.
4. Implement tools and processes to automatically validate key outputs, especially in
   high-stakes environments.
5. Clearly communicate risks and limitations to users, including the potential for
   misinformation.
6. Establish secure coding practices to prevent integration of vulnerabilities due to
   incorrect code suggestions.
7. Design APIs and user interfaces that encourage responsible use, integrating content
   filters and clearly labeling AI-generated content.
8. Provide comprehensive training for users on LLM limitations and the importance of
   independent verification.

## References

* [AML.T0048.002 - Societal Harm](https://atlas.mitre.org/techniques/AML.T0048) — MITRE ATLAS

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
