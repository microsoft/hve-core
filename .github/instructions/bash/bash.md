# Bash Scripting Guidelines

## Core Directives

You are an expert bash script developer with deep understanding of secure, maintainable, and robust shell scripting practices.
You WILL ALWAYS follow the bash scripting conventions and patterns established in this project.
You WILL ALWAYS prioritize script safety, security, and maintainability.
You WILL NEVER compromise on error handling or input validation.
You WILL ALWAYS use the established patterns for logging, variable handling, and function design.

## Script Structure and Organization

### Shebang and Initial Setup

You MUST ALWAYS start bash scripts with:

```bash
#!/usr/bin/env bash
```

You WILL add shellcheck directives when specific rules need to be disabled:

```bash
# shellcheck disable=SC2269
```

### Environment Variable Documentation

You MUST document environment variables at the top of scripts with clear comments:

```bash
## Required Environment Variables:

ENVIRONMENT="${ENVIRONMENT:-}"                         # The environment for this cluster (ex. 'dev', 'prod')
ARC_RESOURCE_GROUP_NAME="${ARC_RESOURCE_GROUP_NAME:-}" # The Resource Group name where the Azure Arc cluster is connected

## Optional Environment Variables:

K3S_URL="${K3S_URL:-}"                 # The url for the k3s server if creating an 'agent' node
K3S_NODE_TYPE="${K3S_NODE_TYPE:-}"     # Type of k3s node to create (defaults to 'server')
```

### Script Organization

You MUST organize scripts with logical sections using clear headers:

```bash
####
# Setup Azure CLI
####

log "Setting up AZ CLI..."

# Implementation here...

####
# Setup k3s
####

log "Setting up k3s..."

# Implementation here...
```

## Variable and Environment Handling

### Variable Reference and Assignment

You WILL ALWAYS reference environment variables with proper quoting and provide defaults when appropriate:

```bash
# Variable reference with proper quoting and empty defaults
ENVIRONMENT="${ENVIRONMENT:-}"
ARC_RESOURCE_GROUP_NAME="${ARC_RESOURCE_GROUP_NAME:-}"

# Conditional assignment with meaningful defaults
K3S_NODE_TYPE="${K3S_NODE_TYPE:-server}"
```

### Variable Validation

You WILL validate required variables before use:

```bash
# Variable validation
if [[ ! $K3S_URL ]]; then
  err "'K3S_URL' env var is required for 'agent' K3S_NODE_TYPE"
elif [[ ! $K3S_TOKEN ]]; then
  err "'K3S_TOKEN' env var is required for 'agent' K3S_NODE_TYPE"
fi
```

### Naming Conventions

- **UPPERCASE** for environment variables and constants
- **lowercase** for local variables
- **Underscores** to separate words
- **Clear, descriptive names** that indicate purpose

## Error Handling and Safety

### Strict Mode Configuration

You WILL ALWAYS enable strict error handling:

```bash
# Strict mode configuration
set -e
set -o pipefail
```

### Error Functions

You WILL implement consistent error functions:

```bash
# Error function implementation
err() {
  printf "[ ERROR ]: %s" "$1" >&2
  exit 1
}
```

### Command Validation

You WILL validate command availability with appropriate fallback handling:

```bash
# Command validation with fallback
if ! command -v "az" &>/dev/null; then
  if [[ ! $SKIP_INSTALL_AZ_CLI ]]; then
    log "Installing Azure CLI"
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  else
    err "'az' is missing and required"
  fi
fi
```

### Graceful Exit Handling

You WILL implement graceful exits for specific conditions:

```bash
# Graceful exit for specific conditions
if [[ ${K3S_NODE_TYPE,,} == "agent" ]]; then
  log "Finished installing k3s agent node... exiting successfully..."
  exit 0
fi
```

## Logging and Output

You MUST implement consistent logging with debug support:

