---
description: "When generating, reviewing, or refactoring code that interacts with Large Language Models (LLMs), read and follow these OWASP Top 10 for LLM Applications (2025) secure coding guidelines to protect against prompt injection, data leakage, and LLM-specific vulnerabilities. Apply these instructions to any LLM integration, agent framework, RAG pipeline, or AI-powered feature. Provide clear and concise security feedback and points of improvement."
maturity: experimental
---

# OWASP Top 10 for LLM Applications - Secure Coding Guidelines

## Instructions

When working with Large Language Model (LLM) applications, ensure all code generated, reviewed, or refactored is secure by default with specific attention to LLM-unique vulnerabilities. Operate with a security-first mindset that recognizes LLMs introduce an entirely new class of risks beyond traditional application security. When in doubt, choose the more secure option and explain the reasoning.

Follow the principles outlined below, which are based on the OWASP Top 10 for LLM Applications (2025).

LLM applications are non-deterministic systems that require defense-in-depth strategies. Unlike traditional applications, LLMs can be manipulated through natural language, making input validation, output handling, and access control fundamentally more complex. Implement multiple layers of security controls rather than relying on a single defense mechanism.

### LLM01:2025 Prompt Injection

#### Core Risk

Prompt injection is the most critical LLM vulnerability, analogous to SQL injection but targeting the model's prompt context. User inputs can manipulate the LLM's behavior, override system instructions, extract sensitive information, or trigger unauthorized actions.

#### Constrain Model Behavior

Define strict boundaries for LLM responses using explicit system prompts that clearly delineate acceptable outputs. Do not rely solely on system prompts for security as they can be bypassed.

#### Input Validation

Apply rigorous validation to all user inputs before they reach the LLM. Use allowlists for expected input patterns, reject suspicious patterns (e.g., instructions like "ignore previous instructions"), and implement semantic analysis to detect manipulation attempts.

#### Output Validation

Validate all LLM outputs against expected formats using deterministic verification. Define strict output schemas and reject responses that deviate from them.

#### Context Boundaries

Separate system instructions from user content using clear delimiters. Do not concatenate user input directly into prompts without sanitization.

<!-- <example-prompt-injection-defense> -->
```python
# ✅ GOOD: Structured prompt with clear boundaries
system_prompt = "You are a customer service assistant. Only answer questions about product features."
user_input = sanitize_input(request.user_message)  # Remove injection attempts
response = llm.generate(system=system_prompt, user=user_input)
validated_response = validate_output_schema(response)  # Ensure format compliance

# ❌ BAD: Direct concatenation with no validation
prompt = f"Answer this: {request.user_message}"  # Vulnerable to injection
response = llm.generate(prompt)  # No output validation
```
<!-- </example-prompt-injection-defense> -->

#### Indirect Injection Defense

When processing external content (files, websites, documents), treat all content as potentially malicious. Sanitize or summarize external data before including it in prompts.

#### Multimodal Risks

Vision and audio models can contain hidden instructions embedded in images or audio files. Implement content integrity checks for multimodal inputs.

### LLM02:2025 Sensitive Information Disclosure

#### Secrets in Prompts

System prompts, user inputs, and model responses can all leak sensitive information. Do not embed API keys, passwords, tokens, PII, or proprietary algorithms in prompts or training data.

#### Data Sanitization

Apply robust data sanitization for both inputs and outputs. Use PII detection tools to identify and redact sensitive information before it reaches the LLM or gets displayed to users.

#### Output Schema Validation

Define strict output schemas that prevent the model from generating sensitive data formats. Use context-appropriate encoding for all outputs (HTML encoding for web display, etc.).

#### Sandboxed Execution

When executing LLM-generated code (which should be avoided when possible), use sandboxed environments with no access to sensitive resources.

<!-- <example-sensitive-info-disclosure> -->
```typescript
// ✅ GOOD: Sanitized context with PII detection
const sanitizedContext = await piiDetector.redact(userDocument);
const prompt = `Summarize this document: ${sanitizedContext}`;
const response = await llm.complete(prompt);
const safeOutput = encodeForContext(response, 'html');

// ❌ BAD: Direct exposure of sensitive data
const prompt = `Analyze this customer: Name: ${customer.name}, SSN: ${customer.ssn}, Income: ${customer.income}`;
// System prompt leaks: "You have access to database: postgres://admin:password@..."
```
<!-- </example-sensitive-info-disclosure> -->

#### Training Data Extraction Defense

Models can potentially reproduce verbatim content from training data. Implement differential privacy techniques and audit mechanisms to detect when models are leaking training data.

