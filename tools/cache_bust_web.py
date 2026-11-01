#!/usr/bin/env python3
"""Stamp a Godot 4.7 web export so the next page load cannot reuse the previous build.

GitHub Pages sends Cache-Control: max-age=600 and the export uses fixed names
(index.js, index.pck, index.wasm). Safari will keep playing those bytes.
This renames every engine file with the commit sha, points index.html at the
new names, and refuses to boot a page whose baked sha is older than version.json.

Query params already on the URL (?mode=flappy, ?mode=hop, ?seed=, ?form=) are
left in place. v= and sw= are only cache-bust keys; the game ignores them.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def build_id() -> str:
    override = ""
    for arg in sys.argv[1:]:
        if arg.startswith("--build="):
            override = arg.split("=", 1)[1].strip()
    if not override:
        override = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", override):
        raise SystemExit("build id must be a commit sha, got %r" % override)
    return override.lower()


def extract_config(html: str) -> tuple[int, int, dict]:
    marker = "const GODOT_CONFIG = "
    start = html.find(marker)
    if start < 0:
        raise SystemExit("index.html has no GODOT_CONFIG")
    body = start + len(marker)
    if body >= len(html) or html[body] != "{":
        raise SystemExit("GODOT_CONFIG is not a JSON object")
    depth = 0
    in_str = False
    esc = False
    end = body
    while end < len(html):
        ch = html[end]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end += 1
                break
        end += 1
    else:
        raise SystemExit("GODOT_CONFIG ran off the end of index.html")
    try:
        config = json.loads(html[body:end])
    except json.JSONDecodeError as exc:
        raise SystemExit("GODOT_CONFIG is not JSON: %s" % exc) from exc
    return body, end, config


def rewrite(text: str, mapping: dict[str, str]) -> str:
    for old in sorted(mapping, key=len, reverse=True):
        text = text.replace(old, mapping[old])
    return text


def patch_service_worker(text: str) -> str:
    needle = "let cached = await cache.match(event.request);"
    if needle not in text:
        raise SystemExit("Godot service worker is still cache-first; refusing to publish it")
    text = text.replace(
        needle,
        "let cached = null; // never answer a navigation or engine file from the worker cache",
        1,
    )
    prelude = (
        "self.addEventListener('install', function () { self.skipWaiting(); });\n"
        "self.addEventListener('activate', function (event) {\n"
        "\tevent.waitUntil(self.clients.claim());\n"
        "});\n"
    )
    if "self.skipWaiting()" not in text:
        text = prelude + text
    return text


KILLER_WORKER = """\
// Stable name a previously installed Godot worker was registered under.
// It does not cache. skipWaiting drops the old Cache Storage so the next
// navigation loads the network copy of index.html.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
	event.waitUntil((async function () {
		var keys = await caches.keys();
		await Promise.all(keys.map(function (key) { return caches.delete(key); }));
		await self.clients.claim();
		var windows = await self.clients.matchAll({ type: 'window' });
		for (var i = 0; i < windows.length; i++) {
			if (windows[i].navigate) {
				windows[i].navigate(windows[i].url);
			}
		}
	})());
});
"""


def loader(build: str, src: str, worker: str) -> str:
    # v and sw are not game flags. mode, seed, and form stay on the URL.
    return """<script>
