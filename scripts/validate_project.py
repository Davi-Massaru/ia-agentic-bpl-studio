"""Read-only local validation. Exit 0 only for local checks, never contest acceptance.

Run: python scripts/validate_project.py --output validation/local.json
The report explicitly separates local checks from unverified native execution.
"""
import argparse
from datetime import datetime, timezone
import json
import re
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "iris-community:2026.3.0AI.154.0"
CONTEST = "https://community.intersystems.com/post/intersystems-programming-contest-ai-agents-interoperability-workflows"


def command_check(name, command, *, cwd=ROOT, timeout=120, expected_stdout=None):
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=timeout,
                                shell=False)
        passed = result.returncode == 0 and (expected_stdout is None or
                   re.fullmatch(expected_stdout, result.stdout.strip()) is not None)
        return {"name": name, "status": "PASS" if passed else "FAIL",
                "exitCode": result.returncode,
                "output": (result.stdout + result.stderr)[-6000:]}
    except FileNotFoundError:
        return {"name": name, "status": "BLOCKED", "error": "COMMAND_NOT_FOUND"}
    except subprocess.TimeoutExpired:
        return {"name": name, "status": "BLOCKED", "error": "COMMAND_TIMEOUT"}
    except OSError:
        return {"name": name, "status": "BLOCKED", "error": "COMMAND_UNAVAILABLE"}


def build_report(checks):
    return {
        "schemaVersion": 1,
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "contestSource": CONTEST,
        "localStatus": "PASS" if all(c["status"] == "PASS" for c in checks) else "FAIL",
        "contestStatus": "NOT_VALIDATED",
        "checks": checks,
        "nativeAcceptance": {
            "status": "NOT_RUN",
            "required": ["Confirm runtime build 2026.3.0AI.154.0, not just an image tag",
                         "Compile Studio classes in an authorized namespace",
                         "Send messages through a Business Service and native BPL",
                         "Observe native AI Hub agent and authorized READ ToolSet calls",
                         "Trace two different decisions and deterministic failure fallback",
                         "Compile/publish managed workflow and preserve immutable revisions"],
        },
        "submissionAcceptance": {
            "status": "NOT_VERIFIED",
            "required": ["Public GitHub/GitLab repository and open-source license",
                         "English installation and working demo description/video",
                         "Open Exchange entry and participant/team information"],
        },
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "validation/local.json")
    args = parser.parse_args(argv)
    checks = [
        command_check("python-tests", [sys.executable, "-m", "pytest", "-q"]),
        command_check("compose-config", ["docker", "compose", "-f",
                                         "deploy/docker-compose.yaml", "config", "--quiet"], timeout=30),
        command_check("docker-engine", ["docker", "info", "--format", "{{.ServerVersion}}"], timeout=30,
                      expected_stdout=r"\d+\.\d+\.\d+[\w.+-]*"),
        command_check("local-build154-image", ["docker", "image", "inspect", IMAGE,
                                              "--format", "{{.Id}}"], timeout=30,
                      expected_stdout=r"sha256:[a-f0-9]{64}"),
    ]
    report = build_report(checks)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for check in checks:
        print(f"{check['status']:7} {check['name']}")
    print("NOT_VALIDATED contest acceptance: native execution evidence required")
    print(f"Report: {args.output}")
    return 0 if report["localStatus"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
