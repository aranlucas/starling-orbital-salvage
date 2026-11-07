"""Run both headless integration suites, failing on Godot script errors too.

Used by GitHub Actions PR validation and release validation.
"""

import os
from pathlib import Path
import re
import shutil
import subprocess


def check(project: Path) -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("Godot") or shutil.which("godot")
    if not godot:
        raise SystemExit("Set GODOT_BIN or put Godot on PATH.")
    for arguments in [
        ["--editor", "--quit"],
        ["--script", "tests/profile_reliability_test.gd"],
        ["--script", "tests/smoke_test.gd"],
        ["--script", "tests/flight3d_test.gd"],
    ]:
        command = [godot, "--headless", "--path", str(project), *arguments]
        print("Running: " + " ".join(command), flush=True)
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180)
        print(result.stdout, flush=True)
        if result.returncode or re.search(r"(?:SCRIPT ERROR:|^ERROR:)", result.stdout, re.MULTILINE):
            raise SystemExit("Gameplay validation failed.")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    check(parser.parse_args().project.resolve())
