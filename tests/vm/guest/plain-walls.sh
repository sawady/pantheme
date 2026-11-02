# shellcheck shell=bash
# For the README screenshots: swaps the downloaded wallpapers (Omarchy's, which
# have no per-image license) for plain gradients, so they don't end up in the
# repository. `plain-walls.sh restore` puts the downloaded ones back.
set -euo pipefail
walls="$HOME/Pictures/Wallpapers" saved="$HOME/.cache/pantheme-test-walls"
if [ "${1:-}" = restore ]; then
  rm -rf "$walls"
  mv "$saved" "$walls"
  exit 0
fi
mv "$walls" "$saved"
mkdir -p "$walls/matrix"
cp "$saved/matrix/"*.jpg "$walls/matrix/"
python3 - "$walls" <<'PY'
import sys
from pathlib import Path
from PIL import Image
# theme: (top, bottom) colors of a vertical gradient
themes = {
    "tokyo-night": ("#24283b", "#1a1b26"),
    "catppuccin-latte": ("#dce0e8", "#eff1f5"),
    "gruvbox": ("#3c3836", "#1d2021"),
}
for name, (top, bottom) in themes.items():
    a, b = (tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in (top, bottom))
    img = Image.new("RGB", (1, 256))
    for y in range(256):
        img.putpixel((0, y), tuple(round(a[i] + (b[i] - a[i]) * y / 255) for i in range(3)))
    d = Path(sys.argv[1]) / name
    d.mkdir(parents=True, exist_ok=True)
    img.resize((1920, 1080)).save(d / "plain.jpg", quality=95)
PY
ls "$walls"
