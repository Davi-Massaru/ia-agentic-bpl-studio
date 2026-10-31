import importlib.util
from pathlib import Path
import subprocess
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("validate_project", Path(__file__).resolve().parents[1] / "scripts/validate_project.py")
validation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validation)


def test_local_success_never_claims_native_or_contest_acceptance():
    report = validation.build_report([{"name": "local", "status": "PASS"}])
    assert report["localStatus"] == "PASS"
    assert report["contestStatus"] == "NOT_VALIDATED"
    assert report["nativeAcceptance"]["status"] == "NOT_RUN"


def test_failure_and_blocked_checks_fail_local_report():
    for status in ("FAIL", "BLOCKED"):
        assert validation.build_report([{"status": status}])["localStatus"] == "FAIL"


def test_command_timeout_and_missing_tool_are_explicit():
    for error, expected in [(FileNotFoundError(), "COMMAND_NOT_FOUND"),
                            (subprocess.TimeoutExpired("docker", 1), "COMMAND_TIMEOUT")]:
        with patch.object(validation.subprocess, "run", side_effect=error):
            result = validation.command_check("docker", ["docker"])
            assert result["status"] == "BLOCKED"
            assert result["error"] == expected


def test_command_failure_captures_bounded_diagnostic_and_exit_code():
    result = subprocess.CompletedProcess(["docker"], 1, "", "error" * 3000)
    with patch.object(validation.subprocess, "run", return_value=result) as run:
        check = validation.command_check("docker", ["docker"])
        assert check["status"] == "FAIL"
        assert check["exitCode"] == 1
        assert len(check["output"]) == 6000
        assert run.call_args.kwargs["shell"] is False


def test_docker_zero_exit_with_error_output_is_not_success():
    result = subprocess.CompletedProcess(["docker"], 0, "", "Internal Server Error")
    with patch.object(validation.subprocess, "run", return_value=result):
        check = validation.command_check("docker", ["docker"], expected_stdout=r"\d+\.\d+\.\d+")
        assert check["status"] == "FAIL"
