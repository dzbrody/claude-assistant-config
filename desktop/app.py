#!/usr/local/bin/python3.12
"""
Claude Assistant — Mac menu bar app.
Runs scheduled tasks via run-scheduled-task.sh in a new Terminal window.
"""
import rumps
import subprocess
import os
from pathlib import Path

PROJ = Path(__file__).parent.parent
RUNNER = PROJ / "scripts" / "run-scheduled-task.sh"

TASKS = {
    "morning-briefing": "☀️  Morning Briefing",
    "evening-wrap-up":  "🌙  Evening Wrap-Up",
    "weekend-briefing": "📅  Weekend Briefing",
    "weekly-review":    "📊  Weekly Review",
}


def run_task(task_key: str):
    label = TASKS[task_key]
    cmd = f"bash '{RUNNER}' {task_key}"
    script = f'''
tell application "Terminal"
    activate
    do script "{cmd}"
end tell
'''
    subprocess.Popen(["osascript", "-e", script])
    rumps.notification("Claude Assistant", label, "Starting in Terminal…")


class ClaudeAssistantApp(rumps.App):
    def __init__(self):
        super().__init__(
            name="Claude Assistant",
            title="🤖",
            quit_button=None,
        )
        self.menu = [
            rumps.MenuItem("☀️  Morning Briefing", callback=lambda _: run_task("morning-briefing")),
            rumps.MenuItem("🌙  Evening Wrap-Up",  callback=lambda _: run_task("evening-wrap-up")),
            rumps.MenuItem("📅  Weekend Briefing", callback=lambda _: run_task("weekend-briefing")),
            rumps.MenuItem("📊  Weekly Review",    callback=lambda _: run_task("weekly-review")),
            None,
            rumps.MenuItem("Quit", callback=rumps.quit_application),
        ]
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
