import os
import sys
import time
import sqlite3
import subprocess
import psutil
import shutil
import threading
from datetime import datetime

# Configuration
TEST_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(TEST_DIR, "../../"))
NUM_TASKS = 10
TIMEOUT_SECONDS = 60

def setup_fake_root(fake_root):
    """Sets up a fake autonomous root directory structure."""
    if os.path.exists(fake_root):
        shutil.rmtree(fake_root)
    os.makedirs(fake_root)

    # Symlink lib
    os.symlink(os.path.join(PROJECT_ROOT, "lib"), os.path.join(fake_root, "lib"))
    
    # Create bin dir and symlink worker
    os.makedirs(os.path.join(fake_root, "bin"))
    worker_src = os.path.join(PROJECT_ROOT, "bin", "tri-agent-worker")
    worker_dst = os.path.join(fake_root, "bin", "tri-agent-worker")
    os.symlink(worker_src, worker_dst)

    # Create fake delegates that simulate work and success
    for model in ["claude", "gemini", "codex"]:
        delegate_path = os.path.join(fake_root, "bin", f"{model}-delegate")
        with open(delegate_path, "w") as f:
            f.write("#!/bin/bash\n")
            f.write("sleep 0.2\n") # Simulate latency
            f.write("echo 'Simulated output' > \"$1\"\n") # Assuming arg1 is input or we just write to stdout? 
            # Worker calls: "${AUTONOMOUS_ROOT}/bin/${model}-delegate" "$content" > "${exec_dir}/output.txt" 2>&1
            # So we should just echo to stdout
            f.write("echo 'Simulated success'\n")
            f.write("exit 0\n")
        os.chmod(delegate_path, 0o755)

    # Create directory structure
    task_dirs = ["queue", "running", "completed", "failed", "review"]
    for d in task_dirs:
        os.makedirs(os.path.join(fake_root, "tasks", d))
    
    os.makedirs(os.path.join(fake_root, "state", "executions"))
    os.makedirs(os.path.join(fake_root, "logs"))

def create_tasks(fake_root, num_tasks):
    """Creates dummy tasks in the queue."""
    queue_dir = os.path.join(fake_root, "tasks", "queue")
    print(f"Creating {num_tasks} tasks in {queue_dir}...")
    for i in range(1, num_tasks + 1):
        task_id = f"LOAD_TEST_{i:04d}"
        task_file = os.path.join(queue_dir, f"{task_id}.md")
        with open(task_file, "w") as f:
            f.write(f"# Load Test Task {i}\nExecute a simple operation.")

def monitor_resources(pid, stop_event, stats):
    """Monitors CPU and Memory usage of the worker process."""
    try:
        proc = psutil.Process(pid)
        while not stop_event.is_set():
            try:
                # interval=None is non-blocking, but first call is 0.0
                cpu = proc.cpu_percent(interval=None)
                mem = proc.memory_info().rss / 1024 / 1024 # MB
                stats['cpu'].append(cpu)
                stats['memory'].append(mem)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                break
            time.sleep(0.5)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass

