from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from task_researcher_comparison.fixtures import load_scenarios


def build_prompt(topic: str, variant: str) -> str:
    if variant == "with-subagents":
        return f'/task-research topic="{topic}" mode=lanes subagents=true'
    return f'/task-research topic="{topic}" mode=focused subagents=false'


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture Task Researcher comparison outputs.")
    parser.add_argument("--fixtures-root", type=Path, default=Path("scripts/evals/task-researcher-comparison/fixtures"))
    parser.add_argument("--output-root", type=Path, default=Path("logs/task-researcher-comparison/captures"))
    args = parser.parse_args()

    command_template = os.getenv("TASK_RESEARCHER_RUNNER")
    if not command_template:
        print("TASK_RESEARCHER_RUNNER is not set; write prompts under logs for manual capture.")

    scenarios = load_scenarios(args.fixtures_root / "scenarios.yml")
    for scenario in scenarios:
        scenario_dir = args.output_root / scenario.id
        scenario_dir.mkdir(parents=True, exist_ok=True)
        for variant in ("no-subagents", "with-subagents"):
            prompt = build_prompt(scenario.prompt, variant)
            if command_template:
                try:
                    completed = subprocess.run(
                        command_template.format(prompt=prompt),
                        shell=True,
                        check=True,
                        text=True,
                        capture_output=True,
                    )
                    (scenario_dir / f"{variant}.md").write_text(completed.stdout, encoding="utf-8")
                except subprocess.CalledProcessError as e:
                    print(f"Error: Runner failed for scenario '{scenario.id}' variant '{variant}'", file=sys.stderr)
                    print(f"Command returned exit code {e.returncode}", file=sys.stderr)
                    if e.stderr:
                        print(f"stderr: {e.stderr}", file=sys.stderr)
                    return 1
            else:
                (scenario_dir / f"{variant}.prompt.txt").write_text(prompt + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
