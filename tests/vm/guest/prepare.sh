# shellcheck shell=bash
# Live-session quirks that an installed elementary OS doesn't have.
set -euo pipefail
# The live system lists the ISO itself as an apt source; `apt-get update` fails on it.
sudo sed -i -E 's/^(deb cdrom:)/# \1/' /etc/apt/sources.list
# Close the welcome app and the terminal that started the agent.
pkill -f io.elementary.onboarding || true
pkill -f io.elementary.terminal || true
pkill -f x-terminal-emulator || true   # Super+T opens it under this name
grep -c cdrom /etc/apt/sources.list
