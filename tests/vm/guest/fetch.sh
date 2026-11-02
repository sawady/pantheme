# shellcheck shell=bash
# Downloads the repository under test from the job server into ~/pantheme.
set -euo pipefail
rm -rf ~/pantheme
wget -qO- "$PANTHEME_AGENT/repo.tar.gz" | tar -xz -C ~
ls ~/pantheme
