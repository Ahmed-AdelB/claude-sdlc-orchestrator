#!/usr/bin/env python3
"""
Tri-Agent Consensus Verifier

Validates 2/3 approval workflow per CLAUDE.md requirements:
- Minimum 2 out of 3 AI models must approve
- Different models for implementation vs verification
- Consensus tracking and logging

Author: Ahmed Adel Bakr Alderai
Version: 1.0.0
"""

import argparse
import json
import logging
import sqlite3
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional, List, Dict, Any
import uuid

# =============================================================================
# Configuration
# =============================================================================

STATE_DIR = Path.home() / ".claude" / "state"
DB_FILE = STATE_DIR / "consensus.db"
LOG_DIR = Path.home() / ".claude" / "logs"
REPORT_DIR = Path.home() / ".claude" / "reports" / "consensus"

MIN_APPROVALS = 2
TOTAL_AGENTS = 3
DEFAULT_TIMEOUT = 120

# =============================================================================
# Enums
# =============================================================================


class Agent(str, Enum):
    CLAUDE = "claude"
    CODEX = "codex"
    GEMINI = "gemini"


class Vote(str, Enum):
    APPROVE = "APPROVE"
    REJECT = "REJECT"
    ABSTAIN = "ABSTAIN"
    TIMEOUT = "TIMEOUT"
    ERROR = "ERROR"


class ConsensusResult(str, Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    INCONCLUSIVE = "INCONCLUSIVE"
    PENDING = "PENDING"


# =============================================================================
# Data Classes
# =============================================================================


@dataclass
class ConsensusSession:
    id: str
    task_id: str
    description: str
    implementer: Agent
    scope: str
    created_at: datetime
    completed_at: Optional[datetime] = None
    final_result: ConsensusResult = ConsensusResult.PENDING
    approvals: int = 0
    rejections: int = 0


@dataclass
class ConsensusVote:
    session_id: str
    agent: Agent
    vote: Vote
    reason: str
    evidence: str
    duration_ms: int
    created_at: datetime


@dataclass
class VerificationRequest:
    """Standard VERIFY block format from CLAUDE.md"""

    scope: str
    change_summary: str
    expected_behavior: str
    repro_steps: str
    evidence_to_check: str
    risk_notes: str

    def to_prompt(self) -> str:
        return f"""VERIFY:
- Scope: {self.scope}
- Change summary: {self.change_summary}
- Expected behavior: {self.expected_behavior}
- Repro steps: {self.repro_steps}
- Evidence to check: {self.evidence_to_check}
- Risk notes: {self.risk_notes}

Review the above and respond with:
- APPROVE if all criteria are met
- REJECT if any issues found (list all issues)
- ABSTAIN if unable to verify

Include your reasoning and any evidence checked."""


# =============================================================================
# Logging Setup
# =============================================================================


def setup_logging(debug: bool = False) -> logging.Logger:
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    level = logging.DEBUG if debug else logging.INFO

    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(LOG_DIR / "consensus-verifier.log"),
        ],
    )

    return logging.getLogger(__name__)


logger = setup_logging()


# =============================================================================
# Database Manager
# =============================================================================


