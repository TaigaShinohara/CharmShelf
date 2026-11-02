#!/usr/bin/env python3
"""Run Flutter with optional local SDK/JDK and temporary process-only settings."""
import argparse, json, os
from pathlib import Path
import platform, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__,allow_abbrev=False)
    parser.add_argument("--java-home")
    parser.add_argument("--android-sdk")
    args,command=parser.parse_known_args()
    if not command: parser.error("provide a Flutter command, e.g. build apk --debug")
    local=ROOT/"build/toolchains/flutter-3.47.9/bin/flutter"
    executable=str(local) if local.is_file() else shutil.which("flutter")
    if not executable: raise SystemExit("Install Flutter 3.47.9 and add its bin directory to PATH")
    if platform.system() not in {"Darwin","Linux"}:
        raise SystemExit("This optional isolated wrapper supports macOS/Linux; use Flutter directly on other hosts")
    if (Path.home()/".flutter_settings").is_file():
        raise SystemExit("Legacy home Flutter settings override process isolation. Review them yourself; this script will not change global settings.")
    java=args.java_home or os.environ.get("JAVA_HOME")
    if not java and platform.system()=="Darwin":
        result=subprocess.run(["/usr/libexec/java_home","-v","17"],capture_output=True,text=True)
        if result.returncode==0: java=result.stdout.strip()
    config={}
    if java:
        if not (Path(java)/"bin/java").is_file():raise SystemExit("Selected JDK is missing bin/java")
        config["jdk-dir"]=str(Path(java).resolve())
    android=args.android_sdk or os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if not android and platform.system()=="Darwin" and (Path.home()/"Library/Android/sdk").is_dir():
        android=str(Path.home()/"Library/Android/sdk")
    if android: config["android-sdk"]=str(Path(android).resolve())
    with tempfile.TemporaryDirectory(prefix="charmshelf-flutter-config-") as temporary:
        Path(temporary,"settings").write_text(json.dumps(config)+"\n")
        environment=os.environ.copy();environment["XDG_CONFIG_HOME"]=temporary
        environment["PATH"]=str(Path(executable).parent)+os.pathsep+environment.get("PATH","")
        if java:environment["JAVA_HOME"]=java
        raise SystemExit(subprocess.run([executable,*command],cwd=ROOT,env=environment).returncode)
if __name__=="__main__":main()
