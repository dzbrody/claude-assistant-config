#!/usr/local/bin/python3.12
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
    "morning": ("morning-briefing.md",  "☀️  Morning Briefing"),
    "evening": ("evening-wrap-up.md",   "🌙  Evening Wrap-Up"),
    "weekend": ("weekend-briefing.md",  "📅  Weekend Briefing"),
    "weekly":  ("weekly-review.md",     "📊  Weekly Review"),
}


def extract_prompt(md_file: Path) -> str:
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

    tmp = Path(os.path.expanduser(f"~/.claude-assistant/desktop/.tmp_{task_key}.txt"))
    tmp.write_text(prompt)

    # Copy prompt to clipboard for instant paste (keystroke types char-by-char, too slow)
    subprocess.run(["pbcopy"], input=prompt.encode(), check=True)

    setup_cmd = f"export AWS_PROFILE=xgc-main && cd {PROJ} && {CLAUDE} --dangerously-skip-permissions"
    script = f'''
tell application "Terminal"
    activate
    do script "{setup_cmd}"
    -- Wait for claude to fully load including CLAUDE.md and MCP servers
    delay 8
    tell application "System Events"
        -- Cmd+V pastes the full prompt instantly from clipboard
        keystroke "v" using command down
        delay 1
        keystroke return
    end tell
end tell
'''
    subprocess.Popen(["osascript", "-e", script])
    rumps.notification("Claude Assistant", label, "Starting — claude launching in Terminal")


class ClaudeAssistantApp(rumps.App):
    def __init__(self):
        super().__init__(
            name="Claude Assistant",
            title="🤖",
            quit_button=None,
        )
        self.menu = [
            rumps.MenuItem("☀️  Morning Briefing", callback=lambda _: run_task("morning")),
            rumps.MenuItem("🌙  Evening Wrap-Up",  callback=lambda _: run_task("evening")),
            rumps.MenuItem("📅  Weekend Briefing", callback=lambda _: run_task("weekend")),
            rumps.MenuItem("📊  Weekly Review",    callback=lambda _: run_task("weekly")),
            None,
            rumps.MenuItem("Quit", callback=rumps.quit_application),
        ]
        # Hide from Dock once the run loop starts
        self._hide_dock_timer = rumps.Timer(self._hide_from_dock, 0.1)
        self._hide_dock_timer.start()

    def _hide_from_dock(self, _):
        try:
            import AppKit
            AppKit.NSApp.setActivationPolicy_(
                AppKit.NSApplicationActivationPolicyAccessory
            )
        except Exception:
            pass
        self._hide_dock_timer.stop()


if __name__ == "__main__":
    ClaudeAssistantApp().run()