#### Separation of Concerns

Store sensitive data in systems that the LLM cannot directly access. Pass only anonymized or minimal data to the model.

### LLM03:2025 Supply Chain

#### Model Provenance Verification

Only use pre-trained models from trusted sources with verified provenance. Verify cryptographic signatures and checksums for all downloaded models.

#### Model Source Trust

Default to established model providers (OpenAI, Azure OpenAI, Anthropic, Google) with strong security postures. Exercise caution with community models from Hugging Face or other repositories without security audits.

#### Dependency Management

Maintain a comprehensive Software Bill of Materials (SBOM) for all AI/ML dependencies. This includes models, fine-tuning adapters (LoRA), embedding models, and ML libraries.

<!-- <example-supply-chain-verification> -->
```python
# ✅ GOOD: Verified model loading with integrity checks
model_hash = verify_model_signature(model_path, expected_signature)
if model_hash != TRUSTED_MODEL_HASH:
    raise SecurityError("Model integrity verification failed")
model = load_model(model_path)

# ❌ BAD: Loading unverified models
model = load_model_from_url(untrusted_url)  # No verification
```
<!-- </example-supply-chain-verification> -->

#### Red Team Testing

Before deploying any third-party model, conduct rigorous adversarial testing including prompt injection attempts, jailbreaking tests, and bias evaluation.

#### Model Isolation

Isolate model development and deployment environments. Use separate credentials and networks. Apply least privilege access controls to model files and APIs.

#### Third-Party Component Monitoring

Regularly scan all ML frameworks (PyTorch, TensorFlow, Transformers) for vulnerabilities. Update promptly when security patches are released.

#### On-Device Model Security

When deploying models to edge devices, implement secure boot chains, encrypted model storage, and integrity monitoring to prevent tampering.

### LLM04:2025 Data and Model Poisoning

#### Data Provenance Tracking

Implement comprehensive tracking for all training and fine-tuning data. Maintain audit logs showing data source, collection date, validation status, and any transformations applied.

#### Pre-Training Data Validation

Before incorporating data into training or fine-tuning sets, apply content validation to detect malicious patterns, hidden instructions, or biased content.

<!-- <example-data-poisoning-defense> -->
```python
# ✅ GOOD: Validated data pipeline with provenance
training_data = load_dataset(source="trusted_repository")
validated_data = data_validator.scan_for_poisoning(training_data)
provenance_log.record(source, validation_result, timestamp)
if validated_data.risk_score > THRESHOLD:
    raise SecurityError("Data poisoning detected")

# ❌ BAD: Unvalidated data ingestion
training_data = scrape_web_content(urls)  # No validation
model.fine_tune(training_data)  # Poisoned data risk
```
<!-- </example-data-poisoning-defense> -->

#### Adversarial Testing for Backdoors

After training or fine-tuning, conduct adversarial testing to detect backdoor triggers. Test with known poisoning patterns and unexpected inputs.

#### Data Versioning

Use data versioning systems (DVC, MLflow) to track changes and enable rollback if poisoning is detected. Monitor for anomalous changes in dataset characteristics (distribution shifts, unexpected tokens).

#### RAG Grounding

Use Retrieval-Augmented Generation (RAG) with trusted, curated knowledge bases to validate model outputs against authoritative sources. This helps detect when poisoned training data influences outputs.

#### Split-View Defense

Split-view poisoning attacks use training examples that appear legitimate but contain hidden patterns. Implement automated anomaly detection on training data distributions.

#### Access Control for Training Data

Restrict who can add or modify training datasets. Implement multi-party approval for training data changes and maintain immutable audit logs.

### LLM05:2025 Improper Output Handling

#### Core Understanding

User prompts can influence LLM outputs, effectively giving users indirect access to any downstream system that processes LLM responses. Treat all LLM outputs as untrusted user input.

#### Context-Aware Output Encoding

Apply strict context-appropriate encoding based on where LLM output will be used:

- HTML context: use HTML entity encoding to prevent XSS
- SQL context: use parameterized queries, never concatenate LLM output into SQL
- Shell context: use proper escaping or avoid shell execution entirely
- JavaScript context: JSON encode and validate

#### Direct Execution Risks

Avoid executing LLM-generated code, commands, or queries without thorough validation and sandboxing.

