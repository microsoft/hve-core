<!-- markdownlint-disable-file -->
# 🔍 Checkov Action Integration Research

**Research Date**: November 4, 2025  
**Researcher**: GitHub Copilot Task Researcher  
**Purpose**: Determine the latest stable version of bridgecrewio/checkov-action, obtain commit SHA for SHA pinning, and recommend the optimal installation method for GitHub Actions workflows.

---

## 📊 Executive Summary

**✅ RECOMMENDATION: Use npm-based installation (current repository pattern) instead of the bridgecrewio/checkov-action GitHub Action.**

### Key Findings
* 🚨 **Latest stable release is OUTDATED**: v12.1347.0 (March 9, 2022 - nearly 3 years old)
* 🐳 **Docker image version in action is ancient**: bridgecrew/checkov:2.0.930 (from 2022)
* ✅ **Repository already has superior npm-based setup** with modern checkov version
* 🔄 **No active maintenance signals**: Last release in 2022, 1760+ commits since last release
* ⚠️ **GitHub Action is self-contained (Docker)** but uses severely outdated tooling

---

## 🎯 Research Scope and Success Criteria

### Scope
* ✅ Identify latest stable release/version of bridgecrewio/checkov-action
* ✅ Obtain full 40-character commit SHA for that release
* ✅ Document recommended usage pattern from official repository
* ✅ Determine if action requires external pip/npm installation or is self-contained
* ✅ Compare with repository's existing npm-based checkov integration

### Success Criteria Met
* ✅ Version tag identified: v12.1347.0
* ✅ Full commit SHA obtained: 99bb2caf247dfd9f03cf984373bc6043d4e32ebf
* ✅ Official usage pattern documented from README
* ✅ Installation method analyzed: Docker-based, self-contained
* ✅ Conflict analysis completed: npm-based approach is superior
* ✅ Source links and access dates provided

---

## 📝 Detailed Research Findings

### 1. Latest Stable Release Information

