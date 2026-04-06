#!/usr/bin/env bash
set -euo pipefail

# Fix summary (web startup freeze at "Preparing... (1/2)"):
# - Patched web/love.js so IDBFS init always unblocks startup.
# - Added a 3s timeout fallback for IDBFS sync on startup.
# - Falls back to MEMFS when IDBFS fails (prevents ENOSPC crashes).
#
# Useful commands while testing:
#   ./host.sh 8000
#
# If browser storage is stuck/full, run this in the page DevTools console:
#   indexedDB.deleteDatabase('/home/web_user/love')
# Then hard refresh:
#   macOS: Cmd+Shift+R
#   Windows/Linux: Ctrl+F5
#
PORT="${1:-8000}"
WEB_DIR="web"
DEFAULT_INDEX="index_weird.html"

python3 - <<'PY'
from pathlib import Path

love_path = Path("web/love.js")
if not love_path.exists():
    raise SystemExit(0)

src = love_path.read_text(encoding="utf-8")
old = 'if(typeof ENVIRONMENT_IS_PTHREAD==="undefined"||!ENVIRONMENT_IS_PTHREAD){Module.addRunDependency("IDBFS_sync");FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");FS.syncfs(true,function(err){if(err){Module["printErr"](err)}else{Module.removeRunDependency("IDBFS_sync")}});window.addEventListener("beforeunload",function(event){FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})})}'
mid = 'if(typeof ENVIRONMENT_IS_PTHREAD==="undefined"||!ENVIRONMENT_IS_PTHREAD){var idbMounted=false;var idbReady=false;function finishIdbInit(){if(idbReady)return;idbReady=true;try{Module.removeRunDependency("IDBFS_sync")}catch(_e){}}try{Module.addRunDependency("IDBFS_sync");FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");idbMounted=true;var idbTimeout=setTimeout(function(){Module["printErr"]("IDBFS init timeout; continuing without blocking startup");finishIdbInit()},3000);FS.syncfs(true,function(err){clearTimeout(idbTimeout);if(err){Module["printErr"]("IDBFS init failed: "+err)}finishIdbInit()})}catch(e){Module["printErr"]("IDBFS unavailable: "+e);finishIdbInit()}window.addEventListener("beforeunload",function(event){if(!idbMounted)return;try{FS.syncfs(false,function(err){if(err){Module["printErr"]("IDBFS save failed: "+err)}})}catch(e){Module["printErr"]("IDBFS save failed: "+e)}})}'
new = 'if(typeof ENVIRONMENT_IS_PTHREAD==="undefined"||!ENVIRONMENT_IS_PTHREAD){var idbMounted=false;var idbReady=false;function fallbackToMemfs(reason){Module["printErr"]("IDBFS disabled: "+reason);if(idbMounted){try{FS.unmount("/home/web_user/love")}catch(_e){}}try{FS.mount(MEMFS,{},"/home/web_user/love")}catch(_e){}idbMounted=false}function finishIdbInit(){if(idbReady)return;idbReady=true;try{Module.removeRunDependency("IDBFS_sync")}catch(_e){}}try{Module.addRunDependency("IDBFS_sync");FS.mkdir("/home/web_user/love");FS.mount(IDBFS,{},"/home/web_user/love");idbMounted=true;var idbTimeout=setTimeout(function(){fallbackToMemfs("timeout");finishIdbInit()},3000);FS.syncfs(true,function(err){clearTimeout(idbTimeout);if(err){fallbackToMemfs(err)}finishIdbInit()})}catch(e){fallbackToMemfs(e);finishIdbInit()}window.addEventListener("beforeunload",function(event){if(!idbMounted)return;try{FS.syncfs(false,function(err){if(err){fallbackToMemfs(err)}})}catch(e){fallbackToMemfs(e)}})}'

if new in src:
    print("love.js patch already present")
elif mid in src:
    love_path.write_text(src.replace(mid, new), encoding="utf-8")
    print("updated love.js patch to MEMFS fallback variant")
elif old in src:
    love_path.write_text(src.replace(old, new), encoding="utf-8")
    print("reapplied love.js IDBFS startup patch with MEMFS fallback")
else:
    print("warning: expected IDBFS block not found in love.js")

game_js_path = Path("web/game.js")
if game_js_path.exists():
    game_js = game_js_path.read_text(encoding="utf-8")
    if '"filename":""' in game_js:
        raise SystemExit(
            "web/game.js is invalid: package metadata contains empty filenames.\n"
            "Rebuild web assets with ./build_web.sh (do not use `love.js . web/ ...`)."
        )
PY

python3 - "$PORT" "$WEB_DIR" "$DEFAULT_INDEX" <<'PY'
import http.server
import socketserver
import sys
from pathlib import Path

port = int(sys.argv[1])
web_dir = sys.argv[2]
default_index = sys.argv[3]
default_index_exists = Path(web_dir, default_index).exists()

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            target = "/" + (default_index if default_index_exists else "index.html")
            self.path = target
        return super().do_GET()

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

with socketserver.TCPServer(("", port), lambda *a, **k: Handler(*a, directory=web_dir, **k)) as httpd:
    active_index = default_index if default_index_exists else "index.html"
    print(f"Serving {web_dir}/ on http://localhost:{port} (index: {active_index})")
    httpd.serve_forever()
PY