window.__rawDeferEngine = true;
(function () {
	var BUILD = %s;
	var SRC = %s;
	var WORKER = %s;
	function loadEngine() {
		var script = document.createElement("script");
		script.src = SRC;
		script.onload = function () {
			if (window.__rawStartEngine) {
				window.__rawStartEngine();
			}
		};
		script.onerror = function () {
			var notice = document.getElementById("status-notice");
			if (notice) {
				notice.textContent = "Could not load this build. Reload the page.";
			}
		};
		document.body.appendChild(script);
	}
	function reloadOnce(key, value) {
		var url = new URL(window.location.href);
		if (url.searchParams.get(key) === value) {
			return false;
		}
		url.searchParams.set(key, value);
		window.location.replace(url.toString());
		return true;
	}
	function clearStaleWorkers() {
		if (!("serviceWorker" in navigator) || !navigator.serviceWorker.getRegistrations) {
			return Promise.resolve(false);
		}
		return navigator.serviceWorker.getRegistrations().then(function (regs) {
			var stale = regs.filter(function (reg) {
				var worker = reg.active || reg.waiting || reg.installing;
				var scriptURL = worker ? worker.scriptURL : "";
				var name = scriptURL.split("?")[0].split("/").pop();
				return !(WORKER && name === WORKER);
			});
			if (!stale.length) {
				return false;
			}
			return Promise.all(stale.map(function (reg) { return reg.unregister(); })).then(function () {
				if (!window.caches || !caches.keys) {
					return true;
				}
				return caches.keys().then(function (keys) {
					return Promise.all(keys.map(function (key) { return caches.delete(key); }));
				}).then(function () { return true; });
			});
		}).catch(function () { return false; });
	}
	function checkVersion() {
		fetch("version.json?t=" + Date.now(), { cache: "no-store", credentials: "same-origin" }).then(function (res) {
			if (!res.ok) {
				throw new Error("version");
			}
			return res.json();
		}).then(function (data) {
			var remote = data && data.build;
			if (remote && remote !== BUILD) {
				if (!reloadOnce("v", remote)) {
					loadEngine();
				}
				return;
			}
			loadEngine();
		}).catch(function () { loadEngine(); });
	}
	clearStaleWorkers().then(function (cleared) {
		if (cleared && reloadOnce("sw", "0")) {
			return;
		}
		checkVersion();
	});
})();
</script>""" % (json.dumps(build), json.dumps(src), json.dumps(worker))


def bust(root: Path, build: str) -> None:
    html_path = root / "index.html"
    if not html_path.is_file():
        raise SystemExit("missing %s" % html_path)
    html = html_path.read_text()
    if "function __rawStartEngine" not in html:
        raise SystemExit("index.html cannot defer engine startup")
    if "unlockGodotAudio" not in html:
        raise SystemExit("index.html lost the iOS audio unlock")
    _body, _end, config = extract_config(html)
    base = str(config.get("executable") or "index")
    if not re.fullmatch(r"[A-Za-z0-9._-]+", base):
        raise SystemExit("unexpected executable name %r" % base)
    new_base = "%s.%s" % (base, build)
    coi_before = config.get("ensureCrossOriginIsolationHeaders")
    threads_off = "const GODOT_THREADS_ENABLED = false" in html
    if "const GODOT_THREADS_ENABLED = true" in html or not threads_off:
        raise SystemExit("refusing to cache-bust a threaded web export")

    mapping: dict[str, str] = {}
    for path in sorted(root.iterdir()):
        if not path.is_file():
            continue
        name = path.name
        if name == "%s.html" % base or not name.startswith(base + "."):
            continue
        mapping[name] = new_base + name[len(base):]
    for required in ("%s.js" % base, "%s.wasm" % base, "%s.pck" % base):
        if required not in mapping:
            raise SystemExit("export is missing %s" % required)

    for old, new in mapping.items():
        (root / old).rename(root / new)

    html = rewrite(html, mapping)
    body, end, config = extract_config(html)
    config["executable"] = new_base
    sizes = config.get("fileSizes") or {}
    config["fileSizes"] = {mapping.get(str(key), str(key)): value for key, value in sizes.items()}
    worker = str(config.get("serviceWorker") or "")
    if worker:
        config["serviceWorker"] = mapping.get(worker, worker)
        worker = str(config["serviceWorker"])
    if config.get("ensureCrossOriginIsolationHeaders") != coi_before:
        raise SystemExit("cross-origin isolation flag changed")
    html = html[:body] + json.dumps(config, separators=(",", ":")) + html[end:]

    src = "%s.js" % new_base
    pattern = re.compile(r"<script\s+src=\"%s\"></script>" % re.escape(src))
    if len(pattern.findall(html)) != 1:
        raise SystemExit("expected one engine script tag for %s" % src)
    html = pattern.sub(lambda _match: loader(build, src, worker), html, count=1)
    if "function __rawStartEngine" not in html or "window.__rawDeferEngine = true" not in html:
        raise SystemExit("engine loader was not installed")
    if "new URL(window.location.href)" not in html or "searchParams.set" not in html:
        raise SystemExit("version reload would drop the page query")
    if "Cache-Control" not in html:
        raise SystemExit("index.html has no cache hint")
    html_path.write_text(html)

    # The engine js/wasm/pck are loaded by the stamped executable name.
    # Rewriting those binaries would corrupt them. Only the worker, manifest,
    # and offline page embed the old file names as strings.
    for suffix in (".service.worker.js", ".manifest.json", ".offline.html"):
        path = root / ("%s%s" % (new_base, suffix))
        if path.is_file():
            path.write_text(rewrite(path.read_text(), mapping))

    sw_path = root / ("%s.service.worker.js" % new_base)
    if sw_path.is_file():
        sw_path.write_text(patch_service_worker(sw_path.read_text()))
    # A worker already registered at the unstamped name will not see a renamed
    # script. Leave an update worker at that stable URL. The page unregisters
    # it when it is not the worker for this build.
    killer = root / ("%s.service.worker.js" % base)
    if killer.resolve() != sw_path.resolve():
        killer.write_text(KILLER_WORKER)

    (root / "version.json").write_text(json.dumps({"build": build}, indent=2) + "\n")

    bare = ('"%s.js"' % base, '"%s.wasm"' % base, '"%s.pck"' % base, "src=\"%s.js\"" % base)
    final = html_path.read_text()
    for token in bare:
        if token in final:
            raise SystemExit("index.html still references %s" % token)
    if '"%s"' % new_base not in final and "'%s'" % new_base not in final:
        raise SystemExit("executable was not stamped")
    # The unstamped service-worker URL is reused on purpose: an already
    # installed worker only updates if that exact script URL changes bytes.
    kept = {killer.name} if killer.is_file() and killer.resolve() != sw_path.resolve() else set()
    for old in mapping:
        if old in kept:
            continue
        if (root / old).exists():
            raise SystemExit("old asset still present: %s" % old)
    print("CACHE_BUST build=%s" % build)
    print("CACHE_BUST executable=%s" % new_base)
    print("CACHE_BUST src=%s" % src)
    print("CACHE_BUST wasm=%s.wasm" % new_base)
    print("CACHE_BUST pck=%s.pck" % new_base)
    print("CACHE_BUST threads=false")
    print("CACHE_BUST ensureCrossOriginIsolationHeaders=%s" % json.dumps(coi_before))
    print("CACHE_BUST serviceWorker=%s" % (worker or "(none)"))
    renamed = ", ".join(sorted(mapping.values()))
    print("CACHE_BUST files=%s" % renamed)


def self_test() -> None:
    build = "abcdef1234567890"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        html = """<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
