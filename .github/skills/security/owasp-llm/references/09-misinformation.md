---
title: 'LLM09: Misinformation'
description: OWASP LLM Top 10 reference for misinformation risks where LLMs generate false or misleading content presented as factual
---

# 09 Misinformation

Identifier: LLM09:2025
Category: Output Reliability

## Description

Misinformation from LLMs poses a core vulnerability for applications relying on these models.
Misinformation occurs when LLMs produce false or misleading information that appears credible.
This vulnerability can lead to security breaches, reputational damage, and legal liability.

One of the major causes of misinformation is hallucination — when the LLM generates content
that seems accurate but is fabricated. Hallucinations occur when LLMs fill gaps in their
training data using statistical patterns without truly understanding the content. While
hallucinations are a major source of misinformation, they are not the only cause; biases
introduced by the training data and incomplete information can also contribute.

A related issue is overreliance, where users place excessive trust in LLM-generated content,
failing to verify its accuracy. This overreliance exacerbates the impact of misinformation,
as users may integrate incorrect data into critical decisions or processes without adequate
scrutiny.

## Risk

* Security breaches from users making decisions based on false or fabricated information.
* Reputational damage from LLM-generated misinformation attributed to the organization.
* Legal liability from harmful or incorrect LLM outputs, as demonstrated by legal actions
  against organizations whose chatbots provided misinformation.
* Healthcare harm from inaccurate medical information or misrepresentation of treatment
  complexity.
* Legal complications from fabricated case citations or baseless assertions in legal
  proceedings.
* Software vulnerabilities introduced through hallucinated or insecure code library
  suggestions.
* Erosion of user trust from the model giving the illusion of understanding complex topics
  it does not actually comprehend.

## Vulnerability checklist

* The LLM generates factually incorrect statements that users may rely on for decisions.
* No Retrieval-Augmented Generation mechanism is in place to ground model outputs in
  verified external data.
* Users are not informed about the potential for LLM misinformation or hallucination.
* No automatic validation mechanisms exist for key LLM outputs in high-stakes environments.
* Code suggestions from the LLM are not verified against trusted package registries before
  integration.
* Human oversight and fact-checking processes are absent for critical or sensitive
  information.
* AI-generated content is not clearly labeled in user interfaces.
* Users are not provided domain-specific training to evaluate LLM outputs within their field
  of expertise.

## Prevention controls

1. Use Retrieval-Augmented Generation (RAG) to enhance output reliability by retrieving
   relevant and verified information from trusted external databases during response
   generation.
2. Enhance the model with fine-tuning or embeddings to improve output quality. Techniques
   such as parameter-efficient tuning (PET) and chain-of-thought prompting can help reduce
   the incidence of misinformation.
3. Encourage users to cross-check LLM outputs with trusted external sources. Implement human
   oversight and fact-checking processes, especially for critical or sensitive information.
   Ensure that human reviewers are properly trained to avoid overreliance on AI-generated
   content.
4. Implement tools and processes to automatically validate key outputs, especially in
   high-stakes environments.
5. Clearly communicate risks and limitations to users, including the potential for
   misinformation. Identify the risks and possible harms associated with LLM-generated
   content.
6. Establish secure coding practices to prevent integration of vulnerabilities due to
   incorrect code suggestions.
7. Design APIs and user interfaces that encourage responsible use, integrating content
   filters, clearly labeling AI-generated content, and informing users on limitations of
   reliability and accuracy.
8. Provide comprehensive training for users on LLM limitations, the importance of independent
   verification of generated content, and the need for critical thinking. In specific
   contexts, offer domain-specific training to ensure users can effectively evaluate LLM
   outputs within their field of expertise.

## Example attack scenarios

### Scenario A — Malicious package hallucination

Attackers experiment with popular coding assistants to find commonly hallucinated package
names. Once they identify these frequently suggested but nonexistent libraries, they publish
malicious packages with those names to widely used repositories. Developers, relying on the
coding assistant's suggestions, unknowingly integrate these poisoned packages into their
software, leading to unauthorized access, malicious code injection, or backdoors.

### Scenario B — Unreliable medical chatbot

A company provides a chatbot for medical diagnosis without ensuring sufficient accuracy.
The chatbot provides poor information, leading to harmful consequences for patients. As a
result, the company is successfully sued for damages. In this case, the safety and security
breakdown did not require a malicious attacker but arose from insufficient oversight and
reliability of the LLM system.

## Detection guidance

* Monitor model outputs for factual accuracy through automated validation tools that
  cross-reference responses against trusted knowledge bases.
* Cross-check LLM outputs with trusted external sources to identify fabricated or
  unsupported claims.
* Test for hallucination by evaluating model responses against known facts in controlled
  test scenarios.
* Review code suggestions for references to non-existent libraries or packages by validating
  against package registries.
* Audit model responses in high-stakes environments for unsupported claims or baseless
  assertions.
* Track user reports of inaccurate information to identify patterns in model misinformation.

## Remediation

* Implement Retrieval-Augmented Generation to ground model outputs in verified information
  from trusted external databases.
* Enhance the model with fine-tuning or embeddings using techniques such as parameter-
  efficient tuning and chain-of-thought prompting to improve output quality.
* Add human oversight and fact-checking processes for all critical or sensitive information.
* Deploy automatic validation mechanisms for key outputs in high-stakes environments.
* Clearly label AI-generated content and communicate risks and limitations to users.
* Establish secure coding practices and verification processes for all LLM-suggested code
  and packages before integration.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
