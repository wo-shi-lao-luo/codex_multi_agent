#!/bin/sh
# POSIX entrypoint; PowerShell remains the kit's shared implementation runtime.
set -eu
pwsh_path=
if [ "${1-}" = "--help" ] || [ "${1-}" = "-h" ]; then
  printf '%s\n' '
Usage: sh scripts/setup.sh [--pwsh PATH] [PowerShell options]
Defaults to -Action Doctor. Actions: Doctor, Install, Verify.
Options: -CodexPath PATH -CodexHome PATH -AgentsHome PATH -Json
         -WhatIf -Force -TimeoutSeconds 120
Examples:
  sh scripts/setup.sh
  sh scripts/setup.sh --pwsh /path/to/pwsh -Action Install -WhatIf
  sh scripts/setup.sh -Action Install
This command does not download dependencies, sign in, or run a model.
'
  exit 0
fi
if [ "${1-}" = "--pwsh" ]; then
  if [ "$#" -lt 2 ] || [ -z "$2" ]; then
    echo 'setup: --pwsh requires an executable path.' >&2
    exit 2
  fi
  pwsh_path=$2
  shift 2
else
  pwsh_path=$(command -v pwsh || :)
fi
uname_path=
for candidate in /usr/bin/uname /bin/uname; do
  if [ -x "$candidate" ]; then uname_path=$candidate; break; fi
done
if [ -n "$uname_path" ]; then
  setup_os=$("$uname_path" -s)
  setup_arch=$("$uname_path" -m)
else
  setup_os=unknown
  setup_arch=unknown
fi
case "$setup_os/$setup_arch" in
  Darwin/arm64|Darwin/x86_64|Linux/aarch64|Linux/arm64|Linux/x86_64) ;;
  *) printf '%s\n' "setup: unsupported platform $setup_os/$setup_arch; use native macOS or Linux on ARM64 or x64." >&2; exit 2 ;;
esac
if [ -z "$pwsh_path" ] || [ ! -x "$pwsh_path" ] || [ -d "$pwsh_path" ]; then
  printf '%s\n' "Detected platform: $setup_os/$setup_arch" >&2
  printf '%s\n' '
setup: PowerShell 7 or later was not found. Install a native build for your OS and architecture using an explicitly approved network route, then rerun with --pwsh PATH if needed.
macOS: https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos
Ubuntu: https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu
For other Linux distributions, use the matching official Microsoft instructions.
Codex: https://learn.chatgpt.com/docs/codex/cli
No dependency was downloaded or installed.
' >&2
  exit 2
fi
case $0 in
  */*) setup_dir=${0%/*} ;;
  *) setup_dir=. ;;
esac
setup_dir=$(CDPATH= cd -P "$setup_dir" && pwd)
POWERSHELL_TELEMETRY_OPTOUT=1
POWERSHELL_UPDATECHECK=Off
export POWERSHELL_TELEMETRY_OPTOUT POWERSHELL_UPDATECHECK
exec "$pwsh_path" -NoLogo -NoProfile -NonInteractive -File "$setup_dir/setup-user.ps1" "$@"
