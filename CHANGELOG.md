# Changelog

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
