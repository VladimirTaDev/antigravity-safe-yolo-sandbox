# Antigravity Safe YOLO Sandbox

A single-file bootstrap launcher to safely run Google Antigravity (`agy`) with `--dangerously-skip-permissions` inside an isolated Windows Sandbox VM.

By running Antigravity inside Windows Sandbox, you can grant the agent autonomous capabilities while isolating your host operating system, keeping host `.gemini` configuration read-only, and optionally running in **Read-Only / Diff-Only Mode**.

## Features

- **Two Isolation Modes (Interactive Dialog + CLI Flags):**
  - **Read-Only / Diff-Only Mode (Safest):** Maps your project folder read-only, copies it to a native sandbox path (`C:\work`) for fast I/O and full symlink/Git support, and exports a `.patch` diff plus added/modified/deleted files to `%TEMP%\agy-yolo-patches\` on close.
  - **Full YOLO Mode (Read-Write):** Maps your project folder read-write at `C:\workspace` for immediate edits while keeping the host OS isolated.
- **Zero Project-Folder Footprint:** Keeps temporary per-run staging in `%TEMP%\agy_yolo_run_*` (locked down via universal SID ACLs granting only `NT AUTHORITY\SYSTEM`, `BUILTIN\Administrators`, and the current user), cached portable tools in `%LOCALAPPDATA%\agy-yolo-sandbox\tools`, and exported patches in `%TEMP%\agy-yolo-patches`. Never writes files into your project directory.
- **Hardened `.gemini` Bridge & Safe Outbox Merge:**
  - Maps host `.gemini` **read-only** (`C:\host-gemini-config`) and maps `C:\agy-bootstrap` **read-only** (`C:\agy-outbox` is the only writable sync bridge).
  - Creates an optional in-sandbox junction (`C:\Users\<HostUser>\.gemini`) so plugins/configs referencing host-absolute `.gemini` paths continue working seamlessly under `WDAGUtilityAccount`.
  - On exit, stops `agy` cleanly, checkpoints `conversation_summaries.db` WAL via Node 24's built-in `node:sqlite`, merges SQLite rows and `history.jsonl` line-by-line (preserving concurrent host sessions), and copies only allow-listed history directories (`antigravity-cli\brain`, `antigravity-cli\conversations`, `antigravity-cli\annotations`) after rejecting any NTFS reparse points/symlinks.
  - `antigravity-cli\knowledge` is excluded from automatic host sync by default (`SyncKnowledgeBack = $false`) to prevent prompt-injection persistence.
  - Runs periodic non-SQLite autosave every **3 minutes** (configurable) so closing via the window **X** retains recent session files without risking torn SQLite snapshots.
- **Fast Host Pre-Extracted Portable Tools (x64 & ARM64):** On first launch, downloads in parallel, SHA-256 verifies, and pre-extracts **Node.js `24.22.3` LTS**, **PowerShell `7.6.10` LTS**, **Windows Terminal `1.25.3131.0`**, and **MinGit `2.56.1`** (configured with `safe.directory '*'` and `core.longpaths true`) on the host, then maps them **read-only** into the sandbox (`C:\agy-tools`) for rapid subsequent startups.
- **Automatic Credential Bridging & Immediate Wipe:** Extracts the `gemini:antigravity` generic credential in memory, injects it as the first sandbox step, and zero-overwrites/deletes the staging token immediately upon `cred_ok.flag`, timeout, abort, or `Ctrl+C`.
- **Safe Path & Root Guardrails:** Handles spaces, `&`, `!`, Unicode paths, and drive roots (`D:\`), supports `wsb.exe` CLI (Windows 11 24H2+) with direct `WindowsSandbox.exe` fallback, and warns/blocks accidental launches directly on `Desktop`, `Downloads`, `Documents`, `%USERPROFILE%`, drive roots, or system directories unless explicitly confirmed.

## Prerequisites

1. **Windows 10/11 Pro, Enterprise, or Education** (Windows Home does not support Windows Sandbox natively).
2. **Hardware Virtualization Enabled** in BIOS/UEFI, plus **Windows Sandbox** enabled in *"Turn Windows features on or off"*.
3. **Antigravity CLI (`agy`)** installed and logged in on the host machine.

## How to Use

1. **Place Anywhere:** Save `launch_safe_yolo_antigravity_in_windows_sandbox.cmd` anywhere (keeping it **outside** the target project folder is recommended so an untrusted agent cannot modify the launcher itself).
2. **Launch:**
   - **Drag and drop** a project folder onto `launch_safe_yolo_antigravity_in_windows_sandbox.cmd`, OR
   - Place it in a project folder and double-click it, OR
   - Run from a terminal with optional flags:
     ```cmd
     launch_safe_yolo_antigravity_in_windows_sandbox.cmd "D:\MyProject" --readonly
     launch_safe_yolo_antigravity_in_windows_sandbox.cmd "D:\MyProject" --yolo --continue --model gemini-3-pro
     launch_safe_yolo_antigravity_in_windows_sandbox.cmd "D:\MyProject" --yolo -- --custom-arg
     ```
   - **Supported flags:**
     - `--readonly`, `--read-only`, `--ro`, `--diff-only` -- Launch in Read-Only / Diff-Only mode.
     - `--yolo`, `--rw` -- Launch in Full YOLO (Read-Write) mode.
     - `--no-dialog` -- Skip the mode selection dialog (defaults to Read-Only if no mode flag is specified).
     - `--help`, `-h`, `/?` -- Show usage help and exit.
     - `--self-test` -- Run offline self-tests without starting Windows Sandbox.
     - `--` -- Forward all subsequent tokens verbatim to `agy`.
   - Any other unrecognized flags/arguments are passed directly through to `agy`.
3. **Choose Mode:** In the popup dialog, pick **Read-Only (Diff-Only)** or **Full YOLO (Read-Write)** and wait for Windows Terminal and `agy` to open (first run caches portable tools once; Read-Only mode copies the workspace to `C:\work` on launch). Leave the host console window open so it can wipe the staging token and merge your session history when done.
4. **Save and Exit:** Double-click the Desktop shortcut inside the sandbox (`Export_Changes_and_Close_Sandbox.cmd` in Read-Only mode or `Save_History_and_Close_Sandbox.cmd` in Full YOLO mode). This stops `agy`, checkpoints SQLite WAL, exports history (and Read-Only diffs), and shuts down the sandbox.

## Configuration

All tunable settings live in the `$Config` block at the top of `launch_safe_yolo_antigravity_in_windows_sandbox.cmd`, including:
- Pinned tool versions, URLs, and SHA-256 hashes (`Tools`), `InstallMinGit`, and `ToolsCacheDir`.
- Resource and `.wsb` isolation options (`MemoryInMB` defaulting to automatic `clamp(50% host RAM, 4096, 8192)`, `vGPU`, `Networking`, `ClipboardRedirection`, `ProtectedClient`, `PreferWsbCli`).
- Sync and execution options (`AutosaveIntervalMinutes`, `SyncKnowledgeBack`, `SyncAllowListDirs`, `GeminiCopyExcludeDirs`, `GeminiCopyExcludeFiles`, `CreateHostProfileJunction`, `ExtraAgyArgs`, `TokenTimeoutSeconds`).

## Security Model

### What IS Isolated
- **Host OS & Host `.gemini`:** Host OS, Registry, installed apps, and host `.gemini` config (`settings.json`, plugins, MCP definitions, `GEMINI.md`, `trustedFolders.json`, `knowledge/`) are protected from sandbox writes.
- **Read-Only Bootstrap & Tools:** Both `C:\agy-bootstrap` and `C:\agy-tools` are mapped read-only; outbox ingestion rejects NTFS junctions/symlinks and path traversal.
- **Dangerous Roots:** Guardrails warn and block accidental launching on `Downloads`, `Desktop`, `Documents`, `%USERPROFILE%`, drive roots, and OS/program folders.

### What Is NOT Isolated (Read Carefully)
- **Antigravity Token & Network Access:** Inside the sandbox, `agy` uses your bridged `gemini:antigravity` credential and has outbound internet access (required to reach AI APIs and MCP servers).
- **Project Files in Full YOLO Mode:** In **Full YOLO (Read-Write)** mode, the mapped project directory is writable. A prompt-injected or misbehaving agent can modify or delete files inside that folder, or modify `.git\hooks\*` / `.vscode\tasks.json` that run on your host later. **Use Read-Only Mode or version control**, and inspect `git status` / `.git\hooks` before running host scripts afterward.

## Troubleshooting

- **"Could not read credential 'gemini:antigravity'":** Log into `agy` at least once on the host machine first (`agy` stores its token in Windows Credential Manager).
- **"Windows Sandbox is not enabled":** Enable Windows Sandbox in *"Turn Windows features on or off"* and ensure CPU virtualization (VT-x / AMD-V) is enabled in BIOS/UEFI.
- **Bootstrap issues inside Sandbox:** Inspect `Desktop\agy-bootstrap.log` inside the sandbox for exact step-by-step errors and robocopy exit codes.
- **Concurrent host `agy.exe` & SQLite merge:** If `agy.exe` is running on the host when the sandbox closes, the launcher warns and waits for you to close host `agy.exe` (or lets you type `S` to skip the DB merge) before safely merging `conversation_summaries.db` (saving a `.bak` backup first).
- **vSMB Symlink & Git Behavior:** In Full YOLO mode (`C:\workspace`), the project runs over Windows Sandbox vSMB, which has limited NTFS symlink/file-lock support. Read-Only mode copies the workspace to native `C:\work`, avoiding vSMB quirks completely.
- **Project History / `agy --continue` Path Mismatch:** Conversations created inside the sandbox record `C:\workspace` (or `C:\work`) as their working directory rather than the host folder path, so host `agy --continue` may not automatically filter them to the host project path; look them up by conversation ID/history instead.
- **Windows Terminal Fallback:** On stripped Windows 11 24H2+ Sandbox images lacking the VC++ Runtime, if unpackaged `wt.exe` fails to start, the launcher automatically falls back to PowerShell 7 (`pwsh.exe`).

## Disclaimer

While Windows Sandbox isolates your *host operating system* and Read-Only mode protects your *project files*, running an AI in **Full YOLO (Read-Write)** mode grants `--dangerously-skip-permissions` over the mapped project directory. By using this script, you assume all risk for modified or deleted workspace files. Always use Read-Only mode or version control.

## License

Released under the [MIT License](LICENSE).
