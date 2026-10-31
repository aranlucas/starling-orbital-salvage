"""Install the official macOS editor and matching export template for CI."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile


def install(version: str, destination: Path, cache: Path) -> Path:
    if sys.platform != "darwin":
        raise SystemExit("The macOS release installer requires macOS.")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise SystemExit("Expected a stable Godot version such as 4.7.2.")
    cache.mkdir(parents=True, exist_ok=True)
    destination.mkdir(parents=True, exist_ok=True)
    base = f"https://github.com/godotengine/godot/releases/download/{version}-stable"
    names = [
        f"Godot_v{version}-stable_macos.universal.zip",
        f"Godot_v{version}-stable_export_templates.tpz",
    ]
    sums = cache / "SHA512-SUMS.txt"
    subprocess.run(["curl", "-fsSL", "--retry", "3", f"{base}/SHA512-SUMS.txt", "-o", str(sums)], check=True)
    expected = {}
    for line in sums.read_text().splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            expected[parts[1].lstrip("*")] = parts[0]
    for name in names:
        path = cache / name
        if not path.exists():
            subprocess.run(["curl", "-fL", "--retry", "3", f"{base}/{name}", "-o", str(path)], check=True)
        digest = hashlib.sha512()
        with path.open("rb") as source:
            for block in iter(lambda: source.read(4 * 1024 * 1024), b""):
                digest.update(block)
        if name not in expected or digest.hexdigest() != expected[name]:
            raise SystemExit(f"Official SHA-512 checksum failed for {name}; remove the cached archive before retrying.")
        print(f"Verified official checksum: {name}", flush=True)
    # ditto preserves executable bits and app bundle metadata.
    subprocess.run(["ditto", "-xk", str(cache / names[0]), str(destination)], check=True)
    templates = Path.home() / "Library/Application Support/Godot/export_templates" / f"{version}.stable"
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(cache / names[1]) as archive:
        (templates / "macos.zip").write_bytes(archive.read("templates/macos.zip"))
    binary = destination / "Godot.app/Contents/MacOS/Godot"
    subprocess.run([str(binary), "--version"], check=True)
    if "GITHUB_PATH" in os.environ:
        with open(os.environ["GITHUB_PATH"], "a") as output:
            output.write(f"{binary.parent}\n")
    print(f"Godot installed at {binary}", flush=True)
    return binary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    args = parser.parse_args()
    install(args.version, args.destination.resolve(), args.cache.resolve())
