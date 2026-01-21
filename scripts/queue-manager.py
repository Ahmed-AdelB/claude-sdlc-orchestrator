#!/usr/bin/env python3
"""
Tri-Agent Task Queue Manager with Priority System

Implements:
- Priority levels: P0-CRITICAL, P1-HIGH, P2-MEDIUM, P3-LOW
- Priority queue (heap-based) with SQLite persistence
- Age-based priority boost (old tasks get promoted)
- Batch processing for similar tasks

Author: Ahmed Adel Bakr Alderai
"""

import argparse
import heapq
import json
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import IntEnum
from pathlib import Path
from typing import Optional
from contextlib import contextmanager


# =============================================================================
# Constants and Configuration
# =============================================================================

QUEUE_DB_PATH = Path.home() / ".claude" / "task-queue" / "queue.db"
QUEUE_DIR = Path.home() / ".claude" / "task-queue"
PENDING_DIR = QUEUE_DIR / "pending"
RUNNING_DIR = QUEUE_DIR / "running"
COMPLETED_DIR = QUEUE_DIR / "completed"
FAILED_DIR = QUEUE_DIR / "failed"

# Age boost configuration (hours until promotion)
AGE_BOOST_THRESHOLDS = {
    "P3_to_P2": 4,  # P3-LOW -> P2-MEDIUM after 4 hours
    "P2_to_P1": 8,  # P2-MEDIUM -> P1-HIGH after 8 hours
    "P1_to_P0": 24,  # P1-HIGH -> P0-CRITICAL after 24 hours
}

# Batch processing configuration
BATCH_SIZE_LIMIT = 10
SIMILARITY_THRESHOLD = 0.7  # Tasks must be 70% similar to batch


class Priority(IntEnum):
    """Task priority levels - lower value = higher priority."""

    P0_CRITICAL = 0
    P1_HIGH = 1
    P2_MEDIUM = 2
    P3_LOW = 3

    @classmethod
    def from_string(cls, s: str) -> "Priority":
        """Parse priority from string like 'P0', 'critical', 'P1-HIGH', etc."""
        s = s.upper().strip()
        mapping = {
            "P0": cls.P0_CRITICAL,
            "CRITICAL": cls.P0_CRITICAL,
            "P0-CRITICAL": cls.P0_CRITICAL,
            "P1": cls.P1_HIGH,
            "HIGH": cls.P1_HIGH,
            "P1-HIGH": cls.P1_HIGH,
            "P2": cls.P2_MEDIUM,
            "MEDIUM": cls.P2_MEDIUM,
            "P2-MEDIUM": cls.P2_MEDIUM,
            "P3": cls.P3_LOW,
            "LOW": cls.P3_LOW,
            "P3-LOW": cls.P3_LOW,
        }
        if s in mapping:
            return mapping[s]
        raise ValueError(f"Unknown priority: {s}")


class TaskStatus:
    """Task status constants."""

    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    BLOCKED = "blocked"


class TaskCategory:
    """Task categories for batching."""

    SECURITY = "security"
    BACKEND = "backend"
    FRONTEND = "frontend"
    TESTING = "testing"
    DOCUMENTATION = "documentation"
    DEVOPS = "devops"
    REFACTORING = "refactoring"
    BUGFIX = "bugfix"
    FEATURE = "feature"
    OTHER = "other"


# =============================================================================
# Data Classes
# =============================================================================


