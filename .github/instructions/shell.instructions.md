---
applyTo: '**/*.sh'
description: 'Instructions for shell script implementation using Bash conventions - Brought to you by microsoft/edge-ai'
---
# Shell Code Instructions

You are an expert in building Bash or Shell code
You will always use the correct and latest conventions for Bash, version 5.2.15(1)-release
You will keep comments to a minimum, only add comments when the logic may be confusing (regex, complex if statements, confusing variables, etc.)
You will always strive to keep bash and shell code simple and well crafted
You will only add functions when needed to simplify logic

## Error Handling and Output Guidelines

When it's obvious errors should be visible or users explicitly request that errors be visible:

* NEVER redirect stderr to `/dev/null` or suppress error output
* Allow commands to fail naturally and show their native error messages
* Use `|| echo ""` pattern only when you need to capture output but allow graceful failure
* Prefer natural bash error propagation over complex error capture and re-display
* Let tools like `az login` fail naturally with their built-in error messages

## Azure CLI and JMESPath Guidelines

When working with Azure CLI:

* Research Azure CLI command output structure using #fetch:<https://docs.microsoft.com/cli/azure/query-azure-cli>
* Understand JMESPath syntax thoroughly using #fetch:<https://jmespath.org/tutorial.html>
* Test JMESPath queries with actual Azure CLI output structure
* Use #githubRepo:"Azure/azure-cli" to research specific Azure CLI behaviors

## ShellCheck and Formatting Compliance

You will always follow all shellcheck and shfmt formatting rules:

* ALWAYS use the get_errors #problems tool to check for linting issues in shell files you are working on
* Use `shellcheck` command line tool only when get_errors #problems tool is not available
* Always follow Shell Style Guide formatting rules from #fetch:<https://google.github.io/styleguide/shellguide.html>
* `shellcheck` is located at #githubRepo:"koalaman/shellcheck" search there for more information
* For all shellcheck rules #fetch:<https://gist.githubusercontent.com/nicerobot/53cee11ee0abbdc997661e65b348f375/raw/d5a97b3b18ead38f323593532050f0711084acf1/_shellcheck.md>
* Always check the get_errors #problems tool for any issues with the specific shell or bash file being modified before AND after making changes

### Formatting Rules (shfmt/Shell Style Guide)

Follow these formatting conventions along with all others outlined in #fetch:<https://google.github.io/styleguide/shellguide.html>:

* Use 2 spaces for indentation, never tabs
* Maximum line length is 80 characters
* Put `; then` and `; do` on the same line as `if`, `for`, `while`
* Use `[[ ... ]]` instead of `[ ... ]` or `test`
* Prefer `"${var}"` over `"$var"` for variable expansion
* Use `$(command)` instead of backticks for command substitution
* Use `(( ... ))` for arithmetic operations instead of `let` or `expr`
* Quote all variable expansions unless you specifically need word splitting
* Use arrays for lists of elements: `declare -a array=(item1 item2)`
* Use `local` for function-specific variables
* Function names: lowercase with underscores `my_function()`
* Constants: uppercase with underscores `readonly MY_CONSTANT="value"`

## Research and Validation Requirements

Before making changes to shell scripts:

* Use #fetch to research Azure CLI documentation when working with `az` commands
* Use #githubRepo to research Azure CLI source code for complex scenarios
* Always validate your understanding of command output formats
* Test complex logic patterns and JMESPath queries before implementation
* Understand the user's specific requirements about error handling and output visibility
