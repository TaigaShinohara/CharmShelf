#!/usr/bin/env python3
"""Run Flutter with optional local SDK/JDK and temporary process-only settings."""
import argparse, json, os
from pathlib import Path
import platform, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def java_is_usable(home):
    binary=Path(home)/"bin/java"
    if not binary.is_file(): return False
    try:
        return subprocess.run([str(binary),"-version"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15).returncode==0
    except (OSError,subprocess.TimeoutExpired):
        return False

def system_java_home():
    if platform.system()=="Darwin":
        result=subprocess.run(["/usr/libexec/java_home","-v","17"],capture_output=True,text=True,timeout=15)
        return result.stdout.strip() if result.returncode==0 else None
    binary=shutil.which("java")
    return str(Path(binary).resolve().parent.parent) if binary else None

def select_java_home(explicit,inherited):
    if explicit:
        if not java_is_usable(explicit): raise SystemExit("The explicit JDK cannot execute; choose a compatible --java-home")
        return str(Path(explicit).resolve())
    if inherited and java_is_usable(inherited): return str(Path(inherited).resolve())
    discovered=system_java_home()
    return str(Path(discovered).resolve()) if discovered and java_is_usable(discovered) else None

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
    java=select_java_home(args.java_home,os.environ.get("JAVA_HOME"))
    config={}
    if java: config["jdk-dir"]=java
    android=args.android_sdk or os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if not android and platform.system()=="Darwin" and (Path.home()/"Library/Android/sdk").is_dir():
        android=str(Path.home()/"Library/Android/sdk")
    if android: config["android-sdk"]=str(Path(android).resolve())
    with tempfile.TemporaryDirectory(prefix="charmshelf-flutter-config-") as temporary:
        Path(temporary,"settings").write_text(json.dumps(config)+"\n")
        environment=os.environ.copy();environment["XDG_CONFIG_HOME"]=temporary
        environment["PATH"]=str(Path(executable).parent)+os.pathsep+environment.get("PATH","")
        if java:environment["JAVA_HOME"]=java
        else:environment.pop("JAVA_HOME",None)
        raise SystemExit(subprocess.run([executable,*command],cwd=ROOT,env=environment).returncode)
if __name__=="__main__":main()