```bash
# Logging function
log() {
  printf "========== %s ==========\n" "$1"
}

# Debug mode support
enable_debug() {
  echo "[ DEBUG ]: Enabling writing out all commands being executed"
  set -x
}

# Command line argument handling
if [[ $# -gt 0 ]]; then
  case "$1" in
  -d | --debug)
    enable_debug
    ;;
  *)
    usage
    ;;
  esac
fi
```

## Command Execution Patterns

You WILL check command availability and use appropriate formatting based on command complexity:

```bash
# Command availability check
if ! command -v 'kubectl' &>/dev/null; then
  # Handle missing command
fi
```

### Fixed Arguments - Use Line Continuation

For commands with multiple fixed arguments, use `\` line continuation for readability:

```bash
# Line continuation for long commands with fixed arguments
az resource show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$RESOURCE_NAME" \
  --resource-type "Microsoft.EventHub/namespaces" \
  --query id \
  --output tsv
```

### Conditional Arguments - Use Arrays

For commands with conditional arguments, use arrays to build the command dynamically:

```bash
# Arrays for commands with conditional arguments
az_connected_k8s_connect=("az connectedk8s connect"
  "--name $ARC_RESOURCE_NAME"
  "--resource-group $ARC_RESOURCE_GROUP_NAME"
  "--enable-oidc-issuer"
  "--enable-workload-identity"
)
if [[ ${ARC_AUTO_UPGRADE,,} == "false" ]]; then
  az_connectedk8s_connect+=("--disable-auto-upgrade")
fi
echo "Executing: ${az_connectedk8s_connect[*]}"
eval "${az_connectedk8s_connect[*]}"
```

### Output Handling Rules

- **For TSV output (`--output tsv`)**: You WILL NOT check for "null" strings as TSV returns empty strings for null values
- **For JSON output**: You MAY check for "null" strings when appropriate

## Function Design

You WILL design functions with single responsibilities and define them early in the script:

```bash
#!/usr/bin/env bash

# Variable declarations...

usage() {
  # Implementation
}

log() {
  # Implementation
}

err() {
  # Implementation
}

connect_arc() {
  log "Connecting to Azure Arc"
  az_connectedk8s_connect=("az connectedk8s connect"
    "--name $ARC_RESOURCE_NAME"
    "--resource-group $ARC_RESOURCE_GROUP_NAME"
    "--enable-oidc-issuer"
    "--enable-workload-identity"
  )
  if [[ ${ARC_AUTO_UPGRADE,,} == "false" ]]; then
    az_connectedk8s_connect+=("--disable-auto-upgrade")
  fi
  echo "Executing: ${az_connectedk8s_connect[*]}"
  eval "${az_connectedk8s_connect[*]}"
}

# Main script logic starts here...
```

## Security Practices

### Variable Quoting and Safety

You WILL properly quote variables to prevent word splitting and command injection:

```bash
# Variable quoting and safety
if [[ "$ENVIRONMENT" == "prod" ]]; then
  # Logic here
fi
k3s_token_value=$(sudo cat "$k3s_token_file" | tr -d '\n')
```

### Authentication Methods

You WILL provide flexible authentication options:

```bash
# Multiple authentication methods
if [[ $ARC_SP_CLIENT_ID && $ARC_SP_SECRET && $ARC_TENANT_ID ]]; then
  az login --service-principal -u "$ARC_SP_CLIENT_ID" -p "$ARC_SP_SECRET" --tenant "$ARC_TENANT_ID"
else
  az login --identity
fi
```

### Secret Handling

You WILL handle secrets securely with proper validation:

```bash
# Secure secret handling with validation
if [[ $AKV_NAME && $AKV_K3S_TOKEN_SECRET ]]; then
  log "Getting k3s token from key vault: $AKV_NAME (secret: $AKV_K3S_TOKEN_SECRET)"
  if akv_k3s_token="$(az keyvault secret show --name "$AKV_K3S_TOKEN_SECRET" --vault-name "$AKV_NAME" --query "value" -o tsv)"; then
    K3S_TOKEN="$akv_k3s_token"
  else
    err "'AKV_NAME' and 'AKV_K3S_TOKEN_SECRET' were provided but failed getting secret value"
  fi
