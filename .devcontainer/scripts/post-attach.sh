#!/bin/bash
set -euo pipefail

# devcontainers copy your local gitconfig but do not parse conditional includes.
# This re-configures the devcontainer git identities based on the prior exported
# global and local git configurations *after* parsing host includes. See also:
# https://github.com/microsoft/vscode-remote-release/issues/2084#issuecomment-2289987894
function copy_user_gitconfig() {
  for conf in .gitconfig.global .gitconfig.local; do
    if [ -f $conf ]; then
      echo "*** Parsing ${conf##.gitconfig.} Git configuration export"
      while IFS='=' read -r key value; do
        case "$key" in
        user.name | user.email | user.signingkey | commit.gpgsign)
          echo "Set Git config ${key}=${value}"
          git config --global "$key" "$value"
          ;;
        esac
      done < "$conf"
      rm -f "$conf"
    fi
  done
}

#
# Main execution path
#

copy_user_gitconfig
