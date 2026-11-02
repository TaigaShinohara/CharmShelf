#!/usr/bin/env python3
"""Check publication boundaries without showing file contents or credentials."""
from pathlib import Path
import hashlib, json, subprocess
ROOT = Path(__file__).resolve().parents[2]
def main():
    run = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True)
    names = [p for p in run.stdout.decode().split("\0") if p]
    if not names:
        raise SystemExit("Publication check requires staged or committed source files")
    errors=[]
    forbidden={".agents", ".audit", ".codex", ".cursor", ".kiro", ".vscode", "screenshots"}
    for name in names:
        path=ROOT/name
        if name.split("/")[0] in forbidden or name.startswith("patches/syncfusion"):
            errors.append((name,"private-or-proprietary-source"))
        if name.endswith(".local.json") or name in {"android/local.properties", "android/key.properties"}:
            errors.append((name,"local-configuration"))
        if path.is_symlink(): errors.append((name,"unchecked-symlink"))
    for name in ("pubspec.yaml", "pubspec.lock"):
        if "syncfusion" in (ROOT/name).read_text().lower(): errors.append((name,"proprietary-pdf-dependency"))
    manifest=json.loads((ROOT/"tool/public_assets/manifest.json").read_text())
    for name,expected in manifest["files"].items():
        path=ROOT/name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
            errors.append((name,"public-asset-manifest-mismatch"))
    notices=json.loads((ROOT/"assets/licenses/third_party_notices.json").read_text())
    if any("syncfusion" in e["package"].lower() for e in notices): errors.append(("notices","stale-pdf-notice"))
    for file in ("LICENSE","THIRD_PARTY_NOTICES.md","CONTRIBUTING.md","SECURITY.md"):
        if not (ROOT/file).is_file(): errors.append((file,"missing-public-document"))
    if errors:
        for name,category in errors: print(json.dumps({"file":name,"issue":category}))
        raise SystemExit(1)
    print("Public snapshot checks passed:",len(names),"files;",len(manifest["files"]),"generated assets")
if __name__=="__main__":main()
