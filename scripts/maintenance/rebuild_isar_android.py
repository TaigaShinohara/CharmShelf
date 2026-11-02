#!/usr/bin/env python3
"""Rebuild the pinned Isar Android libraries with private source paths remapped.

Fetch the documented fixed Isar archive and libmdbx checkout first. Run
--fetch-only once with network access, then run the build offline. Libraries
are staged and validated before --install can replace repository binaries.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ISAR_COMMIT = "6643d064abf22606b6c6a741ea873e4781115ef4"
ISAR_ARCHIVE_SHA256 = "e77776fd6a67e9516c8beae292bdc6010dd0c554cd8735d8bf8163ed2f96896c"
MDBX_COMMIT = "53177e483c18adf5109aed7a5895915e9798ee24"
LOCK_SHA256 = "83bfd3abef120b8d5e264e70fbbe96a89455d14bac738324dd50be88a05e900c"
NDK_VERSION = "28.2.13676358"
RUST_TOOLCHAIN = "1.88.0"
TARGETS = {
    "arm64-v8a": ("aarch64-linux-android", "aarch64-linux-android21"),
    "armeabi-v7a": ("armv7-linux-androideabi", "armv7a-linux-androideabi21"),
    "x86": ("i686-linux-android", "i686-linux-android21"),
    "x86_64": ("x86_64-linux-android", "x86_64-linux-android21"),
}
KNOWN_CRATES = {
    "byteorder": "1.5.0", "crossbeam-channel": "0.5.16", "intmap": "2.0.0",
    "itoa": "1.0.18", "once_cell": "1.21.4", "serde_core": "1.0.229",
    "serde_json": "1.0.151", "threadpool": "1.8.1",
    "unicode-segmentation": "1.13.3",
}
PRIVATE_PATH = re.compile(rb"(?:/Users/|/home/)[A-Za-z0-9_.-]+/|[A-Za-z]:[\\/]Users[\\/]")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_hash(path: Path, expected: str) -> None:
    if digest(path) != expected:
        raise ValueError(f"Pinned input checksum mismatch: {path.name}")


def redacted(text: str) -> str:
    text = text.replace(str(Path.home()), "[home]")
    return re.sub(r"/(?:Users|home)/[^/\s]+", "/[private-home]", text)


def run(command: list[str], *, cwd: Path | None = None,
        env: dict[str, str] | None = None, log: Path | None = None) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True)
    output = redacted(result.stdout + result.stderr)
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(output)
    if result.returncode:
        print(output[-6000:], file=sys.stderr)
        raise RuntimeError(f"{Path(command[0]).name} failed with exit {result.returncode}")
    return result.stdout


def toolchain_binary(name: str) -> Path:
    rustup = shutil.which("rustup")
    if not rustup:
        raise ValueError("The pinned Rust toolchain must already be installed")
    return Path(run([rustup, "which", "--toolchain", RUST_TOOLCHAIN, name]).strip())


def exported_symbols(library: Path, nm: Path) -> set[tuple[str, str]]:
    output = run([str(nm), "--dynamic", "--defined-only", "--format=posix", str(library)])
    return {(parts[0], parts[1]) for line in output.splitlines()
            if len(parts := line.split()) >= 2}


def validate_library(path: Path, original: Path, nm: Path) -> dict[str, object]:
    module_path = ROOT / "scripts/maintenance/check_android_bundle.py"
    spec = importlib.util.spec_from_file_location("android_bundle_gate", module_path)
    if spec is None or spec.loader is None:
        raise ValueError("Cannot load the existing Android ELF gate")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    data = path.read_bytes()
    alignments = module.load_alignments(data)
    if not alignments or min(alignments) < 0x4000:
        raise ValueError(f"16KB alignment failed: {path.parent.name}")
    if b"3.1.0+1" not in data:
        raise ValueError(f"Isar version marker missing: {path.parent.name}")
    if PRIVATE_PATH.search(data):
        raise ValueError(f"Private home path remains: {path.parent.name}")
    expected = exported_symbols(original, nm)
    actual = exported_symbols(path, nm)
    if not expected or actual != expected:
        raise ValueError(f"Exported name/type ABI changed: {path.parent.name}")
    return {"sha256": digest(path), "load_alignments": alignments,
            "exported_symbols": len(actual), "private_home_paths": 0}


def prepare(args: argparse.Namespace) -> tuple[Path, dict[str, str], Path, Path]:
    checked_hash(args.isar_archive, ISAR_ARCHIVE_SHA256)
    checked_hash(args.lock_file, LOCK_SHA256)
    packages = tomllib.loads(args.lock_file.read_text())["package"]
    versions = {p["name"]: p["version"] for p in packages}
    if any(versions.get(k) != v for k, v in KNOWN_CRATES.items()):
        raise ValueError("The old binary's known crate versions must remain fixed")
    head = run(["git", "-c", "core.fsmonitor=false", "-C", str(args.libmdbx_dir),
                "rev-parse", "HEAD"]).strip()
    tag = run(["git", "-c", "core.fsmonitor=false", "-C", str(args.libmdbx_dir),
               "rev-parse", "v0.12.4^{commit}"]).strip()
    if head != MDBX_COMMIT or tag != MDBX_COMMIT:
        raise ValueError("libmdbx HEAD and v0.12.4 must match the pinned commit")
    if run(["git", "-c", "core.fsmonitor=false", "-C", str(args.libmdbx_dir),
            "status", "--porcelain"]).strip():
        raise ValueError("libmdbx input checkout must be clean")
    ndk_revision = (args.ndk / "source.properties").read_text()
    if not re.search(rf"Pkg.Revision\s*=\s*{re.escape(NDK_VERSION)}\s*$",
                     ndk_revision, re.MULTILINE):
        raise ValueError("The pinned Android NDK is required")
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    if PRIVATE_PATH.search(str(work).encode()):
        raise ValueError("Use a build directory outside private home paths")
    if shutil.disk_usage(work).free < 5 * 1024**3:
        raise ValueError("At least 5GB of free disk is required")
    source = work / f"isar-{ISAR_COMMIT}"
    if not source.exists():
        with tarfile.open(args.isar_archive) as archive:
            archive.extractall(work, filter="data")
    # Reusing a workspace must not silently reuse modified source inputs.
    with tarfile.open(args.isar_archive) as archive:
        for member in archive:
            if not member.isfile():
                continue
            original = archive.extractfile(member)
            current = work / member.name
            if original is None or not current.is_file() or (
                hashlib.sha256(original.read()).hexdigest() != digest(current)
            ):
                raise ValueError(f"Pinned source was changed: {Path(member.name).name}")
    shutil.copy2(args.lock_file, source / "Cargo.lock")
    ndk_link = work / "ndk"
    if not ndk_link.exists():
        ndk_link.symlink_to(args.ndk.resolve(), target_is_directory=True)
    elif ndk_link.resolve() != args.ndk.resolve():
        raise ValueError("The build directory points to a different NDK")
    ndk_bin = ndk_link / "toolchains/llvm/prebuilt/darwin-x86_64/bin"
    cargo = toolchain_binary("cargo")
    rustc = toolchain_binary("rustc")
    wrappers = work / "tools"
    wrappers.mkdir(exist_ok=True)
    real_git = shutil.which("git")
    if not real_git:
        raise ValueError("git is required")
    # Upstream build.rs clones this tag on every target. Serve only the pinned
    # verified local checkout so that all compilation can stay offline.
    wrapper = wrappers / "git"
    wrapper.write_text(
        "#!/usr/bin/env python3\nimport os,sys\n"
        "args=sys.argv[1:]\n"
        "if args[:2]==['clone','https://github.com/isar/libmdbx.git']:\n"
        f" args[1]={str(args.libmdbx_dir.resolve())!r}\n"
        " args.append('libmdbx')\n"
        "elif any(x.startswith(('https://','http://','ssh://')) for x in args):\n"
        " raise SystemExit('Unexpected network git command during offline build')\n"
        f"os.execv({real_git!r},[{real_git!r},'-c','core.hooksPath=/dev/null',*args])\n"
    )
    wrapper.chmod(0o755)
    cargo_home = work / "cargo-home"
    cargo_home.mkdir(exist_ok=True)
    env = {k: v for k, v in os.environ.items()
           if k in {"HOME", "TMPDIR", "LANG", "LC_ALL", "RUSTUP_HOME"}}
    env.update({
        "PATH": os.pathsep.join([str(wrappers), str(ndk_bin), str(cargo.parent),
                                  "/opt/homebrew/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]),
        "CARGO_HOME": str(cargo_home), "RUSTC": str(rustc),
        "CARGO_BUILD_JOBS": str(args.jobs), "CARGO_TERM_COLOR": "never",
        "ISAR_VERSION": "3.1.0+1", "GIT_TERMINAL_PROMPT": "0",
        "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null",
        "GIT_CONFIG_NOSYSTEM": "1",
        "LIBCLANG_PATH": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib",
    })
    return source, env, cargo, ndk_bin


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--isar-archive", type=Path, required=True)
    parser.add_argument("--libmdbx-dir", type=Path, required=True)
    parser.add_argument("--ndk", type=Path, required=True)
    parser.add_argument("--lock-file", type=Path, default=Path(__file__).with_name("isar_android.Cargo.lock"))
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--jobs", type=int, choices=(1, 2), default=2)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--fetch-only", action="store_true")
    mode.add_argument("--install", action="store_true")
    args = parser.parse_args()
    source, env, cargo, ndk_bin = prepare(args)
    work = args.work_dir.resolve()
    if args.fetch_only:
        run([str(cargo), "fetch", "--locked", "--manifest-path", str(source / "Cargo.toml")],
            cwd=source, env=env, log=work / "logs/fetch.log")
        print("Pinned Cargo inputs fetched; no build was started")
        return
    env["CARGO_NET_OFFLINE"] = "true"
    original_dir = work / "originals"
    report: dict[str, object] = {}
    libraries = ROOT / "patches/isar_flutter_libs/android/src/main/jniLibs"
    for abi, (target, clang_target) in TARGETS.items():
        original = original_dir / abi / "libisar.so"
        original.parent.mkdir(parents=True, exist_ok=True)
        if not original.exists():
            shutil.copy2(libraries / abi / "libisar.so", original)
        target_env = env.copy()
        target_key = target.replace("-", "_")
        target_env[f"CARGO_TARGET_{target_key.upper()}_LINKER"] = str(ndk_bin / f"{clang_target}-clang")
        target_env[f"CC_{target_key}"] = str(ndk_bin / f"{clang_target}-clang")
        target_env[f"AR_{target_key}"] = str(ndk_bin / "llvm-ar")
        target_env[f"CFLAGS_{target_key}"] = (
            f"-ffile-prefix-map={work}=/build -fdebug-prefix-map={work}=/build"
        )
        target_env["BINDGEN_EXTRA_CLANG_ARGS"] = (
            f"--target={clang_target} --sysroot={ndk_bin.parent / 'sysroot'}"
        )
        target_env["CARGO_ENCODED_RUSTFLAGS"] = "\x1f".join([
            "-C", "link-arg=-Wl,--hash-style=both",
            "-C", "link-arg=-Wl,-z,max-page-size=16384",
            f"--remap-path-prefix={work}=/build",
            f"--remap-path-prefix={Path.home()}=/private-home",
        ])
        print(f"Building {abi} with the pinned offline inputs", flush=True)
        run([str(cargo), "build", "--release", "--locked", "--offline",
             "--target", target, "--jobs", str(args.jobs)],
            cwd=source / "packages/isar_core_ffi", env=target_env,
            log=work / f"logs/{abi}.log")
        candidate = work / "outputs" / abi / "libisar.so"
        candidate.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / "target" / target / "release/libisar.so", candidate)
        report[abi] = validate_library(candidate, original, ndk_bin / "llvm-nm")
        print(f"Validated {abi}: public ABI, version, 16KB alignment, private paths", flush=True)
    (work / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    if args.install:
        for abi in TARGETS:
            target = libraries / abi / "libisar.so"
            staged = target.with_suffix(".so.tmp")
            shutil.copyfile(work / "outputs" / abi / "libisar.so", staged)
            staged.chmod(stat.S_IMODE(target.stat().st_mode))
            staged.replace(target)
        print("Installed all four validated libraries; originals remain in the build workspace")
    else:
        print("Validated candidates are staged; repository binaries were not changed")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(redacted(str(error)), file=sys.stderr)
        raise SystemExit(1)