class DatabaseManager:
    def __init__(self, db_path: Path = DB_FILE):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self):
        with self._get_connection() as conn:
            conn.executescript(
                """
                -- Consensus sessions table
                CREATE TABLE IF NOT EXISTS consensus_sessions (
                    id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL,
                    description TEXT,
                    implementer TEXT NOT NULL,
                    scope TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    completed_at DATETIME,
                    final_result TEXT CHECK(final_result IN ('PASS', 'FAIL', 'INCONCLUSIVE', 'PENDING')),
                    approvals INTEGER DEFAULT 0,
                    rejections INTEGER DEFAULT 0
                );

                -- Individual votes table
                CREATE TABLE IF NOT EXISTS consensus_votes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    agent TEXT NOT NULL CHECK(agent IN ('claude', 'codex', 'gemini')),
                    vote TEXT NOT NULL CHECK(vote IN ('APPROVE', 'REJECT', 'ABSTAIN', 'TIMEOUT', 'ERROR')),
                    reason TEXT,
                    evidence TEXT,
                    duration_ms INTEGER,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES consensus_sessions(id),
                    UNIQUE(session_id, agent)
                );

                -- Verification history for audit trail
                CREATE TABLE IF NOT EXISTS verification_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    action TEXT NOT NULL,
                    details TEXT,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES consensus_sessions(id)
                );

                -- Create indexes
                CREATE INDEX IF NOT EXISTS idx_sessions_task ON consensus_sessions(task_id);
                CREATE INDEX IF NOT EXISTS idx_sessions_result ON consensus_sessions(final_result);
                CREATE INDEX IF NOT EXISTS idx_votes_session ON consensus_votes(session_id);
            """
            )

    def create_session(
        self, task_id: str, description: str, implementer: Agent, scope: str = ""
    ) -> str:
        session_id = f"CS-{datetime.now().strftime('%Y%m%d%H%M%S')}-{task_id}-{uuid.uuid4().hex[:8]}"

        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO consensus_sessions (id, task_id, description, implementer, scope, final_result)
                VALUES (?, ?, ?, ?, ?, 'PENDING')
            """,
                (session_id, task_id, description, implementer.value, scope),
            )

            self._log_audit(
                conn,
                session_id,
                "SESSION_CREATED",
                f"Task: {task_id}, Implementer: {implementer.value}",
            )

        logger.info(f"Created session: {session_id}")
        return session_id

    def record_vote(
        self,
        session_id: str,
        agent: Agent,
        vote: Vote,
        reason: str = "",
        evidence: str = "",
        duration_ms: int = 0,
    ):
        with self._get_connection() as conn:
            # Check if agent is not the implementer
            row = conn.execute(
                "SELECT implementer FROM consensus_sessions WHERE id = ?", (session_id,)
            ).fetchone()

            if row and row["implementer"] == agent.value:
                raise ValueError(
                    f"Agent '{agent.value}' cannot vote on their own implementation"
                )

            # Upsert vote
            conn.execute(
                """
                INSERT OR REPLACE INTO consensus_votes
                (session_id, agent, vote, reason, evidence, duration_ms)
                VALUES (?, ?, ?, ?, ?, ?)
            """,
                (session_id, agent.value, vote.value, reason, evidence, duration_ms),
            )

            self._log_audit(
                conn,
                session_id,
                "VOTE_RECORDED",
                f"Agent: {agent.value}, Vote: {vote.value}",
            )

            # Update counts
            self._update_counts(conn, session_id)

    def _update_counts(self, conn: sqlite3.Connection, session_id: str):
        conn.execute(
            """
            UPDATE consensus_sessions SET
                approvals = (SELECT COUNT(*) FROM consensus_votes
                            WHERE session_id = ? AND vote = 'APPROVE'),
                rejections = (SELECT COUNT(*) FROM consensus_votes
                             WHERE session_id = ? AND vote = 'REJECT')
            WHERE id = ?
        """,
            (session_id, session_id, session_id),
        )

    def evaluate_consensus(self, session_id: str) -> ConsensusResult:
        with self._get_connection() as conn:
            votes = conn.execute(
                """
                SELECT vote, COUNT(*) as count FROM consensus_votes
                WHERE session_id = ?
                GROUP BY vote
            """,
                (session_id,),
            ).fetchall()

            vote_counts = {row["vote"]: row["count"] for row in votes}

            approvals = vote_counts.get("APPROVE", 0)
            rejections = vote_counts.get("REJECT", 0)
            errors = vote_counts.get("ERROR", 0) + vote_counts.get("TIMEOUT", 0)
            total = sum(vote_counts.values())

            # Decision logic per CLAUDE.md
            if approvals >= MIN_APPROVALS:
                result = ConsensusResult.PASS
            elif rejections >= MIN_APPROVALS:
                result = ConsensusResult.FAIL
            elif total >= 2 and errors > 0:
                result = ConsensusResult.INCONCLUSIVE
            else:
                result = ConsensusResult.PENDING

            # Update session
            completed_at = (
                datetime.now().isoformat()
                if result != ConsensusResult.PENDING
                else None
            )
            conn.execute(
                """
                UPDATE consensus_sessions SET
                    final_result = ?,
                    completed_at = ?
                WHERE id = ?
            """,
                (result.value, completed_at, session_id),
            )

            self._log_audit(
                conn,
                session_id,
                "CONSENSUS_EVALUATED",
                f"Result: {result.value}, Approvals: {approvals}, Rejections: {rejections}",
            )

            return result

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM consensus_sessions WHERE id = ?", (session_id,)
            ).fetchone()
            return dict(row) if row else None

    def get_votes(self, session_id: str) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM consensus_votes WHERE session_id = ? ORDER BY created_at",
                (session_id,),
            ).fetchall()
            return [dict(row) for row in rows]

    def get_history(self, session_id: str) -> List[Dict[str, Any]]:
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM verification_history WHERE session_id = ? ORDER BY created_at",
                (session_id,),
            ).fetchall()
            return [dict(row) for row in rows]

    def get_metrics(self, days: int = 30) -> Dict[str, Any]:
        with self._get_connection() as conn:
            row = conn.execute(
                """
                SELECT
                    COUNT(*) as total_sessions,
                    SUM(CASE WHEN final_result = 'PASS' THEN 1 ELSE 0 END) as passed,
                    SUM(CASE WHEN final_result = 'FAIL' THEN 1 ELSE 0 END) as failed,
                    SUM(CASE WHEN final_result = 'INCONCLUSIVE' THEN 1 ELSE 0 END) as inconclusive,
                    AVG(approvals) as avg_approvals
                FROM consensus_sessions
                WHERE created_at >= datetime('now', ?)
                AND final_result IS NOT NULL
            """,
                (f"-{days} days",),
            ).fetchone()

            metrics = dict(row) if row else {}

            if metrics.get("total_sessions", 0) > 0:
                metrics["pass_rate"] = round(
                    100.0 * metrics["passed"] / metrics["total_sessions"], 1
                )
            else:
                metrics["pass_rate"] = 0

            return metrics

    def _log_audit(
        self, conn: sqlite3.Connection, session_id: str, action: str, details: str
    ):
        conn.execute(
            """
            INSERT INTO verification_history (session_id, action, details)
            VALUES (?, ?, ?)
        """,
            (session_id, action, details),
        )


# =============================================================================
# Agent Invokers
# =============================================================================


class AgentInvoker:
    def __init__(self, timeout: int = DEFAULT_TIMEOUT):
        self.timeout = timeout

    def invoke(self, agent: Agent, prompt: str) -> tuple[str, int]:
        """Returns (response, duration_ms)"""
        start_time = time.time()

        try:
            if agent == Agent.CLAUDE:
                response = self._invoke_claude(prompt)
            elif agent == Agent.GEMINI:
                response = self._invoke_gemini(prompt)
            elif agent == Agent.CODEX:
                response = self._invoke_codex(prompt)
            else:
                response = "ERROR: Unknown agent"
        except subprocess.TimeoutExpired:
            response = "TIMEOUT"
        except Exception as e:
            response = f"ERROR: {str(e)}"

        duration_ms = int((time.time() - start_time) * 1000)
        return response, duration_ms

    def _invoke_claude(self, prompt: str) -> str:
        result = subprocess.run(
            ["claude", "-p", prompt],
            capture_output=True,
            text=True,
            timeout=self.timeout,
        )
        return result.stdout.strip() or result.stderr.strip()

    def _invoke_gemini(self, prompt: str) -> str:
        result = subprocess.run(
            ["gemini", "-m", "gemini-3-pro-preview", "--approval-mode", "yolo", prompt],
            capture_output=True,
            text=True,
            timeout=self.timeout,
        )
        return result.stdout.strip() or result.stderr.strip()

    def _invoke_codex(self, prompt: str) -> str:
        result = subprocess.run(
            [
                "codex",
                "exec",
                "-m",
                "gpt-5.2-codex",
                "-c",
                'model_reasoning_effort="xhigh"',
                "-s",
                "workspace-write",
                prompt,
            ],
            capture_output=True,
            text=True,
            timeout=self.timeout,
        )
        return result.stdout.strip() or result.stderr.strip()

    @staticmethod
    def parse_vote(response: str) -> Vote:
        response_lower = response.lower()

        if any(
            word in response_lower for word in ["approve", "approved", "pass", "lgtm"]
        ):
            return Vote.APPROVE
        elif any(
            word in response_lower for word in ["reject", "rejected", "fail", "block"]
        ):
            return Vote.REJECT
        elif "timeout" in response_lower:
            return Vote.TIMEOUT
        elif "error" in response_lower:
            return Vote.ERROR
        else:
            return Vote.ABSTAIN


# =============================================================================
# Consensus Verifier
# =============================================================================


class ConsensusVerifier:
    def __init__(self, db: DatabaseManager, invoker: AgentInvoker):
        self.db = db
        self.invoker = invoker

    def verify(
        self,
        task_id: str,
        description: str,
        implementer: Agent,
        scope: str = "",
        verification_request: Optional[VerificationRequest] = None,
    ) -> tuple[str, ConsensusResult]:
        """
        Run full verification workflow.
        Returns (session_id, result)
        """
        session_id = self.db.create_session(task_id, description, implementer, scope)

        logger.info(f"Starting consensus verification for session: {session_id}")
        logger.info(f"Implementer: {implementer.value} (excluded from voting)")

        # Generate prompt
        if verification_request:
            prompt = verification_request.to_prompt()
        else:
            prompt = f"""Verify the implementation for task {task_id}: {description}