<!-- <example-output-handling> -->
```javascript
// ✅ GOOD: Validated and encoded output
const llmResponse = await llm.generate(userPrompt);
const validatedResponse = outputValidator.validate(llmResponse, expectedSchema);
const safeHtml = DOMPurify.sanitize(validatedResponse.html);
const escapedText = escapeHtml(validatedResponse.text);

// ❌ BAD: Direct execution of LLM output
const llmCode = await llm.generate("Write a function to...");
eval(llmCode);  // Critical vulnerability: arbitrary code execution

const sqlQuery = await llm.generate("Generate SQL for...");
db.execute(sqlQuery);  // SQL injection via LLM
```
<!-- </example-output-handling> -->

#### Parameterized Interfaces

When LLM outputs must interact with databases or APIs, use parameterized queries and structured API calls. Extract parameters from LLM output, validate them, then use them in safe interfaces.

#### Content Security Policy

Implement strict CSP headers to mitigate potential XSS from LLM-generated content. Set `script-src 'self'` and avoid `unsafe-inline`.

#### Path Traversal Protection

When LLM generates file paths, canonicalize and validate they remain within allowed directories. Reject patterns like `../` or absolute paths outside the sandbox.

### LLM06:2025 Excessive Agency

#### Least Privilege for LLM Agents

Grant LLM-based agents only the minimum functionality, permissions, and autonomy required for their specific purpose. Every function call the LLM can make increases attack surface.

#### Functionality Restriction

Only expose functions/tools to the LLM that are absolutely necessary. Remove or disable any extensions, plugins, or APIs that are not core to the application's purpose.

#### Permission Scoping

Extensions and functions should operate with minimal privileges. Do not connect an LLM agent to systems with admin rights or broad data access.

<!-- <example-excessive-agency> -->
```python
# ✅ GOOD: Minimal permissions with explicit allowlist
allowed_functions = ["search_knowledge_base", "format_response"]  # Limited scope
agent = LLMAgent(
    functions=allowed_functions,
    permissions=ReadOnlyPermissions(scope="public_docs"),
    require_approval=True  # Human-in-the-loop for actions
)

# ❌ BAD: Excessive permissions and functionality
agent = LLMAgent(
    functions=all_system_functions,  # Everything exposed
    permissions=AdminPermissions(),  # Full access
    autonomous=True  # No oversight
)
```
<!-- </example-excessive-agency> -->

#### Human-in-the-Loop for High-Impact Actions

Any action that modifies data, makes external calls, or affects system state requires explicit human approval. Do not allow fully autonomous operation for sensitive functions.

#### Action Validation

Before executing any LLM-requested action, validate it against business rules using deterministic code (not LLM-based validation which can be manipulated).

#### Function Call Auditing

Log every function call made by the LLM agent including parameters, user context, and results. Monitor for suspicious patterns like repeated failed authorization attempts.

#### Agent Privilege Separation

Use multiple specialized agents with different privilege levels rather than one powerful agent. A customer-facing agent should be completely isolated from backend admin functions.

### LLM07:2025 System Prompt Leakage

#### Externalize Sensitive Data

Do not include credentials, API keys, tokens, database connection strings, or other secrets in system prompts. Store these in secure vaults (Azure Key Vault, AWS Secrets Manager) that the LLM cannot access directly.

#### Security Through Architecture

Do not rely on system prompts to enforce security controls. Authorization checks, rate limiting, input validation, and other security mechanisms belong in deterministic code outside the LLM.

<!-- <example-system-prompt-leakage> -->
```python
# ✅ GOOD: Security controls outside LLM
def process_request(user_id, request):
    # Deterministic authorization check - NOT in prompt
    if not has_permission(user_id, request.resource):
        raise AuthorizationError("Access denied")
    
    # System prompt contains no secrets
    system_prompt = "You are a helpful assistant. Answer user questions about public documentation."
    response = llm.generate(system=system_prompt, user=request.message)
    return validate_output(response)

# ❌ BAD: Security in system prompt (bypassable)
system_prompt = f"""
You are a banking assistant. 
Database password: {DB_PASSWORD}  # CRITICAL: Secret exposure
API Key: {API_KEY}
Only allow transactions under $1000.  # Security rule in prompt - bypassable
Only users with role='admin' can access account details.  # Auth in prompt - wrong
"""
```
<!-- </example-system-prompt-leakage> -->

#### Assume Prompt Leakage

Design systems assuming attackers will obtain the complete system prompt. The prompt should contain only operational instructions, not security controls or sensitive information.

#### Multi-Agent Architecture

For applications requiring different privilege levels, use separate LLM agents with distinct system prompts and permissions rather than encoding role-based logic in a single prompt.

#### Business Logic Externalization

