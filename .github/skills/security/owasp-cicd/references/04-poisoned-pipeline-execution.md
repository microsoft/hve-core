---
title: 'CICD-SEC-4: Poisoned Pipeline Execution'
description: OWASP CI/CD Top 10 reference for poisoned pipeline execution vulnerabilities including malicious code injection into CI/CD pipelines
---

# 04 Poisoned Pipeline Execution

Identifier: CICD-SEC-4:2025
Category: Pipeline Security

## Description

Poisoned Pipeline Execution (PPE) risks refer to the ability of an attacker with access to source
control systems, and without access to the build environment, to manipulate the build process by
injecting malicious code or commands into the build pipeline configuration, essentially poisoning the
pipeline and running malicious code as part of the build process.

The PPE vector abuses permissions against an SCM repository in a way that causes a CI pipeline to
execute malicious commands. Users that have permissions to manipulate CI configuration files, or
other files which the CI pipeline job relies on, can modify them to contain malicious commands.
Pipelines executing unreviewed code, such as those triggered directly from pull requests or commits
to arbitrary repository branches, are more susceptible to PPE.

There are three types of PPE:

Direct PPE (D-PPE) occurs when the attacker modifies the CI configuration file in a repository they
have access to, either by pushing directly to an unprotected branch or by submitting a pull request.
The pipeline execution is defined by the commands in the modified configuration file.

Indirect PPE (I-PPE) occurs when the pipeline configuration file is protected but the attacker
injects malicious code into files referenced by the configuration, such as Makefiles, test
frameworks, linter configurations, or scripts called from the pipeline.

Public PPE (3PE) targets public repositories that allow contributions from anonymous users. If the
CI pipeline of a public repository runs unreviewed code suggested by anonymous users, it is
susceptible to this attack, potentially exposing internal assets including secrets from private
projects sharing the same CI instance.

## Risk

* Access to any secret available to the CI job, including secrets injected as environment variables
  and credentials for cloud providers, artifact registries, and the SCM itself.
* Access to external assets the job node has permissions to, such as files on the node's filesystem
  or credentials to cloud environments accessible through the underlying host.
* Ability to ship malicious code and artifacts further down the pipeline in the guise of legitimate
  build output.
* Ability to access additional hosts and assets in the network or environment of the job node.
* Lateral movement from the CI environment to production systems using stolen credentials.

## Vulnerability checklist

* Pipelines execute code from unreviewed pull requests or commits to arbitrary branches.
* CI configuration files can be modified by contributors without review.
* Pipeline configuration files are stored in the same repository as source code without protection.
* Files referenced by the pipeline configuration (Makefiles, scripts, test files, linter configs)
  can be modified without triggering a separate review process.
* Public repositories run CI pipelines on code submitted by anonymous contributors.
* Pipeline execution nodes have access to secrets beyond what is needed for the specific job.
* No isolation exists between pipeline nodes handling public and private repositories.
* Branch protection rules do not have correlating CI trigger restrictions.

## Prevention controls

1. Ensure pipelines running unreviewed code execute on isolated nodes not exposed to secrets and
   sensitive environments.
2. Evaluate the need for triggering pipelines on public repositories from external contributors.
   Where possible, refrain from running pipelines originating from forks and consider requiring
   manual approval for pipeline execution.
3. For sensitive pipelines exposed to secrets, ensure each branch configured to trigger a pipeline
   has a correlating branch protection rule in the SCM.
4. Require review of CI configuration file changes before the pipeline runs, or manage the CI
   configuration file in a separate protected branch.
5. Remove unnecessary SCM repository permissions from users.
6. Scope each pipeline to only the credentials it needs with minimum required privileges.
7. Review and restrict which files referenced by the pipeline configuration can be modified
   without additional approval.

## Example attack scenarios

### Scenario A — Direct PPE credential theft

A GitHub Actions workflow is configured to trigger on push events. An attacker creates a new remote
branch and modifies the workflow file to exfiltrate AWS credentials stored as repository secrets.
The modified workflow loads the secrets into environment variables and sends them to an
attacker-controlled server. The push triggers the pipeline, which executes the poisoned
configuration and leaks the credentials.

### Scenario B — Indirect PPE via Makefile

A Jenkins pipeline fetches its Jenkinsfile from a protected main branch, but the build stage runs
a Makefile stored in the repository. An attacker creates a pull request modifying the Makefile to
replace the build target with a command that exfiltrates all environment variables. Since the
pipeline triggers on pull requests, the malicious Makefile content executes during the build stage
where AWS credentials are loaded, sending them to the attacker.

### Scenario C — Public PPE on open source project

An open source project runs CI on all pull requests. An attacker submits a pull request modifying
the test suite to include malicious code. The CI pipeline executes the tests, running the
attacker's code on the build node. Because the same CI instance services private repositories, the
attacker accesses secrets belonging to private projects.

## Detection guidance

* Monitor for modifications to CI configuration files in pull requests and pushes.
* Alert on pipeline executions triggered by unreviewed code from forks or external contributors.
* Audit which files referenced by pipeline configurations have been modified in recent commits.
* Monitor outbound network connections from build nodes for unexpected destinations.
* Review pipeline logs for unusual secret access patterns or commands.
* Compare pipeline configuration files against their protected branch versions before execution.

## Remediation

* Isolate pipeline execution nodes that process unreviewed code from those handling sensitive
  workloads.
* Move CI configuration files to protected branches and require review for all changes.
* Implement manual approval gates for pipelines triggered by external contributors.
* Restrict pipeline credentials using fine-grained scoping aligned with each job's requirements.
* Separate CI infrastructure for public and private repositories.
* Audit and lock down all files referenced by pipeline configurations (Makefiles, scripts, test
  configurations, linter configurations).
* Enable and enforce branch protection rules with correlating pipeline trigger restrictions.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
