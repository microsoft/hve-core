# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""
Lint script to detect bare 'pip install' calls.
The repository follows a 'uv-first' Python convention.
"""
import os
import re
import sys


EXCLUDE_DIRS = {".git", "evals", ".venv", "venv", "env", "node_modules", "__pycache__"}
EXCLUDE_FILES = {"THIRD-PARTY-NOTICES", "lint_pip_install.py"}
TARGET_DIRS = [".github/workflows", "scripts"]

bare_pip_pattern = re.compile(r'\bpip3?\s+install\b')
uv_pip_pattern = re.compile(r'\buv\s+pip3?\s+install\b')

violations = []
scanned_files = set()

def should_exclude(filepath):
    norm_path = filepath.replace("\\", "/")
    
    parts = set(norm_path.split("/"))
    if parts & EXCLUDE_DIRS:
        return True
        
    for ex_file in EXCLUDE_FILES:
        if ex_file in norm_path:
            return True
            
    return False

def scan_file(filepath):
    if filepath in scanned_files:
        return
    scanned_files.add(filepath)
    
    if should_exclude(filepath):
        return
        
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for i, line in enumerate(f, 1):
                stripped_line = line.strip()
                
                if not stripped_line or stripped_line.startswith("#"):
                    continue
                
                if stripped_line.startswith("name:") or stripped_line.startswith("- name:"):
                    continue
                
                if bare_pip_pattern.search(line) and not uv_pip_pattern.search(line):
                    violations.append(f"{filepath}:{i}: {stripped_line}")
    except Exception as e:
        print(f"Warning: Could not read {filepath}: {e}")

def main():
    for target_dir in TARGET_DIRS:
        if os.path.isdir(target_dir):
            for root, _, files in os.walk(target_dir):
                for file in files:
                    scan_file(os.path.join(root, file))

    for root, _, files in os.walk("."):
        for file in files:
            if file.endswith(".py"):
                scan_file(os.path.join(root, file))

    if violations:
        print("ERROR: Found bare 'pip install' calls. Use 'uv pip install' instead.")
        print("The repo follows a uv-first Python convention.\n")
        for v in sorted(set(violations)):
            print(f"  - {v}")
        sys.exit(1)
    else:
        print("Success: No bare 'pip install' calls found.")

if __name__ == "__main__":
    main()
