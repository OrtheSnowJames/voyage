#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build_web.sh [memory_bytes] [title]
# Example:
#   ./build_web.sh 200000000 voyage

MEMORY="${1:-200000000}"
TITLE="${2:-voyage}"
OUT_DIR="web"
CUSTOM_INDEX_SRC="index_weird.html"
CUSTOM_INDEX_DST="$OUT_DIR/index_weird.html"

# Important: do NOT pass "." directly to love.js.
# love.js 11.4.1 treats input as a regex and "." causes empty filenames in game.js.
SRC_TMP="$(mktemp -d /tmp/voyage-web-src.XXXXXX)"
cleanup() {
  rm -rf "$SRC_TMP"
}
trap cleanup EXIT

rsync -a --delete \
  --exclude '.git' \
  --exclude 'web' \
  --exclude '.mypy_cache' \
  --exclude '__pycache__' \
  ./ "$SRC_TMP/"

love.js "$SRC_TMP" "$OUT_DIR/" -t "$TITLE" -c -m "$MEMORY"

# Add a small on-page JS error log so runtime failures are visible without opening devtools.
python3 - "$OUT_DIR/index.html" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

canvas_block = '<canvas id="canvas" oncontextmenu="event.preventDefault()"></canvas>'
log_block = (
    canvas_block +
    '\n        <pre id="errorLog" style="display:none;max-width:800px;text-align:left;'
    'white-space:pre-wrap;background:#111;color:#f88;padding:8px;margin-top:8px;"></pre>'
)
if '<pre id="errorLog"' not in text and canvas_block in text:
    text = text.replace(canvas_block, log_block)

needle = "var Module = {\n        arguments: [\"./\"],"
replacement = (
    "var errorLog = document.getElementById('errorLog');\n"
    "      var Module = {\n"
    "        arguments: [\"./\"],"
)
if "var errorLog = document.getElementById('errorLog');" not in text and needle in text:
    text = text.replace(needle, replacement)

print_err_needle = "printErr: console.error.bind(console),"
print_err_replacement = (
    "printErr: function(msg) {\n"
    "          console.error(msg);\n"
    "          errorLog.style.display = 'block';\n"
    "          errorLog.textContent += String(msg) + \"\\n\";\n"
    "        },"
)
if print_err_needle in text:
    text = text.replace(print_err_needle, print_err_replacement)

path.write_text(text, encoding="utf-8")
PY

# If a custom root-level index exists, copy it into web/ so host.sh can serve it.
if [ -f "$CUSTOM_INDEX_SRC" ]; then
  cp "$CUSTOM_INDEX_SRC" "$CUSTOM_INDEX_DST"
  echo "Copied custom index: $CUSTOM_INDEX_SRC -> $CUSTOM_INDEX_DST"

  cat > "$OUT_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=./index_weird.html">
    <title>Redirecting...</title>
    <script>
      (function() {
        var target = "./index_weird.html" + window.location.search + window.location.hash;
        window.location.replace(target);
      })();
    </script>
  </head>
  <body>
    Redirecting to <a href="./index_weird.html">index_weird.html</a>...
  </body>
</html>
HTML
  echo "Replaced web/index.html with redirect to index_weird.html"
fi

# Ensure the game canvas is shown even if status hooks miss the final transition.
python3 - "$OUT_DIR/index.html" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old = (
    "      var applicationLoad = function(e) {\n"
    "        Love(Module);\n"
    "      }"
)
new = (
    "      function showGameCanvas() {\n"
    "        document.getElementById('loadingCanvas').style.display = 'none';\n"
    "        document.getElementById('canvas').style.visibility = 'visible';\n"
    "      }\n\n"
    "      var applicationLoad = function(e) {\n"
    "        Love(Module).then(showGameCanvas);\n"
    "        setTimeout(showGameCanvas, 2000);\n"
    "      }"
)
if old in text:
    text = text.replace(old, new)

path.write_text(text, encoding="utf-8")
PY

if rg -q '"filename":""' "$OUT_DIR/game.js"; then
  echo "Error: generated $OUT_DIR/game.js still has empty filenames." >&2
  exit 1
fi

echo "Web build complete: $OUT_DIR/game.js + $OUT_DIR/game.data"