Scope: {scope}
Check for correctness, security issues, edge cases.
Reply with APPROVE or REJECT followed by your findings."""

        # Collect votes from non-implementing agents
        for agent in Agent:
            if agent == implementer:
                logger.info(f"{agent.value}: SKIPPED (implementer)")
                continue

            logger.info(f"Requesting verification from {agent.value}...")

            response, duration_ms = self.invoker.invoke(agent, prompt)
            vote = AgentInvoker.parse_vote(response)
            reason = response[:500] if response else ""

            self.db.record_vote(session_id, agent, vote, reason, "", duration_ms)

            if vote == Vote.APPROVE:
                logger.info(f"{agent.value}: APPROVED")
            elif vote == Vote.REJECT:
                logger.warning(f"{agent.value}: REJECTED")
            else:
                logger.warning(f"{agent.value}: {vote.value}")

        # Evaluate consensus
        result = self.db.evaluate_consensus(session_id)

        logger.info(f"Consensus result: {result.value}")

        return session_id, result

    def verify_with_request(
        self, task_id: str, implementer: Agent, request: VerificationRequest
    ) -> tuple[str, ConsensusResult]:
        """Verify using standard VERIFY block format"""
        return self.verify(
            task_id=task_id,
            description=request.change_summary,
            implementer=implementer,
            scope=request.scope,
            verification_request=request,
        )


# =============================================================================
# Report Generator
# =============================================================================


class ReportGenerator:
    def __init__(self, db: DatabaseManager):
        self.db = db

    def generate(self, session_id: str, format: str = "text") -> str:
        """Generate verification report in specified format"""
        REPORT_DIR.mkdir(parents=True, exist_ok=True)

        session = self.db.get_session(session_id)
        votes = self.db.get_votes(session_id)
        history = self.db.get_history(session_id)

        if not session:
            raise ValueError(f"Session not found: {session_id}")

        if format == "json":
            return self._generate_json(session, votes, history)
        elif format in ("markdown", "md"):
            return self._generate_markdown(session, votes, history)
        else:
            return self._generate_text(session, votes, history)

    def _generate_json(
        self,
        session: Dict[str, Any],
        votes: List[Dict[str, Any]],
        history: List[Dict[str, Any]],
    ) -> str:
        return json.dumps(
            {
                "session": session,
                "votes": votes,
                "history": history,
                "generated_at": datetime.now().isoformat(),
            },
            indent=2,
            default=str,
        )

    def _generate_markdown(
        self,
        session: Dict[str, Any],
        votes: List[Dict[str, Any]],
        history: List[Dict[str, Any]],
    ) -> str:
        result = session.get("final_result", "PENDING")

        report = f"""# Tri-Agent Consensus Verification Report