**Version Tag**: `v12.1347.0`  
**Release Date**: March 9, 2022  
**Commit SHA (40 chars)**: `99bb2caf247dfd9f03cf984373bc6043d4e32ebf`  
**Release Author**: [@nimrodkor](https://github.com/nimrodkor)  
**Release Notes**: "Bump checkov container version"

**Age Analysis**:
* ⏰ Released: ~2 years and 8 months ago (as of November 4, 2025)
* 🔢 Commits since release: 1760+ commits to master branch
* 🚨 **CRITICAL**: This is NOT an actively maintained release version

**Source**: [GitHub Release Page](https://github.com/bridgecrewio/checkov-action/releases/tag/v12.1347.0) - Accessed November 4, 2025

---

### 2. Action Implementation Analysis

#### Self-Contained Docker-Based Action

**From `action.yml` at v12.1347.0:**
```yaml
runs:
  using: 'docker'
  image: 'docker://bridgecrew/checkov:2.0.930'
  args:
    - ${{ inputs.directory }}
    - ${{ inputs.check }}
    - ${{ inputs.skip_check }}
    # ... additional arguments
  env:
    API_KEY_VARIABLE: ${{ inputs.api-key }}
```

**Key Characteristics**:
* ✅ **Self-contained**: Uses Docker image, no external pip/npm installation required
* 🐳 **Docker image**: `bridgecrew/checkov:2.0.930` (hard-coded in action definition)
* 📦 **Checkov version**: 2.0.930 (from March 2022)
* ⚠️ **Severely outdated**: Modern checkov is at version 3.x+ with significant security improvements
* 🔒 **Immutable**: Action version is fixed, but Docker image could theoretically be updated upstream

**Benefits of Docker-Based Action**:
* No need to set up Python environment
* No need to install checkov via pip
* Consistent execution environment

**Drawbacks of Docker-Based Action**:
* 🚨 Severely outdated checkov version (2.0.930 from 2022)
* 📏 Slower startup time (Docker image pull)
* 🔐 Less control over checkov version
* 🐛 Missing 2+ years of security fixes and new checks

**Source**: [action.yml at v12.1347.0](https://raw.githubusercontent.com/bridgecrewio/checkov-action/v12.1347.0/action.yml) - Accessed November 4, 2025

---

### 3. Official Usage Pattern from README

**Recommended Usage from Official Repository:**

```yaml
name: checkov

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  workflow_dispatch:

jobs:
  scan:
    permissions:
      contents: read
      security-events: write
      actions: read
      
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Checkov GitHub Action
        uses: bridgecrewio/checkov-action@v12
        with:
          output_format: cli,sarif
          output_file_path: console,results.sarif
        
      - name: Upload SARIF file
        uses: github/codeql-action/upload-sarif@v2
        if: success() || failure()
        with:
          sarif_file: results.sarif
```

**Key Configuration Options:**
* `directory`: Directory to scan (default: `.`)
* `check`: Run only specific check IDs (comma separated)
* `skip_check`: Skip specific check IDs (comma separated)
* `quiet`: Display only failed checks
* `soft_fail`: Do not return error code on failed checks
* `framework`: Run only on specific infrastructure (terraform, cloudformation, kubernetes, all)
* `output_format`: Output format (cli, json, junitxml, github_failed_only, sarif)
* `output_file_path`: Folder and name of results file

**Source**: [bridgecrewio/checkov-action README](https://github.com/bridgecrewio/checkov-action/blob/main/README.md) - Accessed November 4, 2025

---

### 4. Repository Current State Analysis

#### Existing npm-Based Checkov Integration

**From `package.json`:**
```json
{
  "devDependencies": {
    "cspell": "^8.14.4",
    "markdownlint-cli": "^0.42.0",
    "markdown-table-formatter": "^1.6.0"
  },
  "scripts": {
    "security:checkov": "checkov -d . --framework github_actions json yaml secrets --output junitxml --output json --output-file-path console,checkov-results.json --evaluate-variables",
    "security:checkov:report": "checkov -d . --framework github_actions json yaml secrets --output junitxml --output json --output-file-path checkov-junit.xml,checkov-results.json --evaluate-variables"
  }
}
```

**Note**: Checkov is NOT listed in `devDependencies`. It appears to be installed globally or via Python pip.

**From existing workflow `checkov-scan.yml`:**
```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.11'

- name: Install Checkov
  run: |
    pip install checkov

- name: Run Checkov scan
  run: |
    checkov -d . \
      --framework github_actions json yaml secrets \
      --output junitxml \
      --output json \
      --output-file-path checkov-junit.xml,checkov-results.json \
      --evaluate-variables
  continue-on-error: true
```

**Benefits of Current npm/pip-Based Approach**:
* ✅ **Up-to-date**: Installs latest stable checkov version from PyPI
* ✅ **Flexible**: Full control over checkov version
* ✅ **Fast**: No Docker image pull required
* ✅ **Modern**: Uses Python 3.11 (as of current workflow)
* ✅ **Security**: Gets latest security fixes and vulnerability checks
* ✅ **Already implemented**: Repository already has working setup

**Source**: 
* [package.json](c:\Users\wberry\src\hve-core\package.json) - Accessed November 4, 2025
* [.github/workflows/checkov-scan.yml](c:\Users\wberry\src\hve-core\.github\workflows\checkov-scan.yml) - Accessed November 4, 2025

---

### 5. Comparison Analysis: GitHub Action vs npm/pip Installation

| **Criteria** | **bridgecrewio/checkov-action@v12** | **npm/pip Installation (Current)** |
|--------------|--------------------------------------|-------------------------------------|
| **Checkov Version** | 2.0.930 (March 2022) 🚨 | Latest stable (Nov 2025) ✅ |
| **Maintenance** | Last release: March 2022 🚨 | Active (pip install checkov) ✅ |
| **Security Updates** | Outdated by 2+ years 🚨 | Current security fixes ✅ |
| **Setup Complexity** | Simple (one action) ✅ | Medium (Python + pip) ⚠️ |
| **Startup Time** | Slower (Docker pull) ⚠️ | Faster (pip install) ✅ |
| **Flexibility** | Limited to action version ⚠️ | Full control over version ✅ |
| **SARIF Support** | Yes ✅ | Yes ✅ |
| **Already Implemented** | No ❌ | Yes ✅ |
| **Recommended** | **NO** 🚨 | **YES** ✅ |

---

### 6. Conflict Analysis with npm-based checkov

#### Does GitHub Action Conflict with npm Installation?

**Answer**: No direct conflict, but **redundant and inadvisable**.

**Technical Analysis**:
* The bridgecrewio/checkov-action runs checkov inside a Docker container
* The npm script runs checkov via Python pip installation
* They operate in separate execution contexts
* **However**: Using the GitHub Action would result in:
  * ❌ Running severely outdated checkov (2.0.930 vs latest)
  * ❌ Missing 2+ years of security checks and improvements
  * ❌ Inconsistent results between workflows
  * ❌ Confusion about which approach is canonical

**Recommendation**: 
* ✅ **KEEP npm/pip-based approach** (current implementation)
* ❌ **DO NOT adopt bridgecrewio/checkov-action** due to outdated version
* ✅ **Continue using pip install checkov** for latest features
* ✅ **Repository already has superior implementation** in place

---

## 🎯 Final Recommendation

### ✅ Recommended Approach: Continue Using npm/pip-Based Installation

**Rationale**:
1. 📅 **Recency**: Latest checkov from PyPI vs 2022 Docker image
2. 🔒 **Security**: Current vulnerability checks vs outdated checks
3. ⚡ **Performance**: Faster pip install vs Docker image pull
4. 🎯 **Flexibility**: Version control vs hard-coded Docker image
5. ✅ **Already Working**: Repository has proven implementation
6. 🚨 **Action Unmaintained**: Last release March 2022, no activity since

### ❌ Do NOT Use bridgecrewio/checkov-action

**Reasons**:
* 🚨 Checkov version 2.0.930 is **severely outdated** (2022)
* 📆 Action not maintained since March 9, 2022
* 🐛 Missing 1760+ commits worth of fixes and improvements
* ⚠️ Security vulnerabilities likely present in old version
* 💼 Repository already has better solution

### 📋 Action Items

1. ✅ **Keep existing pip-based checkov installation** in workflows
2. ✅ **Use existing workflow patterns** from `checkov-scan.yml`
3. ✅ **Pin actions to SHA** (actions/setup-python, actions/checkout, etc.)
4. ❌ **Do NOT integrate bridgecrewio/checkov-action**
5. 📝 **Document decision** in workflow comments if needed

---

## 📚 Complete Source References

### GitHub Repository
* **Repository**: [bridgecrewio/checkov-action](https://github.com/bridgecrewio/checkov-action)
* **Latest Release**: [v12.1347.0](https://github.com/bridgecrewio/checkov-action/releases/tag/v12.1347.0)
* **Commit SHA**: `99bb2caf247dfd9f03cf984373bc6043d4e32ebf`
* **Release Date**: March 9, 2022
* **Access Date**: November 4, 2025

### Documentation
* **README**: [bridgecrewio/checkov-action/README.md](https://github.com/bridgecrewio/checkov-action/blob/main/README.md)
* **Action Definition**: [action.yml at v12.1347.0](https://raw.githubusercontent.com/bridgecrewio/checkov-action/v12.1347.0/action.yml)
* **Docker Image**: `bridgecrew/checkov:2.0.930`
* **License**: Apache-2.0

### Repository Files Analyzed
* `package.json` - Local repository
* `.github/workflows/checkov-scan.yml` - Local repository
* `.github/workflows/reusable-validation.yml` - Local repository

---

## 📊 Summary Answer to User Request

### Full Commit SHA
```
99bb2caf247dfd9f03cf984373bc6043d4e32ebf
```

### Version Tag
```
v12.1347.0
```

### Whether to Use Action or pip/npm Installation
**🚨 USE PIP/NPM INSTALLATION (current repository pattern)**

### Rationale
1. **Action is severely outdated**: Last release March 9, 2022 (2+ years ago)
2. **Outdated checkov version**: 2.0.930 from 2022 vs latest from 2025
3. **Repository already has superior implementation**: pip-based installation in existing workflows
4. **Security concerns**: Missing 2+ years of vulnerability checks and security fixes
5. **Maintenance red flag**: 1760+ commits since last release, no new versions
6. **Flexibility**: pip installation allows version control and updates
7. **Performance**: Faster pip install vs Docker image pull

### Implementation Guidance

**✅ KEEP (Existing Pattern)**:
```yaml
- name: Set up Python
  uses: actions/setup-python@{SHA} # v5
  with:
    python-version: '3.11'

- name: Install Checkov
  run: pip install checkov

- name: Run Checkov scan
  run: npm run security:checkov:report
  continue-on-error: true
```

**❌ DO NOT USE**:
```yaml
- name: Run Checkov
  uses: bridgecrewio/checkov-action@99bb2caf247dfd9f03cf984373bc6043d4e32ebf # v12.1347.0 - OUTDATED
```

---

## 🏁 Research Complete

**Status**: ✅ All research objectives met  
**Recommendation**: ✅ Clear and actionable  
**Next Steps**: Continue using repository's existing pip-based checkov integration  
**Documentation**: Complete with sources and rationale
