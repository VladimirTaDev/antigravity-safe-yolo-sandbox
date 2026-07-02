# Antigravity Safe YOLO Sandbox

A robust, fully automated bootstrap script to safely run Google Antigravity (`agy`) in YOLO mode inside an isolated Windows Sandbox environment. 

By running Antigravity in Windows Sandbox, you can grant the agent full autonomous capabilities (`--dangerously-skip-permissions`) without risking your host operating system.

## Features

- **Total Isolation:** Executes `agy` inside an ephemeral Windows Sandbox virtual machine.
- **Automatic Authentication:** Securely bridges your existing `gemini:antigravity` credentials from your Host OS into the Sandbox via PowerShell bridging. No need to log in twice.
- **Smart Synchronization:** Seamlessly merges conversation history and configuration changes back to your host upon exit, ensuring you never lose a session (even if working concurrently on the host).
- **Flawless Rendering:** Automatically installs PowerShell 7 and the modern Windows Terminal inside the Sandbox to prevent graphical TUI glitches associated with the legacy Windows Console.
- **Zero Workspace Footprint:** Stages all initialization files in the host's `%TEMP%` directory and self-cleans perfectly. No junk files are left in your project folder.
- **MCP Ready:** Automatically installs Node.js so Model Context Protocol servers run smoothly.

## Prerequisites

1. **Windows 10/11 Pro, Enterprise, or Education:** (Windows Home does not support Windows Sandbox natively).
2. **Windows Sandbox Enabled:** You can enable this by searching for "Turn Windows features on or off" in the Start Menu and checking "Windows Sandbox".
3. **Antigravity CLI:** Must be installed and authenticated on your host machine.

## How to Use

1. **Download:** Place `launch_safe_yolo_antigravity_in_windows_sandbox_1.0.cmd` into the root folder of the project you want the agent to work on.
2. **Launch:** Double-click the script. It will automatically compile the sandbox configuration, extract your credentials, and boot the virtual machine.
3. **Work:** The sandbox will boot and begin installing its dependencies (which only takes a minute). **Disclaimer:** Please wait until the Windows Terminal window automatically pops up with `agy` logged in and running in dangerous mode. This is the signal that everything is fully installed and ready to use!
4. **Save and Exit:** When you are finished, **do not just close the Sandbox window**. Double-click the `Close_Sandbox_Preserving_agy_history_and_settings` shortcut that was automatically generated on the Sandbox's Desktop. This guarantees your conversation history is safely merged back to your host before shutting down the VM.

## Disclaimer

**Please read carefully before using:**
While Windows Sandbox completely isolates and protects your *host operating system*, the **project folder** you launch this script from is explicitly mapped into the Sandbox with read/write access. This means the AI has full permission to modify, delete, or break any files within that specific project folder. 

By using this script, you acknowledge that you are running an AI in a dangerous, auto-approve mode (`--dangerously-skip-permissions`). The author of this script assumes **zero liability** for any lost data, broken code, or damage caused by the AI. Always use version control before letting the agent loose!

## Troubleshooting

- **Sandbox fails to start:** Ensure you have launched `agy` at least once on your host machine so the `.gemini` directory exists. 
- **Terminal Glitches:** The script uses Windows Terminal by default. If you manually switch to `conhost.exe`, you may experience text overwrite bugs or spacing issues.