def run_load_test():
    print("Starting M5-034 Load Testing Validation...")
    
    fake_root = os.path.join(TEST_DIR, "fake_autonomous_root")
    setup_fake_root(fake_root)
    create_tasks(fake_root, NUM_TASKS)

    env = os.environ.copy()
    env["AUTONOMOUS_ROOT"] = fake_root
    # Ensure we don't interfere with real production DB
    env["STATE_DB"] = os.path.join(fake_root, "state", "tri-agent.db")
    
    # Pre-init DB to avoid race conditions or errors during startup if worker assumes it exists
    # Although worker init calls sqlite_state_init
    
    print("Launching worker...")
    start_time = time.time()
    
    worker_out = open(os.path.join(fake_root, "logs", "worker.out"), "w")
    worker_err = open(os.path.join(fake_root, "logs", "worker.err"), "w")

    worker_process = subprocess.Popen(
        [os.path.join(fake_root, "bin", "tri-agent-worker")],
        env=env,
        stdout=worker_out,
        stderr=worker_err,
        preexec_fn=os.setsid # Create new process group
    )
    
    print(f"Worker PID: {worker_process.pid}")

    stats = {'cpu': [], 'memory': []}
    stop_monitor = threading.Event()
    monitor_thread = threading.Thread(target=monitor_resources, args=(worker_process.pid, stop_monitor, stats))
    monitor_thread.start()

    db_path = env["STATE_DB"]
    
    # Wait for DB creation
    wait_db = 0
    while not os.path.exists(db_path):
        time.sleep(0.1)
        wait_db += 0.1
        if worker_process.poll() is not None:
             print("Worker exited prematurely!")
             break
        if wait_db > 5:
             print("Timeout waiting for DB creation.")
             break

    completed = 0
    elapsed = 0
    
    if os.path.exists(db_path):
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            while completed < NUM_TASKS and elapsed < TIMEOUT_SECONDS:
                time.sleep(1)
                elapsed += 1
                try:
                    # Check for tasks in final states or REVIEW (worker considers REVIEW as done processing)
                    cursor.execute("SELECT COUNT(*) FROM tasks WHERE state IN ('COMPLETED', 'FAILED', 'REVIEW')")
                    row = cursor.fetchone()
                    if row:
                        current_completed = row[0]
                        if current_completed > completed:
                            print(f"Progress: {current_completed}/{NUM_TASKS} tasks processed ({elapsed}s)")
                            completed = current_completed
                except sqlite3.OperationalError:
                    # DB might be locked
                    pass
            conn.close()
        except Exception as e:
            print(f"DB Error: {e}")
    else:
        print("DB was not created.")

    end_time = time.time()
    duration = end_time - start_time
    
    print("Stopping worker...")
    stop_monitor.set()
    monitor_thread.join()
    
    os.killpg(os.getpgid(worker_process.pid), 15) # SIGTERM to group
    try:
        worker_process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(worker_process.pid), 9) # SIGKILL
        
    worker_out.close()
    worker_err.close()

    # Debug output if no tasks processed
    if completed == 0:
        print("\n--- WORKER STDERR ---")
        with open(os.path.join(fake_root, "logs", "worker.err"), "r") as f:
            print(f.read())
        print("---------------------")

    # Generate Report
    print("\n" + "="*40)
    print("       LOAD TEST REPORT")
    print("="*40)
    print(f"Tasks Submitted: {NUM_TASKS}")
    print(f"Tasks Processed: {completed}")
    print(f"Duration:        {duration:.2f} seconds")
    throughput = completed / duration if duration > 0 else 0
    print(f"Throughput:      {throughput:.2f} tasks/sec")
    
    if stats['cpu']:
        avg_cpu = sum(stats['cpu']) / len(stats['cpu'])
        max_cpu = max(stats['cpu'])
        print(f"Avg CPU Usage:   {avg_cpu:.2f}%")
        print(f"Max CPU Usage:   {max_cpu:.2f}%")
    
    if stats['memory']:
        avg_mem = sum(stats['memory']) / len(stats['memory'])
        max_mem = max(stats['memory'])
        print(f"Avg Memory:      {avg_mem:.2f} MB")
        print(f"Max Memory:      {max_mem:.2f} MB")

    # Analyze DB results
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT state, COUNT(*) FROM tasks GROUP BY state")
        rows = cursor.fetchall()
        print("\nTask State Breakdown:")
        for state, count in rows:
            print(f"  {state}: {count}")
        conn.close()
    except Exception as e:
        print(f"Error reading final DB stats: {e}")

    # Cleanup
    # shutil.rmtree(fake_root)
    print(f"\nTest artifacts kept in: {fake_root}")

if __name__ == "__main__":
    run_load_test()