**Session ID:** `{session['id']}`
**Generated:** {datetime.now().isoformat()}

---

## Session Details

| Field | Value |
|-------|-------|
| Task ID | {session['task_id']} |
| Description | {session.get('description', '')} |
| Implementer | {session['implementer']} |
| Scope | {session.get('scope', '')} |
| Final Result | **{result}** |
| Approvals | {session.get('approvals', 0)} |
| Rejections | {session.get('rejections', 0)} |
| Created | {session['created_at']} |
| Completed | {session.get('completed_at', 'N/A')} |

---

## Votes

| Agent | Vote | Reason | Duration (ms) | Timestamp |
|-------|------|--------|---------------|-----------|
"""
        for vote in votes:
            reason = (vote.get("reason", "") or "")[:50].replace("\n", " ")
            report += f"| {vote['agent']} | {vote['vote']} | {reason} | {vote.get('duration_ms', 0)} | {vote['created_at']} |\n"

        report += """
---

## Audit Trail

| Action | Details | Timestamp |
|--------|---------|-----------|
"""
        for entry in history:
            details = (entry.get("details", "") or "")[:50].replace("\n", " ")
            report += f"| {entry['action']} | {details} | {entry['created_at']} |\n"

        report += """
---

## Consensus Analysis

"""
        if result == "PASS":
            report += f"The verification **PASSED** with {session.get('approvals', 0)} approvals (minimum {MIN_APPROVALS} required).\n"
        elif result == "FAIL":
            report += f"The verification **FAILED** with {session.get('rejections', 0)} rejections.\n"
        elif result == "INCONCLUSIVE":
            report += (
                "The verification was **INCONCLUSIVE**. Manual review is required.\n"
            )
        else:
            report += "The verification is still **PENDING**.\n"

        report += """
