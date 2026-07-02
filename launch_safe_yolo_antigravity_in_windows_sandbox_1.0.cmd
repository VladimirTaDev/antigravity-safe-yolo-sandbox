@echo off
setlocal

:: ==============================================================================
:: Antigravity Safe YOLO Sandbox Launcher
:: 
:: Version: 1.0
:: Made by: https://github.com/VladimirTaDev
:: Email: d2lq6sw3@duck.com
::
:: Description: 
:: This script safely launches Google Antigravity (agy) in YOLO mode inside an 
:: isolated Windows Sandbox. It automatically bridges your host authentication, 
:: synchronizes your history, installs Node.js, PowerShell 7, and Windows Terminal 
:: for a flawless native-feeling TUI experience—all without risking your host OS.
:: ==============================================================================

echo [Init] Setting up temporary paths and checking prerequisites...

:: Autodetect current project path (the directory where this script lives)
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

:: Define host paths for Antigravity data
set "GEMINI_DIR=%USERPROFILE%\.gemini"
set "AGY_DIR=%LOCALAPPDATA%\agy"

:: Define temporary bootstrap directory on the host
set "TMP_DIR_NAME=agy_yolo_helpers"
set "TMP_DIR=%TEMP%\%TMP_DIR_NAME%"

:: Create necessary directories
mkdir "%TMP_DIR%" 2>nul
mkdir "%GEMINI_DIR%" 2>nul

