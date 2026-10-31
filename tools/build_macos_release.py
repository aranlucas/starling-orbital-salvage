"""Build and verify a standalone macOS release without modifying the checkout.

GODOT_BIN=/path/to/Godot python3 tools/build_macos_release.py v0.1.0
"""

import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


def run(command: list[str], *, cwd: Path | None = None, log: Path | None = None) -> str:
    print("+ " + shlex.join(command), flush=True)
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
    print(result.stdout, end="", flush=True)
    if log:
        log.write_text(result.stdout)
    if result.returncode or re.search(r"(?:SCRIPT ERROR:|^ERROR:)", result.stdout, re.MULTILINE):
        raise SystemExit(f"Build verification failed: {command[0]} (exit {result.returncode})")
    return result.stdout


def build(tag: str, output: Path) -> Path:
    match = re.fullmatch(r"v(\d+\.\d+\.\d+)(?:-[0-9A-Za-z.-]+)?", tag)
    if not match:
        raise SystemExit("Release tag must look like v0.1.0 or v0.1.0-beta.1.")
    if sys.platform != "darwin":
        raise SystemExit("Building and verifying the macOS app requires macOS.")
    godot = os.environ.get("GODOT_BIN") or shutil.which("Godot") or shutil.which("godot")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot editor binary or put Godot on PATH.")
    godot = str(Path(godot).resolve())
    root = Path(__file__).resolve().parents[1]
    output.mkdir(parents=True, exist_ok=True)
    version = tag[1:]
    bundle_version = match.group(1)
    artifact = output / f"Starling-{tag}-macOS-universal.zip"
    if artifact.exists():
        raise SystemExit(f"Refusing to overwrite {artifact}; use a clean output directory.")
    with tempfile.TemporaryDirectory(prefix="starling-release-") as temporary:
        staging = Path(temporary)
        project = staging / "project"
        project.mkdir()
        for directory in ["scenes", "scripts", "assets"]:
            shutil.copytree(root / directory, project / directory, ignore=shutil.ignore_patterns("*.blend1", "*.blend2"))
        for name in ["project.godot", "export_presets.cfg"]:
            shutil.copy2(root / name, project / name)
        settings = project / "project.godot"
        settings.write_text(re.sub(r'^config/version=.*$', f'config/version="{version}"', settings.read_text(), flags=re.MULTILINE))
        preset = project / "export_presets.cfg"
        preset.write_text(re.sub(r'^(application/(?:short_version|version))=.*$', rf'\1="{bundle_version}"', preset.read_text(), flags=re.MULTILINE))
        run([godot, "--headless", "--path", str(project), "--editor", "--quit"], log=output / "import.log")
        app = staging / "Starling.app"
        run([godot, "--headless", "--path", str(project), "--export-release", "macOS", str(app)], log=output / "export.log")
        with (app / "Contents/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        if info["CFBundleShortVersionString"] != bundle_version or info["CFBundleIdentifier"] != "com.aranlucas.starling":
            raise SystemExit("Exported app metadata does not match this release.")
        binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
        architectures = run(["lipo", "-archs", str(binary)]).split()
        if set(architectures) != {"x86_64", "arm64"}:
            raise SystemExit(f"Expected a universal Apple Silicon / Intel app, got {architectures}.")
        run(["codesign", "--verify", "--deep", "--strict", str(app)])
        archive = staging / artifact.name
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)])
        # Verify the actual downloadable ZIP, outside the source project.
        unpacked = staging / "unpacked"
        run(["ditto", "-xk", str(archive), str(unpacked)])
        installed_app = unpacked / "Starling.app"
        run(["codesign", "--verify", "--deep", "--strict", str(installed_app)])
        installed_binary = installed_app / "Contents/MacOS" / info["CFBundleExecutable"]
        run([str(installed_binary), "--headless", "--quit-after", "10"], cwd=unpacked, log=output / "standalone-smoke.log")
        shutil.move(str(archive), artifact)
    checksum = hashlib.sha256(artifact.read_bytes()).hexdigest()
    (output / "SHA256SUMS.txt").write_text(f"{checksum}  {artifact.name}\n")
    print(f"Verified release: {artifact} ({artifact.stat().st_size:,} bytes)", flush=True)
    return artifact


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--output", type=Path, default=Path("builds/release"))
    args = parser.parse_args()
    build(args.tag, args.output.resolve())
