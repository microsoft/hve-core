---
applyTo: '**/*.sh'
description: 'Instructions for bash script implementation - Brought to you by microsoft/edge-ai'
---

# Bash Script Instructions

These instructions define conventions for authoring Bash scripts in this repository. Scripts follow Bash 5.x conventions with strict error handling and ShellCheck compliance.

## Script Structure

Scripts follow a consistent structure with shebang, header comment, strict mode, and a main function pattern.

<!-- <template-script-structure> -->
```bash
#!/usr/bin/env bash
#
# script-name.sh
# Brief description of what this script does

set -euo pipefail

main() {
  # Script logic here
  echo "Executing..."
}

main "$@"
```
<!-- </template-script-structure> -->

### Shebang

Use `#!/usr/bin/env bash` for portability across systems.

### Strict Mode

Enable strict error handling at the top of every script:

```bash
set -euo pipefail
```

This configuration:

* `-e`: Exits immediately on command failure
* `-u`: Treats unset variables as errors
* `-o pipefail`: Propagates pipeline failures

### Main Function Pattern

Encapsulate script logic in a `main()` function called at the end. This pattern:

* Ensures all functions are defined before use
* Supports sourcing scripts for testing
* Provides clear entry point

## Formatting and Style

### Indentation and Line Length

* Use 2 spaces for indentation, never tabs
* Limit lines to 80 characters when practical
* Long commands use backslash continuation

```bash
az resource show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$RESOURCE_NAME" \
  --query id \
  --output tsv
```

### Control Structures

Place `then` and `do` on the same line as their control keyword:

```bash
if [[ -n "${VAR:-}" ]]; then
  echo "Variable is set"
fi

for item in "${items[@]}"; do
  process "$item"
done
```

### Conditionals and Tests

* Use `[[ ... ]]` instead of `[ ... ]` or `test`
* Use `(( ... ))` for arithmetic operations

```bash
if [[ "${ENVIRONMENT}" == "prod" ]]; then
  echo "Production environment"
fi

if (( count > 10 )); then
  echo "Count exceeds threshold"
fi
```

## Variables and Naming

### Naming Conventions

| Type                  | Convention                       | Example                  |
|-----------------------|----------------------------------|--------------------------|
| Environment variables | UPPER_SNAKE_CASE                 | `RESOURCE_GROUP_NAME`    |
| Constants             | UPPER_SNAKE_CASE with `readonly` | `readonly MAX_RETRIES=3` |
| Local variables       | lower_snake_case                 | `local file_path`        |
| Function names        | lower_snake_case                 | `validate_input()`       |

### Variable Expansion

* Use braces for clarity: `"${var}"` over `"$var"`
* Quote all variable expansions unless word splitting is intentional
* Use command substitution with `$()`: never backticks

```bash
# Variable with default
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Required variable check
if [[ -z "${REQUIRED_VAR:-}" ]]; then
  echo "ERROR: REQUIRED_VAR must be set" >&2
  exit 1
fi
```

### Arrays

Use arrays for lists of elements:

```bash
declare -a files=("file1.txt" "file2.txt" "file3.txt")

for file in "${files[@]}"; do
  process "$file"
done
```

## Functions

Define functions before use. Use `local` for function-scoped variables.

```bash
log() {
  local message="$1"
  printf "========== %s ==========\n" "$message"
}

err() {
  local message="$1"
  printf "ERROR: %s\n" "$message" >&2
  exit 1
}

validate_input() {
  local input="$1"
  if [[ -z "${input}" ]]; then
    err "Input cannot be empty"
  fi
}
```

## Error Handling

### Error Functions

Implement consistent error reporting:

```bash
err() {
  printf "ERROR: %s\n" "$1" >&2
  exit 1
}
```

### Command Validation

Check for required commands before use:

```bash
if ! command -v "az" &>/dev/null; then
  err "'az' command is required but not installed"
fi
```

### Error Visibility

Allow commands to fail naturally with their native error messages. Avoid redirecting stderr to `/dev/null` unless errors are genuinely irrelevant. Let tools display their built-in error information.

## Comments

Keep comments minimal. Add them only when logic requires explanation:

* Complex regex patterns
* Non-obvious conditionals
* Workarounds with context

```bash
# Match semantic version pattern: major.minor.patch
if [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Valid version"
fi
```

Document environment variables at the top of scripts that require them:

```bash
## Required Environment Variables:
# ENVIRONMENT       - Target environment (dev, prod)
# RESOURCE_GROUP    - Azure resource group name

## Optional Environment Variables:
# DEBUG             - Enable verbose output when set
```

## Usage Functions

Scripts with arguments include a usage function:

```bash
usage() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help, -h    Show this help message"
  echo "  --verbose     Enable verbose output"
  exit 1
}
```

## Argument Parsing

Use `case` statements for argument handling:

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --output)
      if [[ -z "${2:-}" || "$2" == --* ]]; then
        echo "Error: --output requires an argument" >&2
        usage
      fi
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done
```

## File Operations

Create directories safely and handle paths properly:

```bash
mkdir -p "$(dirname "$OUTPUT_FILE")"

if [[ -f "${config_file}" ]]; then
  source "${config_file}"
fi
```

## Security Practices

### Variable Quoting

Quote variables to prevent word splitting and command injection:

```bash
# Correct
rm -f "${temp_file}"
grep "${pattern}" "${file}"

# Avoid
rm -f $temp_file
grep $pattern $file
```

### File Permissions

Set appropriate permissions for sensitive files:

```bash
chmod 0600 "${HOME}/.kube/config"
```

### Checksum Verification

Verify downloaded files before execution:

```bash
EXPECTED_SHA256="abc123..."
if ! echo "${EXPECTED_SHA256} ${downloaded_file}" | sha256sum -c --quiet -; then
  echo "ERROR: Checksum verification failed" >&2
  rm "${downloaded_file}"
  exit 1
fi
```

## ShellCheck Compliance

All scripts pass ShellCheck validation. Use the VS Code problems panel or run ShellCheck directly:

```bash
shellcheck script.sh
```

When a specific rule needs suppression, add a directive with justification:

```bash
# shellcheck disable=SC2034  # Variable used by sourced script
EXPORTED_CONFIG="value"
```

## Azure CLI Patterns

When working with Azure CLI commands:

### Output Handling

* Use `--output tsv` for single values in scripts
* TSV output returns empty strings for null values (not the string "null")
* Use `--query` with JMESPath for filtering results

```bash
resource_id=$(az resource show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$RESOURCE_NAME" \
  --resource-type "Microsoft.Storage/storageAccounts" \
  --query id \
  --output tsv)

if [[ -z "${resource_id}" ]]; then
  err "Resource not found"
fi
```

### Conditional Command Arguments

Build commands with arrays when arguments are conditional:

```bash
az_cmd=("az" "connectedk8s" "connect"
  "--name" "$RESOURCE_NAME"
  "--resource-group" "$RESOURCE_GROUP"
)

if [[ "${AUTO_UPGRADE:-true}" == "false" ]]; then
  az_cmd+=("--disable-auto-upgrade")
fi

"${az_cmd[@]}"
```