Critical business rules (transaction limits, approval workflows, access policies) belong in application code with proper authorization, not in system prompts.

#### Prompt Injection Resistance

Even when system prompts contain no secrets, their disclosure helps attackers craft effective prompt injection attacks. Use techniques like instruction hierarchy and output validation to maintain control.

### LLM08:2025 Vector and Embedding Weaknesses

#### RAG Security Risks

Retrieval-Augmented Generation (RAG) systems using vector databases introduce unique security challenges. Vectors can leak information, enable unauthorized access, and be poisoned with malicious content.

#### Permission-Aware Vector Search

Implement fine-grained access controls at the vector database level. When retrieving embeddings, filter results based on the current user's permissions. Do not rely on the LLM to enforce access control.

<!-- <example-vector-embedding-security> -->
```python
# ✅ GOOD: Permission-aware retrieval
def retrieve_context(query, user_id):
    query_embedding = embed(query)
    # Filter by user permissions BEFORE retrieval
    results = vector_db.search(
        query_embedding,
        filter={"allowed_users": user_id, "classification": "public"},
        namespace=get_user_namespace(user_id)  # Logical partitioning
    )
    return results

# ❌ BAD: No access control on retrieval
def retrieve_context(query):
    query_embedding = embed(query)
    results = vector_db.search(query_embedding)  # Returns everything
    # Hoping LLM will filter - WRONG
    return results
```
<!-- </example-vector-embedding-security> -->

#### Multi-Tenant Isolation

In multi-tenant environments, strictly partition vector databases by tenant. Use separate namespaces, collections, or database instances. Do not allow cross-tenant queries.

#### Validate Data Before Embedding

Before adding documents to vector databases, scan for hidden content, malicious instructions, or sensitive information. Implement automated content validation.

#### Data Classification and Tagging

Tag all vectors with metadata about sensitivity level, required permissions, and data classification. Enforce tag-based access controls during retrieval.

#### Embedding Inversion Defense

Attackers may attempt to reconstruct original content from embeddings. For highly sensitive data, consider not using RAG for sensitive content, applying additional encryption to embeddings, or using differential privacy techniques.

#### Audit and Monitoring

Maintain comprehensive, immutable logs of all vector database queries including user context, retrieved documents, and timestamps. Monitor for suspicious access patterns (high-volume queries, cross-context leakage attempts).

#### Hidden Text Detection

Scan documents for invisible text, white-on-white text, or other hidden content before embedding. Attackers may inject hidden instructions into documents that later influence model behavior.

#### Regular Security Audits

Periodically audit vector databases for unauthorized data, permission misconfigurations, and orphaned embeddings from deleted users.

### LLM09:2025 Misinformation

#### RAG for Factual Grounding

Use Retrieval-Augmented Generation to ground model responses in verified, authoritative information sources. This significantly reduces hallucinations for factual queries.

#### Automatic Fact Verification

For critical applications, implement automated fact-checking that validates key claims in LLM outputs against trusted databases or knowledge bases before displaying to users.

<!-- <example-misinformation-defense> -->
```python
# ✅ GOOD: RAG with verification
def generate_response(query):
    # Retrieve from curated knowledge base
    authoritative_docs = retrieve_verified_documents(query)
    
    # Ground response in retrieved facts
    response = llm.generate(
        system="Base your answer ONLY on the provided documents.",
        context=authoritative_docs,
        user=query
    )
    
    # Verify critical facts
    verification_result = fact_checker.verify(response, authoritative_docs)
    if verification_result.confidence < 0.8:
        return "I don't have reliable information about this."
    
    return add_uncertainty_indicators(response)

# ❌ BAD: No grounding or verification
def generate_response(query):
    response = llm.generate(query)  # Pure generation - high hallucination risk
    return response  # No fact checking or uncertainty communication
```
<!-- </example-misinformation-defense> -->

#### Communicate Uncertainty

Design UIs that clearly label AI-generated content and communicate reliability limitations. Use phrases like "Based on available information..." or "I'm not certain, but...".

#### Human-in-the-Loop for Critical Decisions

For high-stakes domains (healthcare, legal, financial), require human review of all LLM outputs before they are used for decision-making.

#### Code Generation Safety

When generating code, validate that suggested libraries and APIs actually exist. Implement checks against package registries before recommending installations. Warn users about the "hallucinated package" attack vector.

#### Domain-Specific Validation

For specialized domains, implement validation rules specific to that field (e.g., medical claim validation against clinical guidelines, legal citation verification).

#### Confidence Scoring