:: ------------------------------------------------------------------------------
:: 1. Host Credential Extraction Script (PowerShell)
:: ------------------------------------------------------------------------------
:: This script extracts the agy authentication token from the Host's Credential 
:: Manager so it can be passed securely into the Sandbox.
type nul > "%TMP_DIR%\extract_cred.ps1"
>>"%TMP_DIR%\extract_cred.ps1" echo # Extract the "gemini:antigravity" credential from Windows Credential Manager
>>"%TMP_DIR%\extract_cred.ps1" echo Add-Type -TypeDefinition @'
>>"%TMP_DIR%\extract_cred.ps1" echo using System;
>>"%TMP_DIR%\extract_cred.ps1" echo using System.Runtime.InteropServices;
>>"%TMP_DIR%\extract_cred.ps1" echo using System.Text;
>>"%TMP_DIR%\extract_cred.ps1" echo public class CredentialReader {
>>"%TMP_DIR%\extract_cred.ps1" echo     [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
>>"%TMP_DIR%\extract_cred.ps1" echo     static extern bool CredReadW(string target, int type, int reserved, out IntPtr cred);
>>"%TMP_DIR%\extract_cred.ps1" echo     [DllImport("advapi32.dll")]
>>"%TMP_DIR%\extract_cred.ps1" echo     static extern void CredFree(IntPtr cred);
>>"%TMP_DIR%\extract_cred.ps1" echo     [StructLayout(LayoutKind.Sequential)]
>>"%TMP_DIR%\extract_cred.ps1" echo     struct CREDENTIAL {
>>"%TMP_DIR%\extract_cred.ps1" echo         public int Flags;
>>"%TMP_DIR%\extract_cred.ps1" echo         public int Type;
>>"%TMP_DIR%\extract_cred.ps1" echo         public IntPtr TargetName;
>>"%TMP_DIR%\extract_cred.ps1" echo         public IntPtr Comment;
>>"%TMP_DIR%\extract_cred.ps1" echo         public long LastWritten;
>>"%TMP_DIR%\extract_cred.ps1" echo         public int CredentialBlobSize;
>>"%TMP_DIR%\extract_cred.ps1" echo         public IntPtr CredentialBlob;
>>"%TMP_DIR%\extract_cred.ps1" echo         public int Persist;
>>"%TMP_DIR%\extract_cred.ps1" echo         public int AttributeCount;
>>"%TMP_DIR%\extract_cred.ps1" echo         public IntPtr Attributes;
>>"%TMP_DIR%\extract_cred.ps1" echo         public IntPtr TargetAlias;
>>"%TMP_DIR%\extract_cred.ps1" echo         public IntPtr UserName;
>>"%TMP_DIR%\extract_cred.ps1" echo     }
>>"%TMP_DIR%\extract_cred.ps1" echo     public static string Read(string target) {
>>"%TMP_DIR%\extract_cred.ps1" echo         IntPtr ptr;
>>"%TMP_DIR%\extract_cred.ps1" echo         if (!CredReadW(target, 1, 0, out ptr)) return "";
>>"%TMP_DIR%\extract_cred.ps1" echo         CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
>>"%TMP_DIR%\extract_cred.ps1" echo         byte[] blob = new byte[cred.CredentialBlobSize];
>>"%TMP_DIR%\extract_cred.ps1" echo         Marshal.Copy(cred.CredentialBlob, blob, 0, cred.CredentialBlobSize);
>>"%TMP_DIR%\extract_cred.ps1" echo         CredFree(ptr);
>>"%TMP_DIR%\extract_cred.ps1" echo         return Encoding.UTF8.GetString(blob);
>>"%TMP_DIR%\extract_cred.ps1" echo     }
>>"%TMP_DIR%\extract_cred.ps1" echo }
>>"%TMP_DIR%\extract_cred.ps1" echo '@
>>"%TMP_DIR%\extract_cred.ps1" echo $token = [CredentialReader]::Read("gemini:antigravity")
>>"%TMP_DIR%\extract_cred.ps1" echo if ($token -eq "") {
>>"%TMP_DIR%\extract_cred.ps1" echo     Write-Error "Failed to read credential 'gemini:antigravity' from Credential Manager"
>>"%TMP_DIR%\extract_cred.ps1" echo     exit 1
>>"%TMP_DIR%\extract_cred.ps1" echo }
>>"%TMP_DIR%\extract_cred.ps1" echo [System.IO.File]::WriteAllText("$PSScriptRoot\keyring_token.txt", $token)
>>"%TMP_DIR%\extract_cred.ps1" echo Write-Host "  Credential extracted successfully."

:: ------------------------------------------------------------------------------
:: 2. Sandbox Credential Injection Script (PowerShell)
:: ------------------------------------------------------------------------------
:: This script runs inside the Sandbox to inject the token back into the 
:: Sandbox's isolated Credential Manager.
type nul > "%TMP_DIR%\inject_cred.ps1"
>>"%TMP_DIR%\inject_cred.ps1" echo # Inject the "gemini:antigravity" credential into Windows Credential Manager
>>"%TMP_DIR%\inject_cred.ps1" echo Add-Type -TypeDefinition @'
>>"%TMP_DIR%\inject_cred.ps1" echo using System;
>>"%TMP_DIR%\inject_cred.ps1" echo using System.Runtime.InteropServices;
>>"%TMP_DIR%\inject_cred.ps1" echo using System.Text;
>>"%TMP_DIR%\inject_cred.ps1" echo public class CredentialWriter {
>>"%TMP_DIR%\inject_cred.ps1" echo     [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
>>"%TMP_DIR%\inject_cred.ps1" echo     static extern bool CredWriteW(IntPtr cred, int flags);
>>"%TMP_DIR%\inject_cred.ps1" echo     [StructLayout(LayoutKind.Sequential)]
>>"%TMP_DIR%\inject_cred.ps1" echo     public struct CREDENTIAL {
>>"%TMP_DIR%\inject_cred.ps1" echo         public int Flags;
>>"%TMP_DIR%\inject_cred.ps1" echo         public int Type;
>>"%TMP_DIR%\inject_cred.ps1" echo         [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
>>"%TMP_DIR%\inject_cred.ps1" echo         [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
>>"%TMP_DIR%\inject_cred.ps1" echo         public long LastWritten;
>>"%TMP_DIR%\inject_cred.ps1" echo         public int CredentialBlobSize;
>>"%TMP_DIR%\inject_cred.ps1" echo         public IntPtr CredentialBlob;
>>"%TMP_DIR%\inject_cred.ps1" echo         public int Persist;
>>"%TMP_DIR%\inject_cred.ps1" echo         public int AttributeCount;
>>"%TMP_DIR%\inject_cred.ps1" echo         public IntPtr Attributes;
>>"%TMP_DIR%\inject_cred.ps1" echo         [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
>>"%TMP_DIR%\inject_cred.ps1" echo         [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
>>"%TMP_DIR%\inject_cred.ps1" echo     }
>>"%TMP_DIR%\inject_cred.ps1" echo     public static bool Write(string target, string user, string secret) {
>>"%TMP_DIR%\inject_cred.ps1" echo         byte[] blob = Encoding.UTF8.GetBytes(secret);
>>"%TMP_DIR%\inject_cred.ps1" echo         CREDENTIAL cred = new CREDENTIAL();
>>"%TMP_DIR%\inject_cred.ps1" echo         cred.Type = 1;
>>"%TMP_DIR%\inject_cred.ps1" echo         cred.TargetName = target;
>>"%TMP_DIR%\inject_cred.ps1" echo         cred.UserName = user;
>>"%TMP_DIR%\inject_cred.ps1" echo         cred.CredentialBlobSize = blob.Length;
>>"%TMP_DIR%\inject_cred.ps1" echo         cred.Persist = 2;
>>"%TMP_DIR%\inject_cred.ps1" echo         cred.CredentialBlob = Marshal.AllocHGlobal(blob.Length);
>>"%TMP_DIR%\inject_cred.ps1" echo         Marshal.Copy(blob, 0, cred.CredentialBlob, blob.Length);
>>"%TMP_DIR%\inject_cred.ps1" echo         IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf(cred));
>>"%TMP_DIR%\inject_cred.ps1" echo         Marshal.StructureToPtr(cred, ptr, false);
>>"%TMP_DIR%\inject_cred.ps1" echo         bool ok = CredWriteW(ptr, 0);
>>"%TMP_DIR%\inject_cred.ps1" echo         Marshal.FreeHGlobal(cred.CredentialBlob);
>>"%TMP_DIR%\inject_cred.ps1" echo         Marshal.FreeHGlobal(ptr);
>>"%TMP_DIR%\inject_cred.ps1" echo         return ok;
>>"%TMP_DIR%\inject_cred.ps1" echo     }
>>"%TMP_DIR%\inject_cred.ps1" echo }
>>"%TMP_DIR%\inject_cred.ps1" echo '@
>>"%TMP_DIR%\inject_cred.ps1" echo $tokenFile = Join-Path $PSScriptRoot "keyring_token.txt"
>>"%TMP_DIR%\inject_cred.ps1" echo $token = (Get-Content $tokenFile -Raw).Trim()
>>"%TMP_DIR%\inject_cred.ps1" echo if ([CredentialWriter]::Write("gemini:antigravity", "antigravity", $token)) {
>>"%TMP_DIR%\inject_cred.ps1" echo     Write-Host "  Credential injected successfully."
>>"%TMP_DIR%\inject_cred.ps1" echo } else {
>>"%TMP_DIR%\inject_cred.ps1" echo     Write-Error "CredWriteW failed"
>>"%TMP_DIR%\inject_cred.ps1" echo     exit 1
>>"%TMP_DIR%\inject_cred.ps1" echo }

:: ------------------------------------------------------------------------------
:: 3. Extract Keyring Credential
:: ------------------------------------------------------------------------------
echo [Init] Extracting authentication from Windows Credential Manager...
powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP_DIR%\extract_cred.ps1"
if not exist "%TMP_DIR%\keyring_token.txt" (
    echo ERROR: Could not extract credentials. Make sure you are logged into agy first.
    pause
    exit /b 1
)

:: ------------------------------------------------------------------------------
:: 4. Generate Sandbox Closure Shortcut
:: ------------------------------------------------------------------------------
:: This script is placed on the Sandbox Desktop. When clicked, it synchronizes 
:: conversation history back to the host and securely shuts down the Sandbox.
type nul > "%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd"
>>"%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd" echo @echo off
>>"%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd" echo title Saving and Closing...
>>"%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd" echo echo Saving history and settings to host...
:: Using /E instead of /MIR ensures additive syncing (prevents deleting concurrent host conversations)
>>"%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd" echo robocopy "%%USERPROFILE%%\.gemini" "C:\host-gemini-config" /E /XO /FFT /R:0 /W:0 ^>nul
>>"%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd" echo echo Terminating Sandbox...
>>"%TMP_DIR%\Close_Sandbox_Preserving_agy_history_and_settings.cmd" echo shutdown /p

:: ------------------------------------------------------------------------------
:: 5. Generate Sandbox Bootstrap Initialization Script
:: ------------------------------------------------------------------------------
:: This is the primary logon script executed inside the Sandbox to provision the 
:: environment.
type nul > "%TMP_DIR%\sandbox-init.cmd"
>>"%TMP_DIR%\sandbox-init.cmd" echo @echo off
>>"%TMP_DIR%\sandbox-init.cmd" echo title Bootstrapping Antigravity YOLO Environment...
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [1/9] Installing Node.js for MCP Servers...
>>"%TMP_DIR%\sandbox-init.cmd" echo curl -fsSL https://nodejs.org/dist/v20.15.0/node-v20.15.0-x64.msi -o %%TEMP%%\nodejs.msi
>>"%TMP_DIR%\sandbox-init.cmd" echo start /wait msiexec /i %%TEMP%%\nodejs.msi /quiet /norestart
>>"%TMP_DIR%\sandbox-init.cmd" echo del %%TEMP%%\nodejs.msi
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [2/9] Installing Antigravity CLI...
>>"%TMP_DIR%\sandbox-init.cmd" echo if not exist "%%LOCALAPPDATA%%\agy\bin\agy.exe" goto install_agy
>>"%TMP_DIR%\sandbox-init.cmd" echo echo    agy binary already present, skipping download.
>>"%TMP_DIR%\sandbox-init.cmd" echo goto skip_agy
>>"%TMP_DIR%\sandbox-init.cmd" echo :install_agy
>>"%TMP_DIR%\sandbox-init.cmd" echo curl -fsSL https://antigravity.google/cli/install.cmd -o %%TEMP%%\install.cmd
>>"%TMP_DIR%\sandbox-init.cmd" echo call %%TEMP%%\install.cmd
>>"%TMP_DIR%\sandbox-init.cmd" echo del %%TEMP%%\install.cmd
>>"%TMP_DIR%\sandbox-init.cmd" echo :skip_agy
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [3/9] Copying .gemini configuration locally to avoid SQLite vSMB locks...
>>"%TMP_DIR%\sandbox-init.cmd" echo xcopy /E /I /Y /H C:\host-gemini-config "%%USERPROFILE%%\.gemini" ^>nul 2^>^&1
>>"%TMP_DIR%\sandbox-init.cmd" echo attrib -R "%%USERPROFILE%%\.gemini\*.*" /S /D ^>nul 2^>^&1
>>"%TMP_DIR%\sandbox-init.cmd" echo echo    Config copied.
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [4/9] Injecting authentication into Credential Manager...
>>"%TMP_DIR%\sandbox-init.cmd" echo powershell -NoProfile -ExecutionPolicy Bypass -File "C:\agy-bootstrap\inject_cred.ps1"
>>"%TMP_DIR%\sandbox-init.cmd" echo echo    Done.
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [5/9] Adding agy to PATH...
>>"%TMP_DIR%\sandbox-init.cmd" echo set "PATH=%%LOCALAPPDATA%%\agy\bin;%%PATH%%"
>>"%TMP_DIR%\sandbox-init.cmd" echo setx PATH "%%LOCALAPPDATA%%\agy\bin;%%PATH%%" ^>nul
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [6/9] Installing PowerShell 7...
>>"%TMP_DIR%\sandbox-init.cmd" echo curl -fsSL -L https://github.com/PowerShell/PowerShell/releases/download/v7.4.3/PowerShell-7.4.3-win-x64.msi -o %%TEMP%%\pwsh.msi
>>"%TMP_DIR%\sandbox-init.cmd" echo start /wait msiexec /i %%TEMP%%\pwsh.msi /quiet /norestart
>>"%TMP_DIR%\sandbox-init.cmd" echo del %%TEMP%%\pwsh.msi
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [7/9] Installing Windows Terminal...
>>"%TMP_DIR%\sandbox-init.cmd" echo curl -fsSL -L https://github.com/microsoft/terminal/releases/download/v1.20.11271.0/Microsoft.WindowsTerminal_1.20.11271.0_x64.zip -o %%TEMP%%\wt.zip
>>"%TMP_DIR%\sandbox-init.cmd" echo powershell -NoProfile -Command "Expand-Archive -Force -Path $env:TEMP\wt.zip -DestinationPath C:\wt_temp"
>>"%TMP_DIR%\sandbox-init.cmd" echo xcopy /E /I /Y C:\wt_temp\terminal-1.20.11271.0 C:\wt ^>nul
>>"%TMP_DIR%\sandbox-init.cmd" echo del %%TEMP%%\wt.zip
>>"%TMP_DIR%\sandbox-init.cmd" echo rd /s /q C:\wt_temp
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [8/9] Launching YOLO mode in Windows Terminal...
>>"%TMP_DIR%\sandbox-init.cmd" echo cd /d C:\workspace
>>"%TMP_DIR%\sandbox-init.cmd" echo start "" "C:\wt\wt.exe" --window 0 -d C:\workspace "C:\Program Files\PowerShell\7\pwsh.exe" -NoExit -Command "& '%%LOCALAPPDATA%%\agy\bin\agy.exe' --dangerously-skip-permissions"
>>"%TMP_DIR%\sandbox-init.cmd" echo.
>>"%TMP_DIR%\sandbox-init.cmd" echo echo [9/9] Creating Desktop Shortcut and Cleanup...
>>"%TMP_DIR%\sandbox-init.cmd" echo copy /Y "C:\agy-bootstrap\Close_Sandbox_Preserving_agy_history_and_settings.cmd" "%%USERPROFILE%%\Desktop\" ^>nul
:: The script deletes its own folder contents to clean up host's %TEMP% and leaves no footprint
>>"%TMP_DIR%\sandbox-init.cmd" echo (goto) 2^>nul ^& del /f /q C:\agy-bootstrap\*.* 2^>nul

:: ------------------------------------------------------------------------------
:: 6. Generate Windows Sandbox Configuration (.wsb)
:: ------------------------------------------------------------------------------
type nul > "%TEMP%\yolo-sandbox.wsb"
>>"%TEMP%\yolo-sandbox.wsb" echo ^<Configuration^>
>>"%TEMP%\yolo-sandbox.wsb" echo   ^<MappedFolders^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^<MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<HostFolder^>%PROJECT_DIR%^</HostFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<SandboxFolder^>C:\workspace^</SandboxFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<ReadOnly^>false^</ReadOnly^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^</MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^<MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<HostFolder^>%GEMINI_DIR%^</HostFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<SandboxFolder^>C:\host-gemini-config^</SandboxFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<ReadOnly^>false^</ReadOnly^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^</MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^<MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<HostFolder^>%AGY_DIR%^</HostFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<SandboxFolder^>C:\Users\WDAGUtilityAccount\AppData\Local\agy^</SandboxFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<ReadOnly^>true^</ReadOnly^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^</MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^<MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<HostFolder^>%TMP_DIR%^</HostFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<SandboxFolder^>C:\agy-bootstrap^</SandboxFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo       ^<ReadOnly^>false^</ReadOnly^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^</MappedFolder^>
>>"%TEMP%\yolo-sandbox.wsb" echo   ^</MappedFolders^>
>>"%TEMP%\yolo-sandbox.wsb" echo   ^<LogonCommand^>
>>"%TEMP%\yolo-sandbox.wsb" echo     ^<Command^>C:\agy-bootstrap\sandbox-init.cmd^</Command^>
>>"%TEMP%\yolo-sandbox.wsb" echo   ^</LogonCommand^>
>>"%TEMP%\yolo-sandbox.wsb" echo ^</Configuration^>

:: ------------------------------------------------------------------------------
:: 7. Launch the Sandbox
:: ------------------------------------------------------------------------------
echo [Init] Launching Windows Sandbox...
start "" "%TEMP%\yolo-sandbox.wsb"
exit