---

*Report generated by Tri-Agent Consensus Verifier v1.0.0*
"""
        return report

    def _generate_text(
        self,
        session: Dict[str, Any],
        votes: List[Dict[str, Any]],
        history: List[Dict[str, Any]],
    ) -> str:
        return f"""
================================================================================
TRI-AGENT CONSENSUS VERIFICATION REPORT
================================================================================

Session ID: {session['id']}
Generated:  {datetime.now().isoformat()}

--------------------------------------------------------------------------------
SESSION DETAILS
--------------------------------------------------------------------------------
Task ID:      {session['task_id']}
Description:  {session.get('description', '')}
Implementer:  {session['implementer']}
Scope:        {session.get('scope', '')}
Final Result: {session.get('final_result', 'PENDING')}
Approvals:    {session.get('approvals', 0)}
Rejections:   {session.get('rejections', 0)}
Created:      {session['created_at']}
Completed:    {session.get('completed_at', 'N/A')}

--------------------------------------------------------------------------------
VOTES
--------------------------------------------------------------------------------
{self._format_votes_text(votes)}

--------------------------------------------------------------------------------
AUDIT TRAIL
--------------------------------------------------------------------------------
{self._format_history_text(history)}

================================================================================
END OF REPORT
================================================================================
"""

    def _format_votes_text(self, votes: List[Dict[str, Any]]) -> str:
        if not votes:
            return "No votes recorded."

        lines = []
        for vote in votes:
            lines.append(f"Agent: {vote['agent']}")
            lines.append(f"  Vote: {vote['vote']}")
            lines.append(f"  Reason: {vote.get('reason', 'N/A')[:100]}")
            lines.append(f"  Duration: {vote.get('duration_ms', 0)}ms")
            lines.append(f"  Time: {vote['created_at']}")
            lines.append("")
        return "\n".join(lines)

    def _format_history_text(self, history: List[Dict[str, Any]]) -> str:
        if not history:
            return "No history recorded."

        lines = []
        for entry in history:
            lines.append(
                f"[{entry['created_at']}] {entry['action']}: {entry.get('details', '')}"
            )
        return "\n".join(lines)

    def save(self, session_id: str, format: str = "text") -> Path:
        content = self.generate(session_id, format)

        ext = (
            "json"
            if format == "json"
            else ("md" if format in ("markdown", "md") else "txt")
        )
        output_path = REPORT_DIR / f"{session_id}.{ext}"

        output_path.write_text(content)
        logger.info(f"Report saved: {output_path}")

        return output_path


# =============================================================================
# Demo Scenarios
# =============================================================================


def demo_pass_scenario(db: DatabaseManager) -> str:
    """Demonstrate a PASS scenario with 2/2 approvals"""
    print("\n" + "=" * 60)
    print(" DEMO: PASS SCENARIO")
    print("=" * 60 + "\n")

    session_id = db.create_session(
        task_id="T-001",
        description="Implement OAuth2 PKCE flow",
        implementer=Agent.CLAUDE,
        scope="src/auth/",
    )

    print(f"Created session: {session_id}")
    print("Implementer: claude (excluded from voting)\n")

    # Simulate gemini approval
    print("Simulating Gemini review...")
    db.record_vote(
        session_id=session_id,
        agent=Agent.GEMINI,
        vote=Vote.APPROVE,
        reason="Architecture follows RFC 7636, security best practices applied",
        evidence="Code review completed",
        duration_ms=5200,
    )
    print("[PASS] Gemini: APPROVED")

    # Simulate codex approval
    print("Simulating Codex review...")
    db.record_vote(
        session_id=session_id,
        agent=Agent.CODEX,
        vote=Vote.APPROVE,
        reason="Tests pass, code coverage 85%, no vulnerabilities detected",
        evidence="npm test output clean",
        duration_ms=8100,
    )
    print("[PASS] Codex: APPROVED")

    # Evaluate
    result = db.evaluate_consensus(session_id)

    print(f"\nFinal Result: {result.value}")
    print("Approvals: 2/2 (minimum 2 required)")

    return session_id


def demo_fail_scenario(db: DatabaseManager) -> str:
    """Demonstrate a FAIL scenario with 2/2 rejections"""
    print("\n" + "=" * 60)
    print(" DEMO: FAIL SCENARIO")
    print("=" * 60 + "\n")

    session_id = db.create_session(
        task_id="T-002",
        description="Add admin bypass endpoint",
        implementer=Agent.CODEX,
        scope="src/api/admin.ts",
    )

    print(f"Created session: {session_id}")
    print("Implementer: codex (excluded from voting)\n")

    # Simulate claude rejection
    print("Simulating Claude review...")
    db.record_vote(
        session_id=session_id,
        agent=Agent.CLAUDE,
        vote=Vote.REJECT,
        reason="CRITICAL: Hardcoded credentials detected on line 47, bypasses authentication",
        evidence="Security scan failed",
        duration_ms=3200,
    )
    print("[FAIL] Claude: REJECTED")

    # Simulate gemini rejection
    print("Simulating Gemini review...")
    db.record_vote(
        session_id=session_id,
        agent=Agent.GEMINI,
        vote=Vote.REJECT,
        reason="HIGH: No input validation, SQL injection vulnerability in query builder",
        evidence="Static analysis failed",
        duration_ms=4800,
    )
    print("[FAIL] Gemini: REJECTED")

    # Evaluate
    result = db.evaluate_consensus(session_id)

    print(f"\nFinal Result: {result.value}")
    print("Rejections: 2/2 (consensus to reject)")
    print("\nIssues Found:")
    print("  1. CRITICAL - Hardcoded credentials (line 47)")
    print("  2. HIGH - SQL injection vulnerability")
    print("\nRequired Actions:")
    print("  - Remove hardcoded credentials, use environment variables")
    print("  - Add parameterized queries")
    print("  - Re-submit for fresh verification")

    return session_id


def demo_inconclusive_scenario(db: DatabaseManager) -> str:
    """Demonstrate an INCONCLUSIVE scenario with split votes"""
    print("\n" + "=" * 60)
    print(" DEMO: INCONCLUSIVE SCENARIO")
    print("=" * 60 + "\n")

    session_id = db.create_session(
        task_id="T-003",
        description="Refactor database connection pool",
        implementer=Agent.GEMINI,
        scope="src/db/pool.ts",
    )

    print(f"Created session: {session_id}")
    print("Implementer: gemini (excluded from voting)\n")

    # Simulate claude approval
    print("Simulating Claude review...")
    db.record_vote(
        session_id=session_id,
        agent=Agent.CLAUDE,
        vote=Vote.APPROVE,
        reason="Connection pooling implementation looks correct",
        evidence="Code review passed",
        duration_ms=4100,
    )
    print("[PASS] Claude: APPROVED")

    # Simulate codex timeout
    print("Simulating Codex review...")
    db.record_vote(
        session_id=session_id,
        agent=Agent.CODEX,
        vote=Vote.TIMEOUT,
        reason="Request timed out after 120s",
        evidence="",
        duration_ms=120000,
    )
    print("[WARN] Codex: TIMEOUT")

    # Evaluate
    result = db.evaluate_consensus(session_id)

    print(f"\nFinal Result: {result.value}")
    print("Approvals: 1/2, Timeouts: 1/2")
    print("\nStatus: Unable to reach consensus")
    print("\nResolution Options:")
    print("  1. Retry Codex verification with increased timeout")
    print("  2. Request third AI (manual Claude instance) for tiebreaker")
    print("  3. Escalate to user for manual review")

    return session_id


def run_all_demos():
    """Run all demo scenarios"""
    print("\n" + "=" * 60)
    print(" TRI-AGENT CONSENSUS VERIFIER - DEMO MODE")
    print("=" * 60)
    print("\nThis demo illustrates three verification scenarios:")
    print("  1. PASS - 2/2 approvals achieved")
    print("  2. FAIL - 2/2 rejections (security issues)")
    print("  3. INCONCLUSIVE - Split vote with timeout")

    db = DatabaseManager()
    reporter = ReportGenerator(db)

    sessions = []

    sessions.append(demo_pass_scenario(db))
    sessions.append(demo_fail_scenario(db))
    sessions.append(demo_inconclusive_scenario(db))

    print("\n" + "=" * 60)
    print(" DEMO COMPLETE")
    print("=" * 60)

    # Generate reports
    print(f"\nReports saved to: {REPORT_DIR}/")
    for session_id in sessions:
        path = reporter.save(session_id, "markdown")
        print(f"  - {path.name}")

    # Show metrics
    print("\nSession Metrics:")
    metrics = db.get_metrics()
    print(f"  Total: {metrics.get('total_sessions', 0)}")
    print(f"  Passed: {metrics.get('passed', 0)}")
    print(f"  Failed: {metrics.get('failed', 0)}")
    print(f"  Inconclusive: {metrics.get('inconclusive', 0)}")
    print(f"  Pass Rate: {metrics.get('pass_rate', 0)}%")


# =============================================================================
# CLI Interface
# =============================================================================


def main():
    parser = argparse.ArgumentParser(
        description="Tri-Agent Consensus Verifier - Validates 2/3 approval workflow"
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Init command
    subparsers.add_parser("init", help="Initialize database")

    # Verify command
    verify_parser = subparsers.add_parser("verify", help="Run verification workflow")
    verify_parser.add_argument("-t", "--task", required=True, help="Task identifier")
    verify_parser.add_argument("-d", "--desc", default="", help="Task description")
    verify_parser.add_argument(
        "-i",
        "--impl",
        required=True,
        choices=["claude", "codex", "gemini"],
        help="Implementing agent",
    )
    verify_parser.add_argument("-s", "--scope", default="", help="File/directory scope")
    verify_parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help="Timeout per agent in seconds",
    )

    # Create command
    create_parser = subparsers.add_parser("create", help="Create new session")
    create_parser.add_argument("-t", "--task", required=True, help="Task identifier")
    create_parser.add_argument("-d", "--desc", default="", help="Task description")
    create_parser.add_argument(
        "-i",
        "--impl",
        required=True,
        choices=["claude", "codex", "gemini"],
        help="Implementing agent",
    )
    create_parser.add_argument("-s", "--scope", default="", help="Scope")

    # Vote command
    vote_parser = subparsers.add_parser("vote", help="Record a vote")
    vote_parser.add_argument("-s", "--session", required=True, help="Session ID")
    vote_parser.add_argument(
        "-a",
        "--agent",
        required=True,
        choices=["claude", "codex", "gemini"],
        help="Voting agent",
    )
    vote_parser.add_argument(
        "-v",
        "--vote",
        required=True,
        choices=["APPROVE", "REJECT", "ABSTAIN"],
        help="Vote",
    )
    vote_parser.add_argument("-r", "--reason", default="", help="Reason")

    # Evaluate command
    eval_parser = subparsers.add_parser("evaluate", help="Evaluate consensus")
    eval_parser.add_argument("session", help="Session ID")

    # Report command
    report_parser = subparsers.add_parser("report", help="Generate report")
    report_parser.add_argument("-s", "--session", required=True, help="Session ID")
    report_parser.add_argument(
        "-f",
        "--format",
        default="text",
        choices=["text", "markdown", "json"],
        help="Output format",
    )
    report_parser.add_argument("-o", "--output", help="Output file path")

    # Metrics command
    metrics_parser = subparsers.add_parser("metrics", help="Show metrics")
    metrics_parser.add_argument("--days", type=int, default=30, help="Days to analyze")

    # Demo command
    subparsers.add_parser("demo", help="Run demo scenarios")

    # Parse args
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    db = DatabaseManager()

    if args.command == "init":
        print(f"Database initialized: {DB_FILE}")

    elif args.command == "verify":
        invoker = AgentInvoker(timeout=args.timeout)
        verifier = ConsensusVerifier(db, invoker)
        reporter = ReportGenerator(db)

        session_id, result = verifier.verify(
            task_id=args.task,
            description=args.desc,
            implementer=Agent(args.impl),
            scope=args.scope,
        )

        path = reporter.save(session_id, "markdown")
        print(f"\nSession: {session_id}")
        print(f"Result: {result.value}")
        print(f"Report: {path}")

    elif args.command == "create":
        session_id = db.create_session(
            task_id=args.task,
            description=args.desc,
            implementer=Agent(args.impl),
            scope=args.scope,
        )
        print(session_id)

    elif args.command == "vote":
        db.record_vote(
            session_id=args.session,
            agent=Agent(args.agent),
            vote=Vote(args.vote),
            reason=args.reason,
        )
        print(f"Vote recorded: {args.agent} -> {args.vote}")

    elif args.command == "evaluate":
        result = db.evaluate_consensus(args.session)
        print(result.value)

    elif args.command == "report":
        reporter = ReportGenerator(db)

        if args.output:
            content = reporter.generate(args.session, args.format)
            Path(args.output).write_text(content)
            print(f"Report saved: {args.output}")
        else:
            path = reporter.save(args.session, args.format)
            print(f"Report saved: {path}")

    elif args.command == "metrics":
        metrics = db.get_metrics(args.days)
        print(f"\nConsensus Metrics (last {args.days} days):")
        print(f"  Total Sessions:  {metrics.get('total_sessions', 0)}")
        print(f"  Passed:          {metrics.get('passed', 0)}")
        print(f"  Failed:          {metrics.get('failed', 0)}")
        print(f"  Inconclusive:    {metrics.get('inconclusive', 0)}")
        print(f"  Avg Approvals:   {metrics.get('avg_approvals', 0):.2f}")
        print(f"  Pass Rate:       {metrics.get('pass_rate', 0):.1f}%")

    elif args.command == "demo":
        run_all_demos()


if __name__ == "__main__":
    main()
