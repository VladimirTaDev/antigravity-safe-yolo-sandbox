# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-11-23

### Added
- **Read-Only / Diff-Only Mode & Interactive Mode Selection Dialog:** Added a Windows Forms mode picker (with console fallback and `--readonly` / `--read-only` / `--ro` / `--diff-only` / `--yolo` / `--rw` / `--no-dialog` CLI flags). Read-Only mode maps the project read-only, works in a native sandbox copy (`C:\work`), and exports a `.patch` diff plus added/modified/deleted file details to `%TEMP%\agy-yolo-patches\`.
- **Host Pre-Extracted Portable Tool Cache (`%LOCALAPPDATA%\agy-yolo-sandbox\tools`):** Downloads, SHA-256 verifies, and extracts portable ZIPs once on the host (in parallel via `curl.exe --retry 3`), then maps them read-only (`C:\agy-tools`), reducing sandbox boot time dramatically with zero `msiexec` overhead.
- **ARM64 Architecture Support:** Added verified SHA-256 checksums and download URLs for both `x64` (`AMD64`) and `arm64` (`ARM64`).
- **Portable MinGit Integration:** Automatically provisions MinGit inside the sandbox with `safe.directory '*'` and `core.longpaths true`.
- **Windows 11 24H2 `wsb.exe` CLI Support:** Uses `wsb.exe start --config` (with single-line XML) + `wsb.exe connect` when available, cleaning up orphaned headless sandboxes if `connect` fails and falling back cleanly to direct `WindowsSandbox.exe` invocation with early non-zero exit detection.
- **Host Compatibility Junction & Pass-Through Arguments:** Creates an optional in-sandbox `C:\Users\<HostUser>\.gemini` junction for host-absolute plugin paths, forwards extra arguments (e.g., `--continue`, `--model`, or verbatim args after `--`) safely via JSON into `agy`, and supports dragging a project folder onto the launcher.
- **Dangerous Root Guardrail & Built-in `--self-test`:** Blocks accidental mapping of `Downloads`, `Desktop`, `Documents`, `%USERPROFILE%`, drive roots, and system/application directories unless explicitly confirmed; adds offline `--self-test` verification.
- **Safe Non-SQLite Periodic Autosave:** Periodically copies `brain`, `conversations`, `annotations`, and `history.jsonl` (excluding `.db`/`.db-wal`/`.db-shm`) into the outbox so closing via the window **X** retains recent session data.
- **Repository Metadata:** Added MIT `LICENSE` and `.gitattributes` enforcing CRLF for Windows scripts and LF for Markdown/license files.

### Changed
- **Single-File Polyglot Architecture & Unversioned Filename:** Converted to a clean 7-bit ASCII, CRLF `.cmd` + PowerShell polyglot named `launch_safe_yolo_antigravity_in_windows_sandbox.cmd` (replacing `launch_safe_yolo_antigravity_in_windows_sandbox_1.1.cmd`) with a top `$Config` block and zero fragile nested batch `echo` escaping.
- **Hardened Sandbox Isolation:** Host `.gemini` and `C:\agy-bootstrap` are now mapped **read-only**; only `C:\agy-outbox` is writable. Host `extract` logic runs in memory and never enters the sandbox. Host merge rejects reparse points/symlinks (`Test-SafeOutboxTree`), checks path containment, excludes `knowledge/` from silent auto-merge, merges `history.jsonl` line-by-line, and merges `conversation_summaries.db` rows safely via Node 24's built-in `node:sqlite`.
- **Updated Component Versions (LTS):** Upgraded Node.js `20.15.0` (EOL) -> `24.22.3` LTS, PowerShell `7.4.3` (EOL) -> `7.6.10` LTS, Windows Terminal `1.20.11271.0` -> `1.25.3131.0`, and added MinGit `2.56.1`.
- **Hardened `.wsb` XML Generation:** Switched to UTF-8 (no BOM) `XmlWriter` supporting `&`, `!`, Unicode usernames/paths, and drive roots (`D:\`), with dynamic host RAM scaling (`clamp(50%, 4096, 8192)`), disabled audio/video/printer redirection, and explicit `<Networking>`.

### Fixed
- **Corrected 1.1.0 SQLite / `taskkill` Escaping Bug:** In v1.1.0, `2^^^>nul` wrote `2^>nul` into the generated closer script, causing `taskkill` to fail with `Invalid argument/option - '2>nul'` so `agy.exe` stayed running during sync. Fixed process termination (including ancestor-PID protection so invoking closer from `pwsh` won't self-kill) and added explicit `PRAGMA wal_checkpoint(TRUNCATE);` via `node:sqlite`.
- **Temporary Staging ACLs for Windows Sandbox Services (`0x80070005`):** Updated per-run staging ACL hardening (`Set-PrivateRunDirAcl`) to use universal language-independent SIDs granting `NT AUTHORITY\SYSTEM`, `BUILTIN\Administrators`, and the current user while stripping `Everyone` and `Users`, preventing `E_ACCESSDENIED` from Windows Sandbox host services.
- **Credential Bridging Fixes:** Preserved actual `UserName` from host Credential Manager, fixed unmanaged pointer/string leaks and null-blob crashes in P/Invoke, and guaranteed token zero-overwriting + deletion immediately upon `cred_ok.flag`, timeout, abort, or `Ctrl+C`.
- **Startup & Shutdown Reliability Fixes:** Replaced `xcopy` (which aborted on access-denied dirs like `updater`) with `robocopy /XJ`, fixed `timeout /t 5` stdin-redirection race when deleting `.wsb`, invoked `WindowsSandbox.exe` directly instead of via file association, checked download exit codes before hashing, waited for sandbox DNS readiness, preserved `REG_EXPAND_SZ` in sandbox User `Path`, prevented concurrent sandbox collisions, added Windows Terminal VC++ runtime fallback to `pwsh.exe`, and refused to shut down the VM if final outbox export fails.

## [1.1.0] - 2026-07-02

### Added
- **Supply Chain Security**: Implemented strict SHA256 cryptographic hash verification for all dynamically downloaded tools (Node.js, PowerShell 7, Windows Terminal) to prevent man-in-the-middle attacks.
- **Robust Error Handling**: Added explicit exit codes and error checks for all sandbox setup stages.
- **Preflight Checks**: The script now verifies that Windows Sandbox is enabled and Antigravity is installed on the host before launching.
- **Delayed Cleanup**: The host script now cleans up the ephemeral `%TEMP%\yolo-sandbox.wsb` file immediately after launch.

### Changed
- **Token Security (Base64)**: Credential bridging now natively serializes the authentication blob as raw Base64 bytes instead of UTF-8, entirely fixing a potential corruption bug with UTF-16LE Windows credentials.
- **Aggressive Token Deletion**: The temporary authentication token is now forcefully deleted from the disk the exact millisecond it is successfully injected into the Sandbox's Credential Manager.
- **Safe PATH Modification**: Fixed a critical Windows `setx` bug that could have permanently truncated the User PATH. It now uses a safe PowerShell command to append to the PATH natively.
- **SQLite Data Integrity**: *(Note: later identified as broken in 1.1.0 due to `2^^^>nul` escaping in `taskkill` and fixed in 2.0.0.)* The Desktop "Close Sandbox" shortcut attempted to kill `agy.exe` and `pwsh.exe` processes before running history sync.

## [1.0.0] - 2026-07-02

### Added
- Initial release of the automated sandbox launcher for Google Antigravity.
- Integrated automated Windows Credential Manager token extraction (Host) and injection (Sandbox) to enable seamless login bridging.
- Added automatic installation of Node.js to ensure local MCP (Model Context Protocol) servers function properly out of the box.
- Added automatic installation of PowerShell 7 for improved terminal scripting compatibility.
- Implemented automatic deployment of the standalone Windows Terminal (`wt.exe`) to resolve legacy `conhost.exe` TUI rendering bugs (phantom spaces and character overwrite issues).
- Implemented robust `robocopy /E` synchronization algorithm for `.gemini` configs to prevent concurrent host-conversation deletion while merging history safely.
- Added desktop shortcut generator (`Close_Sandbox_Preserving_agy_history_and_settings.cmd`) for clean data synchronization and VM termination.
- Implemented zero-footprint temporary file architecture using an ephemeral `%TEMP%` mapping to prevent workspace file lock crashes.