Where possible, implement or use confidence scoring mechanisms. Reject or flag low-confidence outputs for human review.

#### Adversarial Testing

Regularly test for hallucination patterns by asking questions with no correct answer or questions designed to trigger false information generation.

### LLM10:2025 Unbounded Consumption

#### Rate Limiting

Apply strict rate limits at multiple levels: per user, per IP address, per API key. Set both request count limits and token consumption limits.

<!-- <example-unbounded-consumption> -->
```python
# ✅ GOOD: Multi-layered rate limiting
@rate_limit(requests_per_minute=10, tokens_per_hour=100000)
@timeout(seconds=30)
def llm_endpoint(request):
    # Input size validation
    if len(request.message) > MAX_INPUT_SIZE:
        raise ValidationError("Input exceeds maximum size")
    
    # Output size control
    response = llm.generate(
        request.message,
        max_tokens=500,  # Hard limit
        timeout=20  # Prevent long-running queries
    )
    return response

# ❌ BAD: No resource controls
def llm_endpoint(request):
    # No rate limiting, input validation, or timeouts
    response = llm.generate(request.message)  # Unbounded
    return response
```
<!-- </example-unbounded-consumption> -->

#### Input Validation with Size Limits

Set reasonable maximum sizes for user inputs. Reject requests that exceed context window limits or that contain repetitive content designed to waste resources.

#### Output Token Limits

Set `max_tokens` parameters when calling LLMs. Use the minimum necessary for the use case.

#### Request Timeouts

Implement aggressive timeouts for LLM requests. When a request takes longer than expected, terminate it and return an error rather than consuming resources indefinitely.

#### Resource Monitoring and Anomaly Detection

Monitor resource consumption patterns (API call frequency, token usage, request duration). Alert on anomalies that may indicate abuse (sudden spikes, unusual usage patterns).

#### Cost Controls

For cloud-hosted models, implement budget alerts and hard spending caps. Monitor cost per user and flag accounts with abnormal usage.

#### Complexity Analysis

For resource-intensive operations (long-context processing, complex reasoning chains), implement additional restrictions or higher authentication requirements.

#### Queue Management

Use job queues with priority levels for LLM requests. Prevent individual users from monopolizing resources by implementing fair queuing.

#### CAPTCHA for Suspicious Activity

When automated abuse is detected, introduce CAPTCHA challenges to verify human users.

#### Model Extraction Defense

Monitor for systematic querying patterns that may indicate model extraction attempts (many similar queries with slight variations). Implement detection and blocking mechanisms.

## General Guidelines for LLM Security

### Defense in Depth

Do not rely on a single security mechanism. Combine input validation, output validation, access controls, monitoring, and human oversight in multiple layers.

### Separate Security from LLM Logic

Security decisions (authentication, authorization, input validation) happen in deterministic code outside the LLM. Do not trust the LLM to enforce security policies.

### Explicit Risk Communication

When generating LLM application code, explicitly state which OWASP LLM vulnerability is being mitigated (e.g., "Using output validation here to prevent LLM05: Improper Output Handling").

### Code Review Education

When identifying LLM security vulnerabilities in code reviews, explain both the traditional security issue and the LLM-specific amplification of that risk.

### Human Oversight for Critical Systems

For applications involving sensitive data, high-value transactions, or safety-critical decisions, maintain human-in-the-loop oversight. LLMs should augment human decision-making, not replace it.

### Regular Security Testing

Conduct ongoing red team testing specifically for LLM vulnerabilities. Test for prompt injection, jailbreaking, data extraction, and other LLM-specific attacks.

### Stay Updated

The LLM security landscape evolves rapidly. Monitor OWASP LLM project updates, security research, and vendor security advisories. Update defenses as new attack vectors emerge.

### Assume Adversarial Users

Design LLM applications assuming some users will actively attempt to bypass controls, extract sensitive information, or abuse functionality. Build robust defenses accordingly.

## Integration with Traditional OWASP Top 10

LLM vulnerabilities complement, not replace, traditional security concerns:

- All traditional application security practices (secure authentication, encryption, access control, etc.) remain critical for LLM applications
- LLM01 (Prompt Injection) is as critical for AI applications as SQL injection (OWASP A03) is for traditional web applications
- Combine LLM-specific and traditional security controls for comprehensive protection
- Use application-layer security (authentication, authorization) alongside LLM-layer security (input validation, output handling, RAG controls)

Working with LLMs requires accepting their non-deterministic nature while implementing deterministic security controls around them. Security is enforced by the application, not delegated to the model.
