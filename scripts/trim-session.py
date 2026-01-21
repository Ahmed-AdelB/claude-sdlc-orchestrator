#!/usr/bin/env python3
"""
Claude Code Session Trimmer

Removes large base64 content from session files while preserving conversation context.
This fixes sessions that hang on resume due to oversized embedded files (PDFs, images).

Usage:
    python3 trim-session.py <session-id>
    python3 trim-session.py f919b7b7-d414-4c50-9590-6cc248425c6d
"""

import json
import sys
import os
import shutil
from pathlib import Path
from datetime import datetime

# Configuration
THRESHOLD_BYTES = 100_000  # 100KB - anything larger gets trimmed
PROJECTS_DIR = Path.home() / '.claude' / 'projects'

def format_size(size_bytes):
    """Format bytes to human readable size"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024:
            return f"{size_bytes:.1f}{unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f}TB"

def trim_large_content(obj, path_stack=None, stats=None):
    """
    Recursively traverse object and replace large base64/string content with placeholders.

    Returns the modified object and updates stats dict.
    """
    if path_stack is None:
        path_stack = []
    if stats is None:
        stats = {'trimmed': 0, 'saved_bytes': 0}

    if isinstance(obj, dict):
        result = {}
        for key, value in obj.items():
            new_path = path_stack + [key]

            # Special handling for known large content patterns
            if key == 'base64' and isinstance(value, str) and len(value) > THRESHOLD_BYTES:
                # PDF/file base64 content
                original_size = len(value)
                file_path = obj.get('filePath', 'unknown')
                file_size = obj.get('originalSize', original_size)

                placeholder = f"[BASE64 CONTENT TRIMMED - file: {file_path}, original_size: {format_size(file_size)}]"
                result[key] = placeholder
                stats['trimmed'] += 1
                stats['saved_bytes'] += original_size - len(placeholder)
                print(f"  Trimmed base64: {file_path} ({format_size(original_size)})")

            elif key == 'data' and isinstance(value, str) and len(value) > THRESHOLD_BYTES:
                # Image/media data content
                original_size = len(value)
                media_type = obj.get('media_type', obj.get('type', 'unknown'))

                placeholder = f"[MEDIA DATA TRIMMED - type: {media_type}, size: {format_size(original_size)}]"
                result[key] = placeholder
                stats['trimmed'] += 1
                stats['saved_bytes'] += original_size - len(placeholder)
                print(f"  Trimmed media data: {media_type} ({format_size(original_size)})")

            elif key == 'content' and isinstance(value, str) and len(value) > THRESHOLD_BYTES * 10:
                # Very large text content (rare, but possible)
                original_size = len(value)
                placeholder = f"[LARGE CONTENT TRIMMED - size: {format_size(original_size)}, preview: {value[:200]}...]"
                result[key] = placeholder
                stats['trimmed'] += 1
                stats['saved_bytes'] += original_size - len(placeholder)
                print(f"  Trimmed large content ({format_size(original_size)})")

            else:
                result[key] = trim_large_content(value, new_path, stats)
        return result

    elif isinstance(obj, list):
        return [trim_large_content(item, path_stack + [f'[{i}]'], stats) for i, item in enumerate(obj)]

    else:
        return obj

def find_session_file(session_id):
    """Find the session file by ID across all project directories"""
    for project_dir in PROJECTS_DIR.iterdir():
        if not project_dir.is_dir():
            continue

        # Check for exact match
        session_file = project_dir / f"{session_id}.jsonl"
        if session_file.exists():
            return session_file

        # Check for partial match (agent files)
        for f in project_dir.glob(f"*{session_id}*.jsonl"):
            return f

    return None

def update_sessions_index(project_dir, old_id, new_id, new_path):
    """Update the sessions-index.json to include the new trimmed session"""
    index_file = project_dir / 'sessions-index.json'
    if not index_file.exists():
        print(f"Warning: No sessions-index.json found in {project_dir}")
        return

    with open(index_file, 'r') as f:
        index_data = json.load(f)

    # Find and update the entry for this session
    entries = index_data.get('entries', [])
    for entry in entries:
        if entry.get('sessionId') == old_id:
            # Create a new entry for the trimmed version
            new_entry = entry.copy()
            new_entry['sessionId'] = new_id
            new_entry['fullPath'] = str(new_path)
            new_entry['firstPrompt'] = f"[TRIMMED] {entry.get('firstPrompt', '')[:100]}..."
            entries.append(new_entry)
            break

    # Backup and write
    backup_file = index_file.with_suffix('.json.bak')
    shutil.copy(index_file, backup_file)

    with open(index_file, 'w') as f:
        json.dump(index_data, f, indent=2)

    print(f"Updated sessions-index.json (backup: {backup_file})")

def trim_session(session_id):
    """Main function to trim a session file"""
    print(f"\n{'='*60}")
    print(f"Claude Code Session Trimmer")
    print(f"{'='*60}")
    print(f"Session ID: {session_id}")

    # Find the session file
    session_file = find_session_file(session_id)
    if not session_file:
        print(f"ERROR: Could not find session file for ID: {session_id}")
        print(f"Searched in: {PROJECTS_DIR}")
        sys.exit(1)

    print(f"Found: {session_file}")
    original_size = session_file.stat().st_size
    print(f"Original size: {format_size(original_size)}")

    # Create output file
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    new_id = f"trimmed-{session_id[:8]}-{timestamp}"
    output_file = session_file.parent / f"{new_id}.jsonl"

    # Process the file
    print(f"\nProcessing...")
    stats = {'trimmed': 0, 'saved_bytes': 0, 'lines': 0}

    with open(session_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8') as outfile:

        for line_num, line in enumerate(infile, 1):
            stats['lines'] += 1
            try:
                obj = json.loads(line)
                trimmed_obj = trim_large_content(obj, stats=stats)
                outfile.write(json.dumps(trimmed_obj) + '\n')
            except json.JSONDecodeError as e:
                print(f"  Warning: Line {line_num} is not valid JSON, copying as-is")
                outfile.write(line)

    # Report results
    new_size = output_file.stat().st_size
    print(f"\n{'='*60}")
    print(f"Results:")
    print(f"  Lines processed: {stats['lines']}")
    print(f"  Items trimmed: {stats['trimmed']}")
    print(f"  Original size: {format_size(original_size)}")
    print(f"  New size: {format_size(new_size)}")
    print(f"  Space saved: {format_size(original_size - new_size)} ({100*(original_size-new_size)/original_size:.1f}%)")
    print(f"\nOutput file: {output_file}")
    print(f"New session ID: {new_id}")

    # Update sessions index
    update_sessions_index(session_file.parent, session_id, new_id, output_file)

    print(f"\n{'='*60}")
    print(f"To resume the trimmed session, run:")
    print(f"  claude --resume {new_id}")
    print(f"{'='*60}\n")

    return output_file, new_id

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 trim-session.py <session-id>")
        print("Example: python3 trim-session.py f919b7b7-d414-4c50-9590-6cc248425c6d")
        sys.exit(1)

    session_id = sys.argv[1]
    trim_session(session_id)
