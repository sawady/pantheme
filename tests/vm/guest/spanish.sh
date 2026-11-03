# shellcheck shell=bash
# Messages follow the locale: Spanish with LANG=es_*, English otherwise, for
# the theme command and the installer (including a real desktop step).
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
fails=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }
has() {  # text command...
  local want="$1" out
  shift
  out="$("$@" 2>&1)"
  echo "\$ $*"
  printf '    %s\n' "${out//$'\n'/$'\n    '}"
  if grep -qF -- "$want" <<<"$out"; then ok "'$want'"; else bad "'$want' not in the output"; fi
}
es=es_AR.UTF-8
has "Tema actual:" env LANG=$es pantheme
has "Uso:" env LANG=$es tema ayuda
has "Pasos por defecto:" env LANG=$es ~/pantheme/install.sh ayuda
has "Atajos aplicados." env LANG=$es ~/pantheme/install.sh atajos
has "Ajustes de escritorio aplicados." env LANG=$es ~/pantheme/install.sh escritorio
has "Current theme:" env LANG=en_US.UTF-8 pantheme
has "Shortcuts applied." env LANG=en_US.UTF-8 ~/pantheme/install.sh shortcuts
echo
echo "$fails failure(s)"
[ "$fails" -eq 0 ]