</head><body>
<script>function unlockGodotAudio() {}</script>
<script src="index.js"></script>
<script>
const GODOT_CONFIG = {"args":[],"ensureCrossOriginIsolationHeaders":false,"executable":"index","fileSizes":{"index.pck":4,"index.wasm":8},"serviceWorker":"index.service.worker.js"};
const GODOT_THREADS_ENABLED = false;
function __rawStartEngine() {
const engine = new Engine(GODOT_CONFIG);
}
if (!window.__rawDeferEngine) { __rawStartEngine(); }
</script>
<img id="status-splash" src="index.png" alt="">
<link rel="icon" href="index.icon.png">
</body></html>
"""
        (root / "index.html").write_text(html)
        for name in (
            "index.js",
            "index.wasm",
            "index.pck",
            "index.png",
            "index.icon.png",
            "index.audio.worklet.js",
            "index.audio.position.worklet.js",
        ):
            (root / name).write_bytes(b"asset-" + name.encode())
        (root / "favicon.png").write_bytes(b"favicon")
        (root / "index.service.worker.js").write_text(
            "const CACHED_FILES = [\"index.js\", \"index.audio.worklet.js\"];\n"
            "self.addEventListener('fetch', (event) => {\n"
            "  event.respondWith((async () => {\n"
            "    let cached = await cache.match(event.request);\n"
            "    if (cached != null) return cached;\n"
            "    return fetch(event.request);\n"
            "  })());\n"
            "});\n"
        )
        bust(root, build)
        out = (root / "index.html").read_text()
        stamped = "index.%s" % build
        if '"executable":"%s"' % stamped not in out:
            raise SystemExit("self-test: executable not stamped: %s" % out)
        if "src=\"index.js\"" in out or '"index.pck"' in out or '"index.wasm"' in out:
            raise SystemExit("self-test: bare engine names remain")
        if "src=\"%s.png\"" % stamped not in out or "href=\"%s.icon.png\"" % stamped not in out:
            raise SystemExit("self-test: side files were not retargeted")
        if "unlockGodotAudio" not in out or "GODOT_THREADS_ENABLED = false" not in out:
            raise SystemExit("self-test: audio unlock or threads flag changed")
        if '"ensureCrossOriginIsolationHeaders":false' not in out:
            raise SystemExit("self-test: cross-origin isolation changed")
        if "new URL(window.location.href)" not in out:
            raise SystemExit("self-test: query string would be dropped")
        version = json.loads((root / "version.json").read_text())
        if version.get("build") != build:
            raise SystemExit("self-test: version.json mismatch")
        if (root / "favicon.png").read_bytes() != b"favicon":
            raise SystemExit("self-test: favicon was rewritten")
        if (root / "index.js").exists() or (root / "index.wasm").exists() or (root / "index.pck").exists():
            raise SystemExit("self-test: old engine files remain")
        sw = (root / ("%s.service.worker.js" % stamped)).read_text()
        if "let cached = null;" not in sw or "skipWaiting" not in sw:
            raise SystemExit("self-test: service worker still caches")
        if '"%s.js"' % stamped not in sw or '"%s.audio.worklet.js"' % stamped not in sw:
            raise SystemExit("self-test: service worker file list is stale")
        killer = (root / "index.service.worker.js").read_text()
        if "skipWaiting" not in killer or "cache.match" in killer:
            raise SystemExit("self-test: update worker missing")
        print("CACHE_BUST self-test ok")


def main() -> None:
    if "--self-test" in sys.argv:
        self_test()
        return
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--build=")]
    if len(args) != 1:
        raise SystemExit("usage: cache_bust_web.py [--build=SHA] BUILD_DIR")
    bust(Path(args[0]), build_id())


if __name__ == "__main__":
    main()
