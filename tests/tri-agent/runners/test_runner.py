#!/usr/bin/env python3
"""
Tri-Agent Daemon Test Runner

A robust test runner for tri-agent daemon validation with:
- YAML test case parsing
- Automatic retry with exponential backoff
- Parallel test execution
- Comprehensive reporting
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml")
    sys.exit(1)


class TestStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    PASS = "pass"
    FAIL = "fail"
    SKIP = "skip"
    ERROR = "error"
    TIMEOUT = "timeout"


@dataclass
class TestResult:
    """Result of a single test execution."""
    test_id: str
    name: str
    category: str
    priority: str
    status: TestStatus
    duration_ms: int = 0
    attempts: int = 1
    error_message: str = ""
    assertion_details: Dict[str, Any] = field(default_factory=dict)
    stdout: str = ""
    stderr: str = ""


@dataclass
class TestCase:
    """Parsed test case from YAML."""
    id: str
    name: str
    description: str
    category: str
    priority: str
    tags: List[str]
    setup: Dict[str, Any]
    input: Dict[str, Any]
    expected: Dict[str, Any]
    teardown: Dict[str, Any]
    retry: Dict[str, Any]
    timeout: Dict[str, Any]
    dependencies: List[str]
    skip: Dict[str, Any]
    file_path: Path


class TestRunner:
    """Main test runner class."""

    def __init__(self, config_path: Path, verbose: bool = False):
        self.config_path = config_path
        self.verbose = verbose
        self.test_root = config_path.parent
        self.config = self._load_config()
        self.results: List[TestResult] = []
        self.run_id = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Create directories
        self.results_dir = self.test_root / "results"
        self.logs_dir = self.test_root / "logs"
        self.results_dir.mkdir(exist_ok=True)
        self.logs_dir.mkdir(exist_ok=True)

    def _load_config(self) -> Dict[str, Any]:
        """Load test framework configuration."""
        with open(self.config_path) as f:
            return yaml.safe_load(f)

    def discover_tests(self,
                       category: Optional[str] = None,
                       priority: Optional[str] = None,
                       tags: Optional[List[str]] = None) -> List[TestCase]:
        """Discover and filter test cases."""
        cases_dir = self.test_root / "cases"
        test_cases = []

        for yaml_file in sorted(cases_dir.rglob("TAT-*.yaml")):
            try:
                test_case = self._parse_test_case(yaml_file)

                # Apply filters
                if category and test_case.category != category:
                    continue
                if priority and test_case.priority != priority:
                    continue
                if tags and not any(t in test_case.tags for t in tags):
                    continue

                test_cases.append(test_case)
            except Exception as e:
                self._log(f"Error parsing {yaml_file}: {e}", "ERROR")

        return test_cases

    def _parse_test_case(self, file_path: Path) -> TestCase:
        """Parse YAML test case file."""
        with open(file_path) as f:
            data = yaml.safe_load(f)

        return TestCase(
            id=data["id"],
            name=data["name"],
            description=data.get("description", ""),
            category=data["category"],
            priority=data.get("priority", "medium"),
            tags=data.get("tags", []),
            setup=data.get("setup", {}),
            input=data["input"],
            expected=data["expected"],
            teardown=data.get("teardown", {}),
            retry=data.get("retry", {"max_attempts": 3}),
            timeout=data.get("timeout", {"execution": 300}),
            dependencies=data.get("dependencies", []),
            skip=data.get("skip", {"enabled": False}),
            file_path=file_path
        )

    def run_tests(self,
                  test_cases: List[TestCase],
                  parallel: bool = False,
                  fail_fast: bool = False) -> List[TestResult]:
        """Run all discovered test cases."""
        self._log(f"Running {len(test_cases)} tests", "INFO")

        if parallel:
            return self._run_parallel(test_cases, fail_fast)
        else:
            return self._run_sequential(test_cases, fail_fast)

    def _run_sequential(self, test_cases: List[TestCase], fail_fast: bool) -> List[TestResult]:
        """Run tests sequentially."""
        for test_case in test_cases:
            if test_case.skip.get("enabled", False):
                self.results.append(TestResult(
                    test_id=test_case.id,
                    name=test_case.name,
                    category=test_case.category,
                    priority=test_case.priority,
                    status=TestStatus.SKIP,
                    error_message=test_case.skip.get("reason", "Skipped")
                ))
                continue

            result = self._run_single_test(test_case)
            self.results.append(result)

            if fail_fast and result.status == TestStatus.FAIL:
                self._log("Fail-fast triggered", "ERROR")
                break

        return self.results

    def _run_parallel(self, test_cases: List[TestCase], fail_fast: bool) -> List[TestResult]:
        """Run tests in parallel."""
        max_workers = self.config.get("execution", {}).get("parallel", {}).get("max_workers", 4)

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(self._run_single_test, tc): tc
                for tc in test_cases
                if not tc.skip.get("enabled", False)
            }

            for future in as_completed(futures):
                result = future.result()
                self.results.append(result)

                if fail_fast and result.status == TestStatus.FAIL:
                    self._log("Fail-fast triggered", "ERROR")
                    break

        return self.results

    def _run_single_test(self, test_case: TestCase) -> TestResult:
        """Run a single test with retry logic."""
        max_attempts = test_case.retry.get("max_attempts", 3)
        backoff_config = test_case.retry.get("backoff", {})
        backoff_type = backoff_config.get("type", "exponential")
        base_seconds = backoff_config.get("base_seconds", 2)
        max_seconds = backoff_config.get("max_seconds", 60)

        self._log(f"Running: {test_case.id} - {test_case.name}", "INFO")

        last_error = ""
        start_time = time.time()

        for attempt in range(1, max_attempts + 1):
            self._log(f"Attempt {attempt}/{max_attempts}", "INFO")

            try:
                # Setup
                if not self._run_setup(test_case):
                    raise Exception("Setup failed")

                # Execute
                stdout, stderr, exit_code = self._run_execution(test_case)

                # Validate
                assertion_result = self._validate_results(test_case, stdout, stderr, exit_code)

                if assertion_result["passed"]:
                    duration_ms = int((time.time() - start_time) * 1000)
                    return TestResult(
                        test_id=test_case.id,
                        name=test_case.name,
                        category=test_case.category,
                        priority=test_case.priority,
                        status=TestStatus.PASS,
                        duration_ms=duration_ms,
                        attempts=attempt,
                        stdout=stdout,
                        stderr=stderr
                    )
                else:
                    last_error = assertion_result.get("message", "Validation failed")

            except Exception as e:
                last_error = str(e)
                self._log(f"Error: {e}", "WARN")

            finally:
                self._run_teardown(test_case)

            # Calculate backoff
            if attempt < max_attempts:
                if backoff_type == "fixed":
                    wait_time = base_seconds
                elif backoff_type == "linear":
                    wait_time = base_seconds * attempt
                else:  # exponential
                    wait_time = min(base_seconds ** attempt, max_seconds)

                self._log(f"Waiting {wait_time}s before retry...", "INFO")
                time.sleep(wait_time)

        # All attempts failed
        duration_ms = int((time.time() - start_time) * 1000)
        return TestResult(
            test_id=test_case.id,
            name=test_case.name,
            category=test_case.category,
            priority=test_case.priority,
            status=TestStatus.FAIL,
            duration_ms=duration_ms,
            attempts=max_attempts,
            error_message=last_error
        )

    def _run_setup(self, test_case: TestCase) -> bool:
        """Run test setup phase."""
        setup = test_case.setup

        # Set environment variables
        for key, value in setup.get("environment", {}).items():
            os.environ[key] = self._expand_vars(value)

        # Run setup commands
        for cmd in setup.get("commands", []):
            try:
                subprocess.run(
                    cmd,
                    shell=True,
                    check=True,
                    capture_output=True,
                    timeout=test_case.timeout.get("setup", 30)
                )
            except subprocess.CalledProcessError as e:
                self._log(f"Setup command failed: {cmd}", "ERROR")
                return False

        return True

    def _run_execution(self, test_case: TestCase) -> tuple:
        """Run test execution phase."""
        input_spec = test_case.input
        input_type = input_spec.get("type", "command")
        timeout = test_case.timeout.get("execution", 300)

        if input_type == "command":
            cmd = input_spec.get("command", {})
            cmd_name = cmd.get("name", "")
            cmd_args = cmd.get("args", [])

            full_cmd = f"{cmd_name} {' '.join(cmd_args)}"

            try:
                result = subprocess.run(
                    full_cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                    env=os.environ.copy()
                )
                return result.stdout, result.stderr, result.returncode
            except subprocess.TimeoutExpired:
                return "", "Timeout exceeded", 124

        # TODO: Implement other input types (event, api, task)
        return "", "", 0

    def _validate_results(self, test_case: TestCase, stdout: str, stderr: str, exit_code: int) -> Dict[str, Any]:
        """Validate test results against expected values."""
        expected = test_case.expected

        # Check exit code
        expected_exit_code = expected.get("exit_code", 0)
        if exit_code != expected_exit_code:
            return {
                "passed": False,
                "message": f"Exit code mismatch: expected {expected_exit_code}, got {exit_code}"
            }

        # Check stdout contains
        stdout_spec = expected.get("stdout", {})
        if "contains" in stdout_spec:
            for pattern in stdout_spec["contains"]:
                if pattern not in stdout:
                    return {
                        "passed": False,
                        "message": f"Expected output not found: {pattern}"
                    }

        # Check stdout not_contains
        if "not_contains" in stdout_spec:
            for pattern in stdout_spec["not_contains"]:
                if pattern in stdout:
                    return {
                        "passed": False,
                        "message": f"Forbidden output found: {pattern}"
                    }

        # Check stdout regex
        if "regex" in stdout_spec:
            if not re.search(stdout_spec["regex"], stdout):
                return {
                    "passed": False,
                    "message": f"Regex pattern not matched: {stdout_spec['regex']}"
                }

        # Check stderr
        stderr_spec = expected.get("stderr", {})
        if stderr_spec.get("empty", False) and stderr.strip():
            return {
                "passed": False,
                "message": f"Expected empty stderr, got: {stderr[:100]}"
            }

        return {"passed": True}

    def _run_teardown(self, test_case: TestCase) -> None:
        """Run test teardown phase."""
        teardown = test_case.teardown

        # Run teardown commands
        for cmd in teardown.get("commands", []):
            try:
                subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    timeout=test_case.timeout.get("teardown", 30)
                )
            except Exception:
                pass  # Don't fail on teardown errors

        # Cleanup files
        for path in teardown.get("cleanup_files", []):
            expanded_path = self._expand_vars(path)
            try:
                if os.path.isfile(expanded_path):
                    os.remove(expanded_path)
                elif os.path.isdir(expanded_path):
                    shutil.rmtree(expanded_path)
            except Exception:
                pass

    def _expand_vars(self, value: str) -> str:
        """Expand environment variables in string."""
        if isinstance(value, str):
            return os.path.expandvars(value)
        return value

    def _log(self, message: str, level: str = "INFO") -> None:
        """Log message with level."""
        timestamp = datetime.now().isoformat()
        log_line = f"[{timestamp}] [{level}] {message}"

        # Write to log file
        log_file = self.logs_dir / f"test-run-{self.run_id}.log"
        with open(log_file, "a") as f:
            f.write(log_line + "\n")

        # Print to console
        if self.verbose or level in ("ERROR", "WARN"):
            colors = {
                "INFO": "\033[34m",
                "PASS": "\033[32m",
                "FAIL": "\033[31m",
                "WARN": "\033[33m",
                "ERROR": "\033[31m"
            }
            reset = "\033[0m"
            color = colors.get(level, "")
            print(f"{color}[{level}]{reset} {message}")

    def generate_report(self) -> Path:
        """Generate test run report."""
        total = len(self.results)
        passed = sum(1 for r in self.results if r.status == TestStatus.PASS)
        failed = sum(1 for r in self.results if r.status == TestStatus.FAIL)
        skipped = sum(1 for r in self.results if r.status == TestStatus.SKIP)

        report = {
            "run_id": self.run_id,
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "total": total,
                "passed": passed,
                "failed": failed,
                "skipped": skipped,
                "pass_rate": (passed / total * 100) if total > 0 else 0
            },
            "results": [
                {
                    "test_id": r.test_id,
                    "name": r.name,
                    "category": r.category,
                    "priority": r.priority,
                    "status": r.status.value,
                    "duration_ms": r.duration_ms,
                    "attempts": r.attempts,
                    "error_message": r.error_message
                }
                for r in self.results
            ]
        }

        report_file = self.results_dir / f"report-{self.run_id}.json"
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)

        return report_file

    def print_summary(self) -> None:
        """Print test run summary."""
        total = len(self.results)
        passed = sum(1 for r in self.results if r.status == TestStatus.PASS)
        failed = sum(1 for r in self.results if r.status == TestStatus.FAIL)
        skipped = sum(1 for r in self.results if r.status == TestStatus.SKIP)

        print("\n" + "=" * 50)
        print("           TEST RUN SUMMARY")
        print("=" * 50)
        print(f"Total:   {total}")
        print(f"Passed:  \033[32m{passed}\033[0m")
        print(f"Failed:  \033[31m{failed}\033[0m")
        print(f"Skipped: \033[33m{skipped}\033[0m")
        print()

        if failed == 0:
            print("\033[32mAll tests passed!\033[0m")
        else:
            print("\033[31mSome tests failed.\033[0m")
            print("\nFailed tests:")
            for r in self.results:
                if r.status == TestStatus.FAIL:
                    print(f"  - {r.test_id}: {r.error_message}")

        print("=" * 50)


def main():
    parser = argparse.ArgumentParser(description="Tri-Agent Daemon Test Runner")
    parser.add_argument("--config", default="config.yaml", help="Config file path")
    parser.add_argument("--category", help="Filter by category")
    parser.add_argument("--priority", help="Filter by priority")
    parser.add_argument("--tags", help="Filter by tags (comma-separated)")
    parser.add_argument("--parallel", action="store_true", help="Run tests in parallel")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first failure")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    args = parser.parse_args()

    # Find config file
    config_path = Path(args.config)
    if not config_path.is_absolute():
        # Look in script directory or current directory
        script_dir = Path(__file__).parent.parent
        config_path = script_dir / args.config
        if not config_path.exists():
            config_path = Path.cwd() / args.config

    if not config_path.exists():
        print(f"Config file not found: {config_path}")
        sys.exit(1)

    # Create runner
    runner = TestRunner(config_path, verbose=args.verbose)

    # Discover tests
    tags = args.tags.split(",") if args.tags else None
    test_cases = runner.discover_tests(
        category=args.category,
        priority=args.priority,
        tags=tags
    )

    if not test_cases:
        print("No test cases found")
        sys.exit(0)

    # Run tests
    runner.run_tests(
        test_cases,
        parallel=args.parallel,
        fail_fast=args.fail_fast
    )

    # Generate report and summary
    report_file = runner.generate_report()
    runner.print_summary()

    print(f"\nReport: {report_file}")

    # Exit with appropriate code
    failed = sum(1 for r in runner.results if r.status == TestStatus.FAIL)
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