@dataclass(order=True)
class Task:
    """
    Task in the priority queue.

    Comparison is based on (priority, -created_at_ts) for heap ordering.
    Lower priority value = higher priority.
    Earlier creation = higher priority within same level.
    """

    # Fields used for ordering (must come first)
    sort_priority: int = field(compare=True, repr=False)
    sort_timestamp: float = field(compare=True, repr=False)

    # Actual task data
    task_id: str = field(compare=False)
    priority: Priority = field(compare=False)
    description: str = field(compare=False)
    category: str = field(compare=False, default=TaskCategory.OTHER)
    status: str = field(compare=False, default=TaskStatus.PENDING)
    assigned_agent: Optional[str] = field(compare=False, default=None)
    verifier_agent: Optional[str] = field(compare=False, default=None)
    created_at: str = field(
        compare=False, default_factory=lambda: datetime.now().isoformat()
    )
    updated_at: str = field(
        compare=False, default_factory=lambda: datetime.now().isoformat()
    )
    started_at: Optional[str] = field(compare=False, default=None)
    completed_at: Optional[str] = field(compare=False, default=None)
    original_priority: Optional[int] = field(compare=False, default=None)
    boost_count: int = field(compare=False, default=0)
    batch_id: Optional[str] = field(compare=False, default=None)
    metadata: dict = field(compare=False, default_factory=dict)
    retry_count: int = field(compare=False, default=0)
    max_retries: int = field(compare=False, default=3)
    dependencies: list = field(compare=False, default_factory=list)
    tags: list = field(compare=False, default_factory=list)

    def __post_init__(self):
        """Initialize sort fields from priority and timestamp."""
        if self.sort_priority == 0 and self.priority:
            self.sort_priority = int(self.priority)
        if self.sort_timestamp == 0.0:
            self.sort_timestamp = -datetime.fromisoformat(self.created_at).timestamp()
        if self.original_priority is None:
            self.original_priority = int(self.priority)

    @classmethod
    def create(
        cls,
        task_id: str,
        description: str,
        priority: Priority,
        category: str = TaskCategory.OTHER,
        **kwargs,
    ) -> "Task":
        """Factory method to create a new task."""
        now = datetime.now().isoformat()
        return cls(
            sort_priority=int(priority),
            sort_timestamp=-datetime.fromisoformat(now).timestamp(),
            task_id=task_id,
            priority=priority,
            description=description,
            category=category,
            created_at=now,
            updated_at=now,
            original_priority=int(priority),
            **kwargs,
        )

    def to_dict(self) -> dict:
        """Convert task to dictionary for serialization."""
        return {
            "task_id": self.task_id,
            "priority": self.priority.name,
            "priority_value": int(self.priority),
            "description": self.description,
            "category": self.category,
            "status": self.status,
            "assigned_agent": self.assigned_agent,
            "verifier_agent": self.verifier_agent,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "original_priority": self.original_priority,
            "boost_count": self.boost_count,
            "batch_id": self.batch_id,
            "metadata": self.metadata,
            "retry_count": self.retry_count,
            "max_retries": self.max_retries,
            "dependencies": self.dependencies,
            "tags": self.tags,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Task":
        """Create task from dictionary."""
        priority = Priority.from_string(data.get("priority", "P2"))
        created_at = data.get("created_at", datetime.now().isoformat())
        return cls(
            sort_priority=data.get("priority_value", int(priority)),
            sort_timestamp=-datetime.fromisoformat(created_at).timestamp(),
            task_id=data["task_id"],
            priority=priority,
            description=data.get("description", ""),
            category=data.get("category", TaskCategory.OTHER),
            status=data.get("status", TaskStatus.PENDING),
            assigned_agent=data.get("assigned_agent"),
            verifier_agent=data.get("verifier_agent"),
            created_at=created_at,
            updated_at=data.get("updated_at", datetime.now().isoformat()),
            started_at=data.get("started_at"),
            completed_at=data.get("completed_at"),
            original_priority=data.get("original_priority"),
            boost_count=data.get("boost_count", 0),
            batch_id=data.get("batch_id"),
            metadata=data.get("metadata", {}),
            retry_count=data.get("retry_count", 0),
            max_retries=data.get("max_retries", 3),
            dependencies=data.get("dependencies", []),
            tags=data.get("tags", []),
        )


@dataclass
class Batch:
    """A batch of similar tasks for parallel processing."""

    batch_id: str
    category: str
    priority: Priority
    tasks: list[Task] = field(default_factory=list)
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    status: str = TaskStatus.PENDING

    def add_task(self, task: Task) -> bool:
        """Add task to batch if compatible."""
        if len(self.tasks) >= BATCH_SIZE_LIMIT:
            return False
        if task.category != self.category:
            return False
        task.batch_id = self.batch_id
        self.tasks.append(task)
        return True

    def to_dict(self) -> dict:
        """Convert batch to dictionary."""
        return {
            "batch_id": self.batch_id,
            "category": self.category,
            "priority": self.priority.name,
            "task_count": len(self.tasks),
            "task_ids": [t.task_id for t in self.tasks],
            "created_at": self.created_at,
            "status": self.status,
        }


# =============================================================================
# Database Layer
# =============================================================================


class QueueDatabase:
    """SQLite-backed persistent storage for the task queue."""

    def __init__(self, db_path: Path = QUEUE_DB_PATH):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    @contextmanager
    def _get_connection(self):
        """Get database connection with proper handling."""
        conn = sqlite3.connect(str(self.db_path), timeout=30.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=30000")
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def _init_db(self):
        """Initialize database schema."""
        with self._get_connection() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS tasks (
                    task_id TEXT PRIMARY KEY,
                    priority INTEGER NOT NULL,
                    original_priority INTEGER,
                    description TEXT NOT NULL,
                    category TEXT DEFAULT 'other',
                    status TEXT DEFAULT 'pending',
                    assigned_agent TEXT,
                    verifier_agent TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    started_at TEXT,
                    completed_at TEXT,
                    boost_count INTEGER DEFAULT 0,
                    batch_id TEXT,
                    metadata TEXT DEFAULT '{}',
                    retry_count INTEGER DEFAULT 0,
                    max_retries INTEGER DEFAULT 3,
                    dependencies TEXT DEFAULT '[]',
                    tags TEXT DEFAULT '[]'
                );

                CREATE TABLE IF NOT EXISTS batches (
                    batch_id TEXT PRIMARY KEY,
                    category TEXT NOT NULL,
                    priority INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    status TEXT DEFAULT 'pending'
                );

                CREATE TABLE IF NOT EXISTS queue_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    total_tasks INTEGER,
                    pending_tasks INTEGER,
                    running_tasks INTEGER,
                    completed_tasks INTEGER,
                    failed_tasks INTEGER,
                    p0_count INTEGER,
                    p1_count INTEGER,
                    p2_count INTEGER,
                    p3_count INTEGER,
                    avg_wait_time_seconds REAL,
                    boosted_tasks INTEGER
                );

                CREATE TABLE IF NOT EXISTS task_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    task_id TEXT NOT NULL,
                    action TEXT NOT NULL,
                    old_value TEXT,
                    new_value TEXT,
                    timestamp TEXT NOT NULL,
                    FOREIGN KEY (task_id) REFERENCES tasks(task_id)
                );

                CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
                CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority, created_at);
                CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category);
                CREATE INDEX IF NOT EXISTS idx_tasks_batch ON tasks(batch_id);
                CREATE INDEX IF NOT EXISTS idx_history_task ON task_history(task_id);
            """
            )

    def save_task(self, task: Task) -> None:
        """Save or update a task."""
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO tasks (
                    task_id, priority, original_priority, description, category,
                    status, assigned_agent, verifier_agent, created_at, updated_at,
                    started_at, completed_at, boost_count, batch_id, metadata,
                    retry_count, max_retries, dependencies, tags
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    task.task_id,
                    int(task.priority),
                    task.original_priority,
                    task.description,
                    task.category,
                    task.status,
                    task.assigned_agent,
                    task.verifier_agent,
                    task.created_at,
                    task.updated_at,
                    task.started_at,
                    task.completed_at,
                    task.boost_count,
                    task.batch_id,
                    json.dumps(task.metadata),
                    task.retry_count,
                    task.max_retries,
                    json.dumps(task.dependencies),
                    json.dumps(task.tags),
                ),
            )

    def get_task(self, task_id: str) -> Optional[Task]:
        """Get a task by ID."""
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM tasks WHERE task_id = ?", (task_id,)
            ).fetchone()
            if row:
                return self._row_to_task(row)
        return None

    def get_pending_tasks(self) -> list[Task]:
        """Get all pending tasks ordered by priority."""
        with self._get_connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM tasks
                WHERE status = 'pending'
                ORDER BY priority ASC, created_at ASC
            """
            ).fetchall()
            return [self._row_to_task(row) for row in rows]

    def get_tasks_by_status(self, status: str) -> list[Task]:
        """Get tasks by status."""
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM tasks WHERE status = ? ORDER BY priority ASC, created_at ASC",
                (status,),
            ).fetchall()
            return [self._row_to_task(row) for row in rows]

    def get_tasks_by_category(self, category: str, status: str = None) -> list[Task]:
        """Get tasks by category, optionally filtered by status."""
        with self._get_connection() as conn:
            if status:
                rows = conn.execute(
                    "SELECT * FROM tasks WHERE category = ? AND status = ? ORDER BY priority ASC",
                    (category, status),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM tasks WHERE category = ? ORDER BY priority ASC",
                    (category,),
                ).fetchall()
            return [self._row_to_task(row) for row in rows]

    def delete_task(self, task_id: str) -> bool:
        """Delete a task."""
        with self._get_connection() as conn:
            cursor = conn.execute("DELETE FROM tasks WHERE task_id = ?", (task_id,))
            return cursor.rowcount > 0

    def record_history(
        self, task_id: str, action: str, old_value: str = None, new_value: str = None
    ) -> None:
        """Record task history event."""
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO task_history (task_id, action, old_value, new_value, timestamp)
                VALUES (?, ?, ?, ?, ?)
            """,
                (task_id, action, old_value, new_value, datetime.now().isoformat()),
            )

    def get_queue_stats(self) -> dict:
        """Get current queue statistics."""
        with self._get_connection() as conn:
            stats = {}

            # Total counts by status
            for status in [
                TaskStatus.PENDING,
                TaskStatus.RUNNING,
                TaskStatus.COMPLETED,
                TaskStatus.FAILED,
            ]:
                count = conn.execute(
                    "SELECT COUNT(*) FROM tasks WHERE status = ?", (status,)
                ).fetchone()[0]
                stats[f"{status}_count"] = count

            # Counts by priority
            for p in Priority:
                count = conn.execute(
                    "SELECT COUNT(*) FROM tasks WHERE priority = ? AND status = 'pending'",
                    (int(p),),
                ).fetchone()[0]
                stats[f"{p.name}_count"] = count

            # Boosted tasks
            stats["boosted_count"] = conn.execute(
                "SELECT COUNT(*) FROM tasks WHERE boost_count > 0"
            ).fetchone()[0]

            # Average wait time for completed tasks
            avg_wait = conn.execute(
                """
                SELECT AVG(
                    (julianday(started_at) - julianday(created_at)) * 86400
                ) FROM tasks
                WHERE started_at IS NOT NULL AND created_at IS NOT NULL
            """
            ).fetchone()[0]
            stats["avg_wait_seconds"] = round(avg_wait, 2) if avg_wait else 0

            # Oldest pending task age
            oldest = conn.execute(
                """
                SELECT MIN(created_at) FROM tasks WHERE status = 'pending'
            """
            ).fetchone()[0]
            if oldest:
                age = datetime.now() - datetime.fromisoformat(oldest)
                stats["oldest_pending_hours"] = round(age.total_seconds() / 3600, 2)
            else:
                stats["oldest_pending_hours"] = 0

            return stats

    def save_metrics_snapshot(self) -> None:
        """Save current metrics snapshot."""
        stats = self.get_queue_stats()
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO queue_metrics (
                    timestamp, total_tasks, pending_tasks, running_tasks,
                    completed_tasks, failed_tasks, p0_count, p1_count,
                    p2_count, p3_count, avg_wait_time_seconds, boosted_tasks
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    datetime.now().isoformat(),
                    sum(
                        stats.get(f"{s}_count", 0)
                        for s in [
                            TaskStatus.PENDING,
                            TaskStatus.RUNNING,
                            TaskStatus.COMPLETED,
                            TaskStatus.FAILED,
                        ]
                    ),
                    stats.get("pending_count", 0),
                    stats.get("running_count", 0),
                    stats.get("completed_count", 0),
                    stats.get("failed_count", 0),
                    stats.get("P0_CRITICAL_count", 0),
                    stats.get("P1_HIGH_count", 0),
                    stats.get("P2_MEDIUM_count", 0),
                    stats.get("P3_LOW_count", 0),
                    stats.get("avg_wait_seconds", 0),
                    stats.get("boosted_count", 0),
                ),
            )

    def save_batch(self, batch: Batch) -> None:
        """Save a batch."""
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO batches (batch_id, category, priority, created_at, status)
                VALUES (?, ?, ?, ?, ?)
            """,
                (
                    batch.batch_id,
                    batch.category,
                    int(batch.priority),
                    batch.created_at,
                    batch.status,
                ),
            )

    def _row_to_task(self, row: sqlite3.Row) -> Task:
        """Convert database row to Task object."""
        return Task(
            sort_priority=row["priority"],
            sort_timestamp=-datetime.fromisoformat(row["created_at"]).timestamp(),
            task_id=row["task_id"],
            priority=Priority(row["priority"]),
            description=row["description"],
            category=row["category"],
            status=row["status"],
            assigned_agent=row["assigned_agent"],
            verifier_agent=row["verifier_agent"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            started_at=row["started_at"],
            completed_at=row["completed_at"],
            original_priority=row["original_priority"],
            boost_count=row["boost_count"],
            batch_id=row["batch_id"],
            metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            retry_count=row["retry_count"],
            max_retries=row["max_retries"],
            dependencies=json.loads(row["dependencies"]) if row["dependencies"] else [],
            tags=json.loads(row["tags"]) if row["tags"] else [],
        )


# =============================================================================
# Priority Queue Manager
# =============================================================================


class PriorityQueue:
    """
    Heap-based priority queue with age-based boosting.

    Uses a min-heap where lower priority values = higher priority.
    Supports automatic priority boosting for aging tasks.
    """

    def __init__(self, db: QueueDatabase):
        self.db = db
        self._heap: list[Task] = []
        self._task_map: dict[str, Task] = {}
        self._load_from_db()

    def _load_from_db(self) -> None:
        """Load pending tasks from database into heap."""
        self._heap = []
        self._task_map = {}
        tasks = self.db.get_pending_tasks()
        for task in tasks:
            self._task_map[task.task_id] = task
            heapq.heappush(self._heap, task)

    def add(self, task: Task) -> None:
        """Add a task to the queue."""
        task.status = TaskStatus.PENDING
        task.updated_at = datetime.now().isoformat()
        self.db.save_task(task)
        self.db.record_history(task.task_id, "created", None, task.priority.name)
        self._task_map[task.task_id] = task
        heapq.heappush(self._heap, task)

    def pop(self) -> Optional[Task]:
        """Remove and return highest priority task."""
        while self._heap:
            task = heapq.heappop(self._heap)
            if task.task_id in self._task_map:
                # Verify task is still pending (may have been updated)
                current = self.db.get_task(task.task_id)
                if current and current.status == TaskStatus.PENDING:
                    del self._task_map[task.task_id]
                    return current
        return None

    def peek(self) -> Optional[Task]:
        """Return highest priority task without removing."""
        while self._heap:
            task = self._heap[0]
            if task.task_id in self._task_map:
                current = self.db.get_task(task.task_id)
                if current and current.status == TaskStatus.PENDING:
                    return current
            heapq.heappop(self._heap)
        return None

    def update_priority(
        self, task_id: str, new_priority: Priority, is_boost: bool = False
    ) -> bool:
        """Update task priority."""
        task = self.db.get_task(task_id)
        if not task:
            return False

        old_priority = task.priority
        task.priority = new_priority
        task.sort_priority = int(new_priority)
        task.updated_at = datetime.now().isoformat()

        if is_boost:
            task.boost_count += 1
            self.db.record_history(
                task_id, "priority_boost", old_priority.name, new_priority.name
            )
        else:
            self.db.record_history(
                task_id, "priority_change", old_priority.name, new_priority.name
            )

        self.db.save_task(task)

        # Rebuild heap with updated priority
        if task_id in self._task_map:
            self._task_map[task_id] = task
            self._rebuild_heap()

        return True

    def _rebuild_heap(self) -> None:
        """Rebuild the heap from task map."""
        self._heap = list(self._task_map.values())
        heapq.heapify(self._heap)

    def apply_age_boosts(self) -> int:
        """
        Apply priority boosts to aging tasks.

        Returns number of tasks boosted.
        """
        boosted = 0
        now = datetime.now()
        pending_tasks = self.db.get_pending_tasks()

        for task in pending_tasks:
            created = datetime.fromisoformat(task.created_at)
            age_hours = (now - created).total_seconds() / 3600

            new_priority = None

            if task.priority == Priority.P3_LOW:
                if age_hours >= AGE_BOOST_THRESHOLDS["P3_to_P2"]:
                    new_priority = Priority.P2_MEDIUM
            elif task.priority == Priority.P2_MEDIUM:
                if age_hours >= AGE_BOOST_THRESHOLDS["P2_to_P1"]:
                    new_priority = Priority.P1_HIGH
            elif task.priority == Priority.P1_HIGH:
                if age_hours >= AGE_BOOST_THRESHOLDS["P1_to_P0"]:
                    new_priority = Priority.P0_CRITICAL

            if new_priority:
                self.update_priority(task.task_id, new_priority, is_boost=True)
                boosted += 1

        return boosted

    def size(self) -> int:
        """Return number of pending tasks."""
        return len(self._task_map)

    def is_empty(self) -> bool:
        """Check if queue is empty."""
        return self.size() == 0

    def get_by_priority(self, priority: Priority) -> list[Task]:
        """Get all pending tasks of a specific priority."""
        return [t for t in self._task_map.values() if t.priority == priority]


# =============================================================================
# Batch Processor
# =============================================================================


class BatchProcessor:
    """Groups similar tasks for efficient parallel processing."""

    def __init__(self, db: QueueDatabase, queue: PriorityQueue):
        self.db = db
        self.queue = queue
        self._batch_counter = 0

    def _generate_batch_id(self) -> str:
        """Generate unique batch ID."""
        self._batch_counter += 1
        return f"batch_{int(time.time())}_{self._batch_counter}"

    def create_batches(self) -> list[Batch]:
        """
        Create batches from pending tasks.

        Groups tasks by category and priority level.
        """
        batches: list[Batch] = []

        # Group tasks by category and priority
        for priority in Priority:
            for category in [
                TaskCategory.SECURITY,
                TaskCategory.BACKEND,
                TaskCategory.FRONTEND,
                TaskCategory.TESTING,
                TaskCategory.DOCUMENTATION,
                TaskCategory.DEVOPS,
                TaskCategory.REFACTORING,
                TaskCategory.BUGFIX,
                TaskCategory.FEATURE,
                TaskCategory.OTHER,
            ]:

                tasks = self.db.get_tasks_by_category(category, TaskStatus.PENDING)
                tasks = [t for t in tasks if t.priority == priority]

                if not tasks:
                    continue

                # Create batches for this category/priority
                current_batch = None
                for task in tasks:
                    if (
                        current_batch is None
                        or len(current_batch.tasks) >= BATCH_SIZE_LIMIT
                    ):
                        current_batch = Batch(
                            batch_id=self._generate_batch_id(),
                            category=category,
                            priority=priority,
                        )
                        batches.append(current_batch)

                    current_batch.add_task(task)
                    self.db.save_task(task)

                if current_batch:
                    self.db.save_batch(current_batch)

        return batches

    def get_next_batch(self) -> Optional[Batch]:
        """Get the next batch to process (highest priority first)."""
        batches = self.create_batches()
        if not batches:
            return None

        # Sort by priority (lower = higher priority)
        batches.sort(key=lambda b: (int(b.priority), b.created_at))
        return batches[0] if batches else None

    def export_batch_file(self, batch: Batch, output_dir: Path = PENDING_DIR) -> Path:
        """Export batch to file format compatible with existing system."""
        output_dir.mkdir(parents=True, exist_ok=True)
        filepath = output_dir / f"batch_{batch.batch_id}.txt"

        lines = [
            "Complete ALL of the following tasks. Number your responses clearly.\n"
        ]
        for i, task in enumerate(batch.tasks, 1):
            lines.append(f"**Task {i} [{task.task_id}]:** {task.description}\n")

        filepath.write_text("\n".join(lines))
        return filepath


# =============================================================================
# Queue Manager (Main Interface)
# =============================================================================


class QueueManager:
    """
    Main interface for task queue management.

    Provides high-level operations for adding, processing, and managing tasks.
    """

    def __init__(self, db_path: Path = QUEUE_DB_PATH):
        self.db = QueueDatabase(db_path)
        self.queue = PriorityQueue(self.db)
        self.batch_processor = BatchProcessor(self.db, self.queue)

    def add_task(
        self, description: str, priority: str = "P2", category: str = "other", **kwargs
    ) -> Task:
        """Add a new task to the queue."""
        task_id = f"task_{int(time.time())}_{os.getpid()}"
        task = Task.create(
            task_id=task_id,
            description=description,
            priority=Priority.from_string(priority),
            category=category,
            **kwargs,
        )
        self.queue.add(task)
        return task

    def get_next_task(self) -> Optional[Task]:
        """Get the next highest priority task."""
        self.queue.apply_age_boosts()
        return self.queue.peek()

    def start_task(self, task_id: str, agent: str = None) -> Optional[Task]:
        """Mark a task as started."""
        task = self.db.get_task(task_id)
        if not task:
            return None

        task.status = TaskStatus.RUNNING
        task.started_at = datetime.now().isoformat()
        task.updated_at = datetime.now().isoformat()
        if agent:
            task.assigned_agent = agent

        self.db.save_task(task)
        self.db.record_history(
            task_id, "started", TaskStatus.PENDING, TaskStatus.RUNNING
        )

        # Move file to running directory
        self._move_task_file(task_id, PENDING_DIR, RUNNING_DIR)

        return task

    def complete_task(self, task_id: str, success: bool = True) -> Optional[Task]:
        """Mark a task as completed or failed."""
        task = self.db.get_task(task_id)
        if not task:
            return None

        new_status = TaskStatus.COMPLETED if success else TaskStatus.FAILED
        task.status = new_status
        task.completed_at = datetime.now().isoformat()
        task.updated_at = datetime.now().isoformat()

        self.db.save_task(task)
        self.db.record_history(
            task_id,
            "completed" if success else "failed",
            TaskStatus.RUNNING,
            new_status,
        )

        # Move file to appropriate directory
        target_dir = COMPLETED_DIR if success else FAILED_DIR
        self._move_task_file(task_id, RUNNING_DIR, target_dir)

        return task

    def retry_task(self, task_id: str) -> Optional[Task]:
        """Retry a failed task."""
        task = self.db.get_task(task_id)
        if not task:
            return None

        if task.retry_count >= task.max_retries:
            return None

        task.retry_count += 1
        task.status = TaskStatus.PENDING
        task.started_at = None
        task.completed_at = None
        task.updated_at = datetime.now().isoformat()

        self.db.save_task(task)
        self.db.record_history(task_id, "retry", TaskStatus.FAILED, TaskStatus.PENDING)

        # Re-add to queue
        self.queue._task_map[task_id] = task
        heapq.heappush(self.queue._heap, task)

        # Move file back to pending
        self._move_task_file(task_id, FAILED_DIR, PENDING_DIR)

        return task

    def set_priority(self, task_id: str, priority: str) -> bool:
        """Update task priority."""
        return self.queue.update_priority(task_id, Priority.from_string(priority))

    def get_stats(self) -> dict:
        """Get queue statistics."""
        stats = self.db.get_queue_stats()
        stats["queue_size"] = self.queue.size()
        return stats

    def apply_boosts(self) -> int:
        """Apply age-based priority boosts."""
        return self.queue.apply_age_boosts()

    def create_batch(self) -> Optional[Batch]:
        """Create a batch of similar tasks."""
        return self.batch_processor.get_next_batch()

    def export_batch(self, batch: Batch) -> Path:
        """Export batch to file."""
        return self.batch_processor.export_batch_file(batch)

    def import_tasks(self, filepath: Path) -> list[Task]:
        """Import tasks from a file."""
        tasks = []
        content = filepath.read_text()

        # Parse tasks from batch file format
        pattern = r"\*\*Task \d+ \[([^\]]+)\]:\*\* (.+)"
        matches = re.findall(pattern, content)

        for task_id, description in matches:
            task = Task.create(
                task_id=task_id,
                description=description.strip(),
                priority=Priority.P2_MEDIUM,
            )
            self.queue.add(task)
            tasks.append(task)

        return tasks

    def list_tasks(
        self, status: str = None, priority: str = None, limit: int = 50
    ) -> list[Task]:
        """List tasks with optional filters."""
        if status:
            tasks = self.db.get_tasks_by_status(status)
        else:
            tasks = self.db.get_pending_tasks()

        if priority:
            p = Priority.from_string(priority)
            tasks = [t for t in tasks if t.priority == p]

        return tasks[:limit]

    def save_metrics(self) -> None:
        """Save metrics snapshot."""
        self.db.save_metrics_snapshot()

    def _move_task_file(self, task_id: str, from_dir: Path, to_dir: Path) -> None:
        """Move task file between directories."""
        to_dir.mkdir(parents=True, exist_ok=True)
        for ext in [".txt", ".json"]:
            src = from_dir / f"{task_id}{ext}"
            if src.exists():
                dst = to_dir / f"{task_id}{ext}"
                src.rename(dst)


# =============================================================================
# CLI Interface
# =============================================================================


def format_task_table(tasks: list[Task], verbose: bool = False) -> str:
    """Format tasks as a table."""
    if not tasks:
        return "No tasks found."

    lines = []
    header = f"{'ID':<30} {'Priority':<12} {'Status':<12} {'Category':<15} {'Age':<10}"
    if verbose:
        header += f" {'Boosts':<7} {'Retries':<8}"
    lines.append(header)
    lines.append("-" * len(header))

    now = datetime.now()
    for task in tasks:
        created = datetime.fromisoformat(task.created_at)
        age = now - created
        age_str = f"{age.seconds // 3600}h {(age.seconds // 60) % 60}m"
        if age.days > 0:
            age_str = f"{age.days}d {age.seconds // 3600}h"

        row = f"{task.task_id:<30} {task.priority.name:<12} {task.status:<12} {task.category:<15} {age_str:<10}"
        if verbose:
            row += f" {task.boost_count:<7} {task.retry_count}/{task.max_retries:<8}"
        lines.append(row)

    return "\n".join(lines)


def format_stats(stats: dict) -> str:
    """Format statistics as text."""
    lines = [
        "=== Queue Statistics ===",
        f"Queue Size: {stats.get('queue_size', 0)}",
        "",
        "By Status:",
        f"  Pending:   {stats.get('pending_count', 0)}",
        f"  Running:   {stats.get('running_count', 0)}",
        f"  Completed: {stats.get('completed_count', 0)}",
        f"  Failed:    {stats.get('failed_count', 0)}",
        "",
        "By Priority (Pending):",
        f"  P0-CRITICAL: {stats.get('P0_CRITICAL_count', 0)}",
        f"  P1-HIGH:     {stats.get('P1_HIGH_count', 0)}",
        f"  P2-MEDIUM:   {stats.get('P2_MEDIUM_count', 0)}",
        f"  P3-LOW:      {stats.get('P3_LOW_count', 0)}",
        "",
        f"Boosted Tasks:      {stats.get('boosted_count', 0)}",
        f"Avg Wait Time:      {stats.get('avg_wait_seconds', 0):.1f}s",
        f"Oldest Pending Age: {stats.get('oldest_pending_hours', 0):.1f}h",
    ]
    return "\n".join(lines)


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Tri-Agent Task Queue Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Add a new task
  %(prog)s add "Implement user authentication" --priority P1 --category security

  # List pending tasks
  %(prog)s list --status pending

  # Get next task
  %(prog)s next

  # Start working on a task
  %(prog)s start task_123456_789

  # Complete a task
  %(prog)s complete task_123456_789

  # Apply age-based boosts
  %(prog)s boost

  # Create a batch of similar tasks
  %(prog)s batch

  # View statistics
  %(prog)s stats

  # Set task priority
  %(prog)s priority task_123456_789 P0

  # Retry a failed task
  %(prog)s retry task_123456_789
        """,
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Add command
    add_parser = subparsers.add_parser("add", help="Add a new task")
    add_parser.add_argument("description", help="Task description")
    add_parser.add_argument(
        "-p",
        "--priority",
        default="P2",
        choices=["P0", "P1", "P2", "P3", "CRITICAL", "HIGH", "MEDIUM", "LOW"],
        help="Task priority (default: P2)",
    )
    add_parser.add_argument("-c", "--category", default="other", help="Task category")
    add_parser.add_argument("-t", "--tags", nargs="+", default=[], help="Task tags")
    add_parser.add_argument(
        "-d",
        "--dependencies",
        nargs="+",
        default=[],
        help="Task dependencies (task IDs)",
    )
    add_parser.add_argument("-a", "--agent", help="Assigned agent")
    add_parser.add_argument("-v", "--verifier", help="Verifier agent")

    # List command
    list_parser = subparsers.add_parser("list", help="List tasks")
    list_parser.add_argument("-s", "--status", help="Filter by status")
    list_parser.add_argument("-p", "--priority", help="Filter by priority")
    list_parser.add_argument(
        "-l", "--limit", type=int, default=50, help="Max tasks to show"
    )
    list_parser.add_argument(
        "--verbose", "-V", action="store_true", help="Show more details"
    )
    list_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # Next command
    subparsers.add_parser("next", help="Get next highest priority task")

    # Start command
    start_parser = subparsers.add_parser("start", help="Start a task")
    start_parser.add_argument("task_id", help="Task ID")
    start_parser.add_argument("-a", "--agent", help="Agent working on task")

    # Complete command
    complete_parser = subparsers.add_parser("complete", help="Complete a task")
    complete_parser.add_argument("task_id", help="Task ID")
    complete_parser.add_argument("--failed", action="store_true", help="Mark as failed")

    # Priority command
    priority_parser = subparsers.add_parser("priority", help="Set task priority")
    priority_parser.add_argument("task_id", help="Task ID")
    priority_parser.add_argument("priority", help="New priority (P0-P3)")

    # Retry command
    retry_parser = subparsers.add_parser("retry", help="Retry a failed task")
    retry_parser.add_argument("task_id", help="Task ID")

    # Boost command
    subparsers.add_parser("boost", help="Apply age-based priority boosts")

    # Batch command
    batch_parser = subparsers.add_parser("batch", help="Create task batch")
    batch_parser.add_argument(
        "--export", action="store_true", help="Export batch to file"
    )

    # Stats command
    stats_parser = subparsers.add_parser("stats", help="Show queue statistics")
    stats_parser.add_argument("--json", action="store_true", help="Output as JSON")
    stats_parser.add_argument(
        "--save", action="store_true", help="Save metrics snapshot"
    )

    # Import command
    import_parser = subparsers.add_parser("import", help="Import tasks from file")
    import_parser.add_argument("file", help="File to import")

    # Get command
    get_parser = subparsers.add_parser("get", help="Get task details")
    get_parser.add_argument("task_id", help="Task ID")
    get_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Delete a task")
    delete_parser.add_argument("task_id", help="Task ID")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    manager = QueueManager()

    try:
        if args.command == "add":
            task = manager.add_task(
                description=args.description,
                priority=args.priority,
                category=args.category,
                tags=args.tags,
                dependencies=args.dependencies,
                assigned_agent=args.agent,
                verifier_agent=args.verifier,
            )
            print(f"Created task: {task.task_id}")
            print(f"Priority: {task.priority.name}")
            print(f"Category: {task.category}")

        elif args.command == "list":
            tasks = manager.list_tasks(
                status=args.status,
                priority=args.priority,
                limit=args.limit,
            )
            if args.json:
                print(json.dumps([t.to_dict() for t in tasks], indent=2))
            else:
                print(format_task_table(tasks, args.verbose))

        elif args.command == "next":
            task = manager.get_next_task()
            if task:
                print(f"Next task: {task.task_id}")
                print(f"Priority: {task.priority.name}")
                print(f"Description: {task.description}")
                print(f"Category: {task.category}")
            else:
                print("No pending tasks.")

        elif args.command == "start":
            task = manager.start_task(args.task_id, args.agent)
            if task:
                print(f"Started task: {task.task_id}")
            else:
                print(f"Task not found: {args.task_id}")
                sys.exit(1)

        elif args.command == "complete":
            task = manager.complete_task(args.task_id, not args.failed)
            if task:
                status = "failed" if args.failed else "completed"
                print(f"Task {status}: {task.task_id}")
            else:
                print(f"Task not found: {args.task_id}")
                sys.exit(1)

        elif args.command == "priority":
            if manager.set_priority(args.task_id, args.priority):
                print(f"Updated priority for {args.task_id} to {args.priority}")
            else:
                print(f"Task not found: {args.task_id}")
                sys.exit(1)

        elif args.command == "retry":
            task = manager.retry_task(args.task_id)
            if task:
                print(f"Retrying task: {task.task_id} (attempt {task.retry_count})")
            else:
                print(
                    f"Cannot retry task: {args.task_id} (max retries reached or not found)"
                )
                sys.exit(1)

        elif args.command == "boost":
            count = manager.apply_boosts()
            print(f"Boosted {count} tasks")

        elif args.command == "batch":
            batch = manager.create_batch()
            if batch:
                print(f"Created batch: {batch.batch_id}")
                print(f"Category: {batch.category}")
                print(f"Priority: {batch.priority.name}")
                print(f"Tasks: {len(batch.tasks)}")
                for task in batch.tasks:
                    print(f"  - {task.task_id}: {task.description[:50]}...")

                if args.export:
                    filepath = manager.export_batch(batch)
                    print(f"Exported to: {filepath}")
            else:
                print("No tasks available for batching.")

        elif args.command == "stats":
            stats = manager.get_stats()
            if args.json:
                print(json.dumps(stats, indent=2))
            else:
                print(format_stats(stats))

            if args.save:
                manager.save_metrics()
                print("\nMetrics snapshot saved.")

        elif args.command == "import":
            tasks = manager.import_tasks(Path(args.file))
            print(f"Imported {len(tasks)} tasks")
            for task in tasks:
                print(f"  - {task.task_id}")

        elif args.command == "get":
            task = manager.db.get_task(args.task_id)
            if task:
                if args.json:
                    print(json.dumps(task.to_dict(), indent=2))
                else:
                    print(f"Task ID:     {task.task_id}")
                    print(f"Priority:    {task.priority.name}")
                    print(f"Status:      {task.status}")
                    print(f"Category:    {task.category}")
                    print(f"Description: {task.description}")
                    print(f"Created:     {task.created_at}")
                    print(f"Updated:     {task.updated_at}")
                    if task.started_at:
                        print(f"Started:     {task.started_at}")
                    if task.completed_at:
                        print(f"Completed:   {task.completed_at}")
                    if task.assigned_agent:
                        print(f"Agent:       {task.assigned_agent}")
                    if task.verifier_agent:
                        print(f"Verifier:    {task.verifier_agent}")
                    print(f"Boosts:      {task.boost_count}")
                    print(f"Retries:     {task.retry_count}/{task.max_retries}")
            else:
                print(f"Task not found: {args.task_id}")
                sys.exit(1)

        elif args.command == "delete":
            if manager.db.delete_task(args.task_id):
                print(f"Deleted task: {args.task_id}")
            else:
                print(f"Task not found: {args.task_id}")
                sys.exit(1)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
