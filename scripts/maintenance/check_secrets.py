#!/usr/bin/env python3
"""Run checksum-pinned Gitleaks; emit locations and rule IDs, never matched values."""
from pathlib import Path
import hashlib, json, os, platform, subprocess, tarfile, tempfile, urllib.request
ROOT = Path(__file__).resolve().parents[2]
VERSION = "8.30.1"
ARCHIVES = {
    ("Darwin", "arm64"): ("darwin_arm64", "b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"),
    ("Linux", "x86_64"): ("linux_x64", "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"),
}
def main():
    with tempfile.TemporaryDirectory(prefix="charmshelf-secret-check-") as temporary:
        folder=Path(temporary)
        configured=os.environ.get("GITLEAKS_BIN")
        if configured:
            executable=Path(configured).resolve()
        else:
            choice=ARCHIVES.get((platform.system(),platform.machine()))
            if choice is None:
                raise SystemExit("Set GITLEAKS_BIN to Gitleaks 8.30.1 on this host")
            target,expected=choice
            name=f"gitleaks_{VERSION}_{target}.tar.gz"
            archive=folder/name
            url=f"https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/{name}"
            with urllib.request.urlopen(url,timeout=90) as response:
                archive.write_bytes(response.read())
            if hashlib.sha256(archive.read_bytes()).hexdigest()!=expected:
                raise SystemExit("Gitleaks archive checksum mismatch")
            with tarfile.open(archive) as packed:
                member=packed.getmember("gitleaks")
                if not member.isfile(): raise SystemExit("Invalid Gitleaks executable")
                data=packed.extractfile(member).read()
            executable=folder/"gitleaks";executable.write_bytes(data);executable.chmod(0o700)
        actual=subprocess.run([str(executable),"version"],capture_output=True,text=True,check=True).stdout.strip()
        if actual!=VERSION: raise SystemExit("Gitleaks version mismatch")
        report=folder/"redacted.json"
        listed=subprocess.run(["git","ls-files","-z"],cwd=ROOT,capture_output=True,check=True)
        if not listed.stdout: raise SystemExit("No indexed source files to inspect")
        snapshot=folder/"snapshot";snapshot.mkdir()
        subprocess.run(["git","checkout-index","-a","--prefix="+str(snapshot)+"/"],cwd=ROOT,check=True,capture_output=True)
        scopes=[("indexed snapshot",["dir",str(snapshot)])]
        if subprocess.run(["git","rev-parse","--verify","HEAD"],cwd=ROOT,capture_output=True).returncode==0:
            scopes.append(("all Git history",["git",str(ROOT),"--log-opts=--all"]))
        failed=False
        for index,(scope,args) in enumerate(scopes):
            report=folder/f"redacted-{index}.json"
            result=subprocess.run([str(executable),*args,"--config",str(ROOT/".gitleaks.toml"),"--redact=100","--no-banner","--no-color","--report-format","json","--report-path",str(report)],cwd=ROOT,capture_output=True,text=True)
            if result.returncode not in (0,1) or not report.exists():
                raise SystemExit("Gitleaks failed before producing a redacted report")
            findings=json.loads(report.read_text()) or []
            print("Gitleaks",VERSION,"findings:",len(findings),"scope:",scope)
            for item in findings:
                print(json.dumps({"file":item["File"],"line":item["StartLine"],"rule":item["RuleID"]}))
            failed=failed or result.returncode!=0
        raise SystemExit(1 if failed else 0)

if __name__=="__main__":main()
