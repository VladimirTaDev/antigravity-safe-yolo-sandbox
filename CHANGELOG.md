# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- **SQLite Data Integrity**: The Desktop "Close Sandbox" shortcut now explicitly forcefully kills all `agy.exe` and `pwsh.exe` processes *before* running the history sync, guaranteeing that SQLite releases all vSMB file locks and commits its WAL files safely.

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
