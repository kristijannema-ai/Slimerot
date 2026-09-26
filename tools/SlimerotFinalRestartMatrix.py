"""Run the eight desktop process-death analogs; never uses a player save.

Example: python tools/SlimerotFinalRestartMatrix.py --godot /path/to/godot
Android force-stop/lifecycle validation remains a separate device requirement.
"""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = (args.output or repo / ".godot" / "Slimerot-final-restart-results").resolve()
    output.mkdir(parents=True, exist_ok=True)
    executable = args.godot.resolve()
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    results = []
    for case in range(1, 9):
        result = {"case": case, "platform": "desktop process-death analog", "android": "NOT RUN", "stages": []}
        modes = ["write", "resume", "verify"] if case == 2 else ["write", "verify"]
        for mode in modes:
            console = output / f"case-{case}-{mode}-console.log"
            command = [str(executable), "--headless", "--path", str(repo), "--log-file",
                       str(output / f"case-{case}-{mode}-engine.log"),
                       "res://tests/SlimerotFinalRestartProbe.tscn", "--", "--slimerot-test",
                       f"--case={case}", f"--mode={mode}"]
            with console.open("w", encoding="utf-8") as stream:
                process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, creationflags=flags)
                try:
                    deadline = time.monotonic() + 45
                    while True:
                        text = console.read_text(encoding="utf-8", errors="replace")
                        if "SCRIPT ERROR" in text or "FINAL RESTART FAIL" in text:
                            raise RuntimeError(f"Case {case}/{mode}: {text}")
                        ready = f"FINAL RESTART READY case={case} mode={mode}" in text
                        if ready and mode != "verify":
                            # Windows Popen.kill uses TerminateProcess. No graceful exit callback runs.
                            process.kill()
                            process.wait(timeout=5)
                            match = re.search(r"READY.*checks=(\d+)", text)
                            result["stages"].append({"mode": mode, "externally_killed": True, "checks": int(match[1])})
                            break
                        if process.poll() is not None:
                            match = re.search(r"RESULT: case=(\d+) checks=(\d+) failures=(\d+)", text)
                            if mode != "verify" or process.returncode != 0 or not match or int(match[3]) != 0:
                                raise RuntimeError(f"Case {case}/{mode} exited {process.returncode}: {text}")
                            result["stages"].append({"mode": mode, "externally_killed": False, "checks": int(match[2])})
                            break
                        if time.monotonic() > deadline:
                            raise TimeoutError(f"Case {case}/{mode} did not complete: {text}")
                        time.sleep(0.05)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)
        result["status"] = "PASS"
        result["checks"] = sum(stage["checks"] for stage in result["stages"])
        results.append(result)
        print(f"Case {case}: PASS ({result['checks']} checks; Android NOT RUN)", flush=True)
    report = {"platform": os.name, "cases": results, "checks": sum(case["checks"] for case in results), "status": "PASS"}
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"FINAL RESTART MATRIX: 8 cases; {report['checks']} checks; 0 failures", flush=True)


if __name__ == "__main__":
    main()
