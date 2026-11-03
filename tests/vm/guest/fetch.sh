# shellcheck shell=bash
# Downloads a repository tarball from the job server into ~.
#   fetch.sh [tarball] [directory]   default: repo.tar.gz (the repository under
#                                    test) into ~/pantheme
set -euo pipefail
tarball="${1:-repo.tar.gz}" dir="${2:-pantheme}"
rm -rf ~/"$dir"
wget -qO- "$PANTHEME_AGENT/$tarball" | tar -xz -C ~
ls ~/"$dir"