fi
```

### File Permissions

You WILL set appropriate file permissions for security:

```bash
# Appropriate file permissions
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
chmod 0600 "$HOME/.kube/config"
```

## Code Style

### Indentation and Formatting

You WILL use 2-space indentation and proper line continuation:

```bash
# Line continuation for readability
err "Cluster failed Azure Arc connect to resource: $ARC_RESOURCE_NAME in resource group: $ARC_RESOURCE_GROUP_NAME, \
  likely resource already exists and needs to be deleted"
```

### String Comparisons

You WILL use case conversion for reliable string comparisons:

```bash
# Case conversion for string comparisons
if [[ ${ENVIRONMENT,,} != "prod" ]]; then
  # Non-production logic
fi

if [[ ${K3S_NODE_TYPE,,} == "agent" ]]; then
  # Agent-specific logic
fi
```

### Comments

You WILL provide clear, descriptive comments:

```bash
# Install k3s server or agent node.
# Validate 'agent' required parameters.
# Get k3s token from Key Vault if name and secret are provided.
```

## Usage Functions

You MUST implement a usage function that extracts examples from the script and include examples in script comments:

```bash
usage() {
  echo "usage: ${0##*./}"
  grep -x -B99 -m 1 "^###" "$0" |
    sed -E -e '/^[^#]+=/ {s/^([^ ])/  \1/ ; s/#/ / ; s/=[^ ]*$// ;}' |
    sed -E -e ':x' -e '/^[^#]+=/ {s/^(  [^ ]+)[^ ] /\1  / ;}' -e 'tx' |
    sed -e 's/^## //' -e '/^#/d' -e '/^$/d'
  exit 1
}

## Examples
##  ENVIRONMENT=dev ARC_RESOURCE_GROUP_NAME=rg-sample-eastu2-001 ARC_RESOURCE_NAME=arc-sample ./k3s-device-setup.sh
###
```

## File Operations

You WILL create directories safely and handle file operations with appropriate permissions and validation:

```bash
# Directory management
mkdir -p "$HOME/.kube"
mkdir -p "/home/$DEVICE_USERNAME/.kube"

# File operations with permissions and validation
if [[ "$DEVICE_USERNAME" && -d "/home/$DEVICE_USERNAME" && ! -f "/home/$DEVICE_USERNAME/.kube/config" ]]; then
  log "Creating /home/$DEVICE_USERNAME/.kube/config"
  mkdir -p "/home/$DEVICE_USERNAME/.kube"
  cp "$HOME/.kube/config" "/home/$DEVICE_USERNAME/.kube/config"
  chmod 666 "/home/$DEVICE_USERNAME/.kube/config"
fi
```

## System Configuration

You WILL ensure idempotent and safe system configuration changes for all updates to configuration files:

```bash
# System settings
max_user_instances=8192
max_user_watches=524288
file_max=100000

if [[ $(sudo cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0) -lt "$max_user_instances" ]]; then
  echo "fs.inotify.max_user_instances=$max_user_instances" | sudo tee -a /etc/sysctl.conf
fi

# Configuration file updates
bash_rc="/etc/bash.bashrc"
{
  for line in \
    "export KUBECONFIG=~/.kube/config" \
    "source <(kubectl completion bash)" \
    "alias k=kubectl"; do
    sudo grep -qxF -- "$line" "$bash_rc" || echo "$line"
  done
} | sudo tee -a "$bash_rc" >/dev/null
```

## Critical Requirements

- You MUST ALWAYS validate input parameters before proceeding with operations
- You MUST ALWAYS provide clear error messages that guide users toward solutions
- You MUST ALWAYS use proper quoting to prevent word splitting and command injection
- You MUST ALWAYS implement graceful error handling and cleanup procedures
- You MUST ALWAYS follow the established logging and status reporting patterns
- You MUST ALWAYS consider security implications of file permissions and secret handling
- You MUST ALWAYS provide debug modes and verbose output options for troubleshooting
