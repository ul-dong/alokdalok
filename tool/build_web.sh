#!/bin/zsh
# 알록달록 꼬마 놀이터 - GitHub Pages 용 웹 빌드 (배포는 하지 않는다)
# 결과: build/web  (base-href /alokdalok/, CDN 없이 CanvasKit·MediaPipe 를 모두 앱 안에 담음)
# 빌드 뒤 오프라인 서비스 워커(web/offline_sw.js)가 미리 담을 파일 목록 offline_files.json 을 만든다.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/alokdev/flutter/bin/flutter}"
cd "$REPO"
"$FLUTTER" build web --release --base-href /alokdalok/ --no-web-resources-cdn "$@"
python3 - "$REPO/build/web" <<'PY'
import hashlib, json, os, sys
root = sys.argv[1]
skip_names = {"offline_sw.js", "offline_files.json", "flutter_service_worker.js", ".last_build_id"}
files, h = [], hashlib.sha256()
for d, _, names in os.walk(root):
    for n in sorted(names):
        rel = os.path.relpath(os.path.join(d, n), root).replace(os.sep, "/")
        if n in skip_names or n.endswith(".symbols"):
            continue
        # dart2js + CanvasKit 빌드라서 skwasm·wimp·webparagraph 엔진은 쓰지 않는다.
        if rel.startswith("canvaskit/") and (
            "/webparagraph/" in "/" + rel or os.path.basename(rel).startswith(("skwasm", "wimp"))):
            continue
        files.append(rel)
        h.update(rel.encode())
        h.update(open(os.path.join(d, n), "rb").read())
files.sort()
version = h.hexdigest()[:12]
json.dump({"version": version, "files": files}, open(os.path.join(root, "offline_files.json"), "w"), indent=0)
with open(os.path.join(root, "offline_sw.js"), "a") as f:
    f.write(f"\n// build {version}\n")
size = sum(os.path.getsize(os.path.join(root, p)) for p in files)
mp = [p for p in files if p.startswith("mediapipe/")]
print(f"오프라인 목록: 파일 {len(files)}개, {size / 1e6:.1f}MB (MediaPipe {len(mp)}개), 버전 {version}")
PY
