#!/usr/bin/env python3
"""
Claude Assistant — Mac menu bar app.
Runs briefing tasks via the claude CLI in a new Terminal window.
"""
import rumps
import subprocess
import os
from datetime import datetime
from pathlib import Path

PROJ = Path(__file__).parent.parent
PROMPTS_DIR = PROJ / "scheduled-tasks"
CLAUDE = os.path.expanduser("~/.local/bin/claude")

TASKS = {
    "morning":  ("morning-briefing.md",  "☀️  Morning Briefing"),
    "evening":  ("evening-wrap-up.md",   "🌙  Evening Wrap-Up"),
    "weekend":  ("weekend-briefing.md",  "📅  Weekend Briefing"),
    "weekly":   ("weekly-review.md",     "📊  Weekly Review"),
}


def extract_prompt(md_file: Path) -> str:
    """Extract everything after the '## Prompt' heading."""
    text = md_file.read_text()
    marker = "## Prompt"
    idx = text.find(marker)
    if idx == -1:
        raise ValueError(f"No '## Prompt' section found in {md_file.name}")
    return text[idx + len(marker):].strip()


def run_task(task_key: str):
    filename, label = TASKS[task_key]
    md_path = PROMPTS_DIR / filename
    try:
        prompt = extract_prompt(md_path)
    except Exception as e:
        rumps.notification("Claude Assistant", "Error", str(e))
        return

    date_str = datetime.now().strftime("%Y-%m-%d")
    prompt = prompt.replace("{date}", date_str)

    # Write prompt to a temp file to avoid shell escaping issues
    tmp = Path(os.path.expanduser(f"~/.claude-assistant/desktop/.tmp_{task_key}.txt"))
    tmp.write_text(prompt)

    # AppleScript: open new Terminal tab, run the task, keep window open
    script = f'''
tell application "Terminal"
    activate
    do script "echo '🤖 {label} — {date_str}'; echo ''; {CLAUDE} --dangerously-skip-permissions -p \\"$(cat {tmp})\\" ; echo ''; echo '✅ Done. You can close this window.'"
end tell
'''
    subprocess.Popen(["osascript", "-e", script])
    rumps.notification("Claude Assistant", label, "Running — check Terminal window")


class ClaudeAssistantApp(rumps.App):
    def __init__(self):
        super().__init__(
            name="Claude Assistant",
            title="🤖",
            quit_button=None,
        )
        self.menu = [
            rumps.MenuItem("☀️  Morning Briefing",  callback=lambda _: run_task("morning")),
            rumps.MenuItem("🌙  Evening Wrap-Up",   callback=lambda _: run_task("evening")),
            rumps.MenuItem("📅  Weekend Briefing",  callback=lambda _: run_task("weekend")),
            rumps.MenuItem("📊  Weekly Review",     callback=lambda _: run_task("weekly")),
            None,  # separator
            rumps.MenuItem("Quit", callback=rumps.quit_application),
        ]


if __name__ == "__main__":
    ClaudeAssistantApp().run()
