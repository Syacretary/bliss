#!/usr/bin/env python3
"""Fetches and verifies the pinned Android libnode release used by Bliss."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import time
import tempfile
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath
from typing import Optional

VERSION_TAG = "v24.21.0-0"
ASSET_NAME = "nodejs-mobile-android-24.21.0-0.zip"
EXPECTED_SHA256 = "e3cd29a1be03405f11dd5c857af8cd3ad13f84f1409ea648f5328f0bada5bd76"
ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")
ROOT = Path(__file__).resolve().parents[2]
CPP_ROOT = ROOT / "MainApp/android/app/src/main/cpp/node-runtime"
JNI_ROOT = ROOT / "MainApp/android/app/src/main/jniLibs"
API_URL = f"https://api.github.com/repos/fogtape/nodejs-mobile/releases/tags/{VERSION_TAG}"


def find_llvm_strip() -> Optional[str]:
    executable = shutil.which("llvm-strip")
    if executable:
        return executable

    sdk_roots = [
        Path(value)
        for key in ("ANDROID_NDK_HOME", "ANDROID_NDK_ROOT", "ANDROID_HOME", "ANDROID_SDK_ROOT")
        if (value := os.environ.get(key))
    ]
    local_properties = ROOT / "MainApp/android/local.properties"
    if local_properties.is_file():
        for line in local_properties.read_text(encoding="utf-8").splitlines():
            if line.startswith("sdk.dir="):
                sdk_roots.append(Path(line.partition("=")[2].replace("\\:", ":")))
                break

    names = ("llvm-strip.exe", "llvm-strip")
    candidates = [
        candidate
        for root in sdk_roots
        for candidate in root.glob("ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-strip*")
        if candidate.name in names and candidate.is_file()
    ]
    return str(sorted(candidates, reverse=True)[0]) if candidates else None


def download(url: str, target: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Bliss-Android-Node-Runtime/1.0"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=60) as response, target.open("wb") as output:
                shutil.copyfileobj(response, output)
            return
        except Exception:
            target.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)


def main() -> None:
    strip_tool = find_llvm_strip()
    if strip_tool is None:
        raise SystemExit("Android NDK llvm-strip was not found; install the NDK to prepare the runtime.")

    expected_version = f"{VERSION_TAG}\nsha256:{EXPECTED_SHA256}\nstrip:unneeded\n"
    required_outputs = [CPP_ROOT / "VERSION", *(JNI_ROOT / abi / "libnode.so" for abi in ABIS)]
    if all(path.is_file() for path in required_outputs) and (CPP_ROOT / "VERSION").read_text(encoding="utf-8") == expected_version:
        print(f"Node mobile {VERSION_TAG} is already prepared; using the pinned local artifact.")
        return

    request = urllib.request.Request(API_URL, headers={"Accept": "application/vnd.github+json", "User-Agent": "Bliss-Android-Node-Runtime/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    if release.get("tag_name") != VERSION_TAG or not release.get("prerelease"):
        raise SystemExit("Pinned Node mobile release metadata did not match the expected prerelease.")
    asset = next((item for item in release.get("assets", []) if item.get("name") == ASSET_NAME), None)
    digest = (asset or {}).get("digest")
    if not asset or digest != f"sha256:{EXPECTED_SHA256}":
        raise SystemExit("Pinned Android runtime asset digest differs from the reviewed SHA-256; refusing download.")

    CPP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bliss-node24-") as temporary:
        archive_path = Path(temporary) / ASSET_NAME
        download(asset["browser_download_url"], archive_path)
        actual = hashlib.sha256(archive_path.read_bytes()).hexdigest()
        if actual.lower() != EXPECTED_SHA256:
            raise SystemExit("Node mobile runtime checksum mismatch.")

        with zipfile.ZipFile(archive_path) as archive:
            names = archive.namelist()
            header = next((name for name in names if name.endswith("include/node/node.h")), None)
            if not header:
                raise SystemExit("The Android runtime archive does not contain Node.js headers.")
            include_prefix = header[: -len("node.h")]
            abi_entries = {
                abi: next((name for name in names if name.endswith(f"bin/{abi}/libnode.so")), None)
                for abi in ABIS
            }
            missing_abis = [abi for abi, name in abi_entries.items() if not name]
            if missing_abis:
                raise SystemExit(f"Node runtime archive is missing ABI(s): {', '.join(missing_abis)}.")
            for name in names:
                path = PurePosixPath(name)
                if path.is_absolute() or ".." in path.parts:
                    raise SystemExit("Unsafe path in Node runtime archive.")
                if name.startswith(include_prefix) and not name.endswith("/"):
                    relative = Path("include/node") / Path(*path.parts[len(PurePosixPath(include_prefix).parts):])
                    output = CPP_ROOT / relative
                    output.parent.mkdir(parents=True, exist_ok=True)
                    output.write_bytes(archive.read(name))
            for abi in ABIS:
                binary = abi_entries[abi]
                assert binary is not None
                destination = JNI_ROOT / abi / "libnode.so"
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(binary))
                subprocess.run([strip_tool, "--strip-unneeded", str(destination)], check=True)

    version_file = CPP_ROOT / "VERSION"
    version_file.write_text(expected_version, encoding="utf-8")
    print(f"Prepared Node mobile {VERSION_TAG} (sha256:{EXPECTED_SHA256}) for {', '.join(ABIS)}")


if __name__ == "__main__":
    main()
