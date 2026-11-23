@echo off
setlocal
:: ==============================================================================
:: Antigravity Safe YOLO Sandbox Launcher
::
:: Version: 2.0.0
:: Made by: https://github.com/VladimirTaDev
:: Email: d2lq6sw3@duck.com
::
:: Description:
:: Single-file polyglot (.cmd + PowerShell) that safely launches Google
:: Antigravity (agy) inside an isolated Windows Sandbox in either Read-Only
:: (Diff-Only) mode or Full YOLO (Read-Write) mode. Leaves zero files in the
:: target project directory. Keep CRLF line endings and 7-bit ASCII encoding.
:: ==============================================================================
set "AGY_LAUNCHER_FILE=%~f0"
set "AGY_LAUNCHER_DIR=%~dp0"
set AGY_CMDLINE=%*
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS_EXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText($env:AGY_LAUNCHER_FILE); $m='# === '+'AGY_PS_BODY ==='; $i=$c.IndexOf($m); if($i -lt 0){throw 'Corrupt launcher file'}; & ([scriptblock]::Create($c.Substring($i)))"
exit /b %ERRORLEVEL%
# === AGY_PS_BODY ===

$ErrorActionPreference = 'Stop'
$global:LASTEXITCODE = 0
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ------------------------------------------------------------------------------
# User Configuration Block (edit values here to customize behavior/versions)
# ------------------------------------------------------------------------------
$Config = [ordered]@{
    Version                   = '2.0.0'
    CredentialTarget          = 'gemini:antigravity'
    ToolsCacheDir             = Join-Path $env:LOCALAPPDATA 'agy-yolo-sandbox\tools'
    PatchExportRoot           = Join-Path $env:TEMP 'agy-yolo-patches'
    InstallMinGit             = $true
    CreateHostProfileJunction = $true
    AutosaveIntervalMinutes   = 3
    SyncKnowledgeBack         = $false
    SyncAllowListDirs         = @(
        'antigravity-cli\brain',
        'antigravity-cli\conversations',
        'antigravity-cli\annotations'
    )
    GeminiCopyExcludeDirs     = @(
        'updater',
        'daemon',
        'crashes',
        'log',
        'cache',
        'tmp',
        'antigravity-browser-profile'
    )
    GeminiCopyExcludeFiles    = @()
    ExtraAgyArgs              = @()
    MemoryInMB                = 0          # 0 = auto: clamp(50% host RAM, 4096, 8192)
    vGPU                      = 'Default'  # 'Default', 'Enable', or 'Disable'
    Networking                = 'Enable'   # 'Enable' or 'Disable'
    ClipboardRedirection      = 'Enable'   # 'Enable' or 'Disable'
    AudioInput                = 'Disable'
    VideoInput                = 'Disable'
    PrinterRedirection        = 'Disable'
    ProtectedClient           = 'Default'  # 'Default', 'Enable', or 'Disable'
    PreferWsbCli              = $true
    TokenTimeoutSeconds       = 180
    Tools = [ordered]@{
        node = [ordered]@{
            Version  = '24.22.3'
            Sentinel = 'node.exe'
            x64 = [ordered]@{
                Url    = 'https://nodejs.org/dist/v24.22.3/node-v24.22.3-win-x64.zip'
                Sha256 = 'E612AF99F626AB415EA225AF6BCE5C971FEB448CB5CAE250BB1C3FA50C5F7D9F'
            }
            arm64 = [ordered]@{
                Url    = 'https://nodejs.org/dist/v24.22.3/node-v24.22.3-win-arm64.zip'
                Sha256 = 'B3CC74A295B39D4F273271E96F58C06DD2B35757CA12ABEC64C7D0598B434F14'
            }
        }
        pwsh = [ordered]@{
            Version  = '7.6.10'
            Sentinel = 'pwsh.exe'
            x64 = [ordered]@{
                Url    = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.10/PowerShell-7.6.10-win-x64.zip'
                Sha256 = '7D871531806EB1646264E4BBABD9F0C30C23355591BC756BB9909448C29AE166'
            }
            arm64 = [ordered]@{
                Url    = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.10/PowerShell-7.6.10-win-arm64.zip'
                Sha256 = '1D36ECAC1D8F5AC9577CFDFC426AF41F3E90CBCA6C52445E7DB167F532B3A7AB'
            }
        }
        wt = [ordered]@{
            Version  = '1.25.3131.0'
            Sentinel = 'wt.exe'
            x64 = [ordered]@{
                Url    = 'https://github.com/microsoft/terminal/releases/download/v1.25.3131.0/Microsoft.WindowsTerminal_1.25.3131.0_x64.zip'
                Sha256 = '273D6F1502ECA1B5BD95C43F5D4D7EC72CC503DF340102F8659717E5BEAD3437'
            }
            arm64 = [ordered]@{
                Url    = 'https://github.com/microsoft/terminal/releases/download/v1.25.3131.0/Microsoft.WindowsTerminal_1.25.3131.0_arm64.zip'
                Sha256 = 'B7E1D2A414E6368AFFD098D91A4CBA441DCACD3AB634A6F39C8E6F5490DEEF89'
            }
        }
        mingit = [ordered]@{
            Version  = '2.56.1'
            Sentinel = 'cmd\git.exe'
            x64 = [ordered]@{
                Url    = 'https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/MinGit-2.56.1-64-bit.zip'
                Sha256 = '4A92850B6E917DA4FD010669B614B55DCCF5B0EC333A534CC4BE4700DFEFDAFD'
            }
            arm64 = [ordered]@{
                Url    = 'https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/MinGit-2.56.1-arm64.zip'
                Sha256 = '96571E442E90523A90E5FD8661B4C4E43BC192910F3C6DB938816E6955B4CC8C'
            }
        }
    }
}

# ------------------------------------------------------------------------------
# Pure Helpers (Testable Offline)
# ------------------------------------------------------------------------------
function Show-HelpText {
    Write-Host @"
Antigravity Safe YOLO Sandbox Launcher v$($Config.Version)

Usage:
  launch_safe_yolo_antigravity_in_windows_sandbox.cmd [ProjectDir] [Options] [-- AgyArgs...]

Options:
  --readonly, --ro, --diff-only   Run in Read-Only / Diff-Only mode (exports patch to %TEMP%)
  --yolo, --rw                    Run in Full YOLO mode (project mapped Read-Write)
  --no-dialog                     Skip the mode selection dialog (defaults to Read-Only if unspecified)
  --help, -h, /?                  Show this help message
  --self-test                     Run offline verification self-tests and exit

Notes:
  - Drag and drop a project folder onto the .cmd file to launch outside your project folder.
  - Any unrecognized arguments are passed straight through to agy (e.g. --continue --model ...).
  - Zero files are ever written into your project directory by this launcher.
"@
}

function Split-CmdLine {
    param([AllowEmptyString()][string]$RawLine)
    $tokens = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($RawLine)) {
        return ,([string[]]@())
    }
    $sb = New-Object System.Text.StringBuilder
    $inQuotes = $false
    $hasToken = $false
    for ($i = 0; $i -lt $RawLine.Length; $i++) {
        $ch = $RawLine[$i]
        if ($ch -eq '"') {
            $inQuotes = -not $inQuotes
            $hasToken = $true
        } elseif ((-not $inQuotes) -and [char]::IsWhiteSpace($ch)) {
            if ($hasToken) {
                $tokens.Add($sb.ToString())
                $null = $sb.Clear()
                $hasToken = $false
            }
        } else {
            $null = $sb.Append($ch)
            $hasToken = $true
        }
    }
    if ($hasToken) {
        $tokens.Add($sb.ToString())
    }
    return ,([string[]]$tokens.ToArray())
}

function Normalize-DirPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $trimmed = $Path.Trim()
    if ($trimmed.Length -eq 2 -and $trimmed[1] -eq ':') {
        $trimmed += '\'
    }
    $full = [IO.Path]::GetFullPath($trimmed)
    if ($full.Length -gt 3 -and $full.EndsWith('\')) {
        $full = $full.TrimEnd('\')
    }
    return $full
}

function Get-HostArch {
    $candidates = @($env:PROCESSOR_ARCHITEW6432, $env:PROCESSOR_ARCHITECTURE)
    foreach ($arch in $candidates) {
        if ([string]::IsNullOrWhiteSpace($arch)) { continue }
        switch ($arch.ToUpperInvariant()) {
            'AMD64' { return 'x64' }
            'ARM64' { return 'arm64' }
        }
    }
    throw "Unsupported host CPU architecture: $($env:PROCESSOR_ARCHITECTURE). Only x64 (AMD64) and ARM64 are supported."
}

function Get-AutoMemoryInMB {
    param([int]$ConfiguredMB)
    if ($ConfiguredMB -gt 0) {
        return $ConfiguredMB
    }
    $totalMB = 8192
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        if ($cs -and $cs.TotalPhysicalMemory -gt 0) {
            $totalMB = [int][math]::Floor([double]$cs.TotalPhysicalMemory / 1MB)
        }
    } catch {
        $totalMB = 8192
    }
    $half = [int][math]::Floor($totalMB / 2)
    if ($half -lt 4096) { return 4096 }
    if ($half -gt 8192) { return 8192 }
    return $half
}

function Test-DangerousRootPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$GeminiDir
    )
    $norm = Normalize-DirPath $Path
    if ($norm -match '^[A-Za-z]:\\$') {
        return "Drive root ($norm)"
    }

    $exactList = New-Object System.Collections.Generic.List[string]
    foreach ($p in @(
        $env:USERPROFILE,
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('MyDocuments'),
        (Join-Path $env:USERPROFILE 'Downloads')
    )) {
        if (-not [string]::IsNullOrWhiteSpace($p)) {
            $exactList.Add((Normalize-DirPath $p))
        }
    }
    try {
        $usf = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
        if ($usf -and $usf.PSObject.Properties['{374DE290-123F-4565-9164-39C4925E467B}']) {
            $dl = [Environment]::ExpandEnvironmentVariables([string]$usf.'{374DE290-123F-4565-9164-39C4925E467B}')
            if (-not [string]::IsNullOrWhiteSpace($dl)) {
                $exactList.Add((Normalize-DirPath $dl))
            }
        }
    } catch {}

    foreach ($ex in $exactList) {
        if ([string]::Equals($norm, $ex, [StringComparison]::OrdinalIgnoreCase)) {
            return "Sensitive user root folder ($norm)"
        }
    }

    $prefixList = @(
        $env:SystemRoot,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:LOCALAPPDATA,
        $env:APPDATA,
        $GeminiDir
    )
    foreach ($rawPrefix in $prefixList) {
        if ([string]::IsNullOrWhiteSpace($rawPrefix)) { continue }
        $np = Normalize-DirPath $rawPrefix
        $npSlash = if ($np.EndsWith('\')) { $np } else { $np + '\' }
        if ([string]::Equals($norm, $np, [StringComparison]::OrdinalIgnoreCase) -or
            $norm.StartsWith($npSlash, [StringComparison]::OrdinalIgnoreCase)) {
            return "Protected system/application directory ($norm)"
        }
    }
    return $null
}

function Parse-LauncherArguments {
    param(
        [AllowEmptyCollection()][string[]]$Tokens,
        [Parameter(Mandatory = $true)][string]$DefaultDir
    )
    $result = [ordered]@{
        ProjectDir        = Normalize-DirPath $DefaultDir
        ProjectOverridden = $false
        RequestedMode     = $null
        NoDialog          = $false
        ShowHelp          = $false
        SelfTest          = $false
        PassThroughArgs   = New-Object System.Collections.Generic.List[string]
    }
    $afterDoubleDash = $false
    foreach ($tok in $Tokens) {
        if ([string]::IsNullOrEmpty($tok)) { continue }
        if ($afterDoubleDash) {
            $result.PassThroughArgs.Add($tok)
            continue
        }
        if ($tok -eq '--') {
            $afterDoubleDash = $true
            continue
        }
        $lower = $tok.ToLowerInvariant()
        if ($lower -eq '--yolo' -or $lower -eq '--rw') {
            $result.RequestedMode = 'yolo'
            continue
        } elseif ($lower -eq '--readonly' -or $lower -eq '--read-only' -or $lower -eq '--ro' -or $lower -eq '--diff-only') {
            $result.RequestedMode = 'readonly'
            continue
        } elseif ($lower -eq '--no-dialog') {
            $result.NoDialog = $true
            continue
        } elseif ($lower -eq '--help' -or $lower -eq '-h' -or $lower -eq '/?') {
            $result.ShowHelp = $true
            continue
        } elseif ($lower -eq '--self-test') {
            $result.SelfTest = $true
            continue
        }
        if ((-not $result.ProjectOverridden) -and (-not $tok.StartsWith('-')) -and ($tok -ne '/?')) {
            $isContainer = $false
            try { $isContainer = Test-Path -LiteralPath $tok -PathType Container } catch {}
            if ($isContainer) {
                $result.ProjectDir = Normalize-DirPath $tok
                $result.ProjectOverridden = $true
                continue
            }
            if ($tok -match '^[A-Za-z]:[\\/]|^\\\\') {
                throw "Project directory does not exist: '$tok'"
            }
        }
        $result.PassThroughArgs.Add($tok)
    }
    return $result
}

function Build-WsbXml {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][string]$ProjectDir,
        [Parameter(Mandatory = $true)][string]$GeminiDir,
        [Parameter(Mandatory = $true)][string]$AgyHostDir,
        [Parameter(Mandatory = $true)][string]$AgySandboxDir,
        [Parameter(Mandatory = $true)][string]$ToolsCacheDir,
        [Parameter(Mandatory = $true)][string]$BootstrapDir,
        [Parameter(Mandatory = $true)][string]$OutboxDir,
        [Parameter(Mandatory = $true)][int]$MemoryInMB,
        [Parameter(Mandatory = $true)][hashtable]$WsbSettings
    )
    $sw = New-Object System.IO.StringWriter
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.OmitXmlDeclaration = $true
    $xw = [System.Xml.XmlWriter]::Create($sw, $settings)
    try {
        $xw.WriteStartElement('Configuration')
        $xw.WriteElementString('vGPU', [string]$WsbSettings.vGPU)
        $xw.WriteElementString('Networking', [string]$WsbSettings.Networking)
        $xw.WriteElementString('ClipboardRedirection', [string]$WsbSettings.ClipboardRedirection)
        $xw.WriteElementString('AudioInput', [string]$WsbSettings.AudioInput)
        $xw.WriteElementString('VideoInput', [string]$WsbSettings.VideoInput)
        $xw.WriteElementString('PrinterRedirection', [string]$WsbSettings.PrinterRedirection)
        if ($WsbSettings.ProtectedClient -in @('Enable', 'Disable')) {
            $xw.WriteElementString('ProtectedClient', [string]$WsbSettings.ProtectedClient)
        }
        $xw.WriteElementString('MemoryInMB', [string]$MemoryInMB)

        $wsTarget = if ($Mode -eq 'readonly') { 'C:\workspace-ro' } else { 'C:\workspace' }
        $wsReadOnly = if ($Mode -eq 'readonly') { 'true' } else { 'false' }

        $mappings = @(
            @{ Host = $ProjectDir;    Sandbox = $wsTarget;               RO = $wsReadOnly },
            @{ Host = $GeminiDir;     Sandbox = 'C:\host-gemini-config'; RO = 'true' },
            @{ Host = $AgyHostDir;    Sandbox = $AgySandboxDir;          RO = 'true' },
            @{ Host = $ToolsCacheDir; Sandbox = 'C:\agy-tools';          RO = 'true' },
            @{ Host = $BootstrapDir;  Sandbox = 'C:\agy-bootstrap';      RO = 'true' },
            @{ Host = $OutboxDir;     Sandbox = 'C:\agy-outbox';         RO = 'false' }
        )

        $xw.WriteStartElement('MappedFolders')
        foreach ($m in $mappings) {
            $xw.WriteStartElement('MappedFolder')
            $xw.WriteElementString('HostFolder', [string]$m.Host)
            $xw.WriteElementString('SandboxFolder', [string]$m.Sandbox)
            $xw.WriteElementString('ReadOnly', [string]$m.RO)
            $xw.WriteEndElement()
        }
        $xw.WriteEndElement()

        $xw.WriteStartElement('LogonCommand')
        $xw.WriteElementString('Command', 'C:\agy-bootstrap\sandbox-init.cmd')
        $xw.WriteEndElement()

        $xw.WriteEndElement()
        $xw.Flush()
    } finally {
        $xw.Dispose()
    }
    return $sw.ToString()
}

function Test-SafeOutboxTree {
    param([Parameter(Mandatory = $true)][string]$RootDir)
    if (-not (Test-Path -LiteralPath $RootDir)) { return $true }
    $rootItem = Get-Item -LiteralPath $RootDir -Force
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Security check failed: reparse point detected at '$($rootItem.FullName)'."
    }
    $items = Get-ChildItem -LiteralPath $RootDir -Recurse -Force -ErrorAction Stop
    foreach ($it in $items) {
        if (($it.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Security check failed: reparse point/symlink detected in sandbox outbox at '$($it.FullName)'."
        }
    }
    return $true
}

function Resolve-SafeSubPath {
    param(
        [Parameter(Mandatory = $true)][string]$BaseDir,
        [Parameter(Mandatory = $true)][string]$RelPath
    )
    if ([IO.Path]::IsPathRooted($RelPath)) {
        throw "Security check failed: rooted relative path '$RelPath'."
    }
    $baseNorm = Normalize-DirPath $BaseDir
    $basePrefix = if ($baseNorm.EndsWith('\')) { $baseNorm } else { $baseNorm + '\' }
    $candidate = [IO.Path]::GetFullPath((Join-Path $baseNorm $RelPath))
    if (-not $candidate.StartsWith($basePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Security check failed: path traversal detected for '$RelPath'."
    }
    return $candidate
}

function Merge-HistoryJsonl {
    param(
        [Parameter(Mandatory = $true)][string]$HostFile,
        [Parameter(Mandatory = $true)][string]$OutboxFile,
        [AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$BaselineLines
    )
    if (-not (Test-Path -LiteralPath $OutboxFile -PathType Leaf)) { return 0 }
    $existingSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if ($BaselineLines) {
        foreach ($b in $BaselineLines) {
            if (-not [string]::IsNullOrWhiteSpace($b)) { $null = $existingSet.Add($b) }
        }
    }
    $hostLines = @()
    if (Test-Path -LiteralPath $HostFile -PathType Leaf) {
        $hostLines = [IO.File]::ReadAllLines($HostFile, $Utf8NoBom)
        foreach ($hl in $hostLines) {
            if (-not [string]::IsNullOrWhiteSpace($hl)) { $null = $existingSet.Add($hl) }
        }
    }
    $outboxLines = [IO.File]::ReadAllLines($OutboxFile, $Utf8NoBom)
    $toAppend = New-Object System.Collections.Generic.List[string]
    foreach ($ol in $outboxLines) {
        if ([string]::IsNullOrWhiteSpace($ol)) { continue }
        if ($existingSet.Add($ol)) {
            $toAppend.Add($ol)
        }
    }
    if ($toAppend.Count -gt 0) {
        $parent = Split-Path -Parent $HostFile
        if (-not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }
        $needsLeadingNewline = $false
        if ((Test-Path -LiteralPath $HostFile -PathType Leaf) -and ((Get-Item -LiteralPath $HostFile).Length -gt 0)) {
            $rawBytes = [IO.File]::ReadAllBytes($HostFile)
            if ($rawBytes.Length -gt 0 -and $rawBytes[$rawBytes.Length - 1] -ne 10) {
                $needsLeadingNewline = $true
            }
        }
        $sw = New-Object System.IO.StreamWriter($HostFile, $true, $Utf8NoBom)
        try {
            if ($needsLeadingNewline) { $sw.Write("`n") }
            foreach ($line in $toAppend) {
                $sw.Write($line)
                $sw.Write("`n")
            }
        } finally {
            $sw.Dispose()
        }
    }
    return $toAppend.Count
}

function Initialize-HostCredentialTypes {
    if (-not ('AgyCredentialReader' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using FILETIME = System.Runtime.InteropServices.ComTypes.FILETIME;

public class AgyCredentialData {
    public string UserName;
    public string BlobBase64;
}

public static class AgyCredentialReader {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredReadW(string target, int type, int reservedFlag, out IntPtr credentialPtr);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern void CredFree(IntPtr cred);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public int Flags;
        public int Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    public static AgyCredentialData Read(string target, out int win32Error) {
        win32Error = 0;
        IntPtr ptr = IntPtr.Zero;
        if (!CredReadW(target, 1, 0, out ptr)) {
            win32Error = Marshal.GetLastWin32Error();
            return null;
        }
        try {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            if (cred.CredentialBlobSize <= 0 || cred.CredentialBlob == IntPtr.Zero) {
                throw new InvalidOperationException("Credential '" + target + "' exists but has an empty blob.");
            }
            byte[] blob = new byte[cred.CredentialBlobSize];
            Marshal.Copy(cred.CredentialBlob, blob, 0, cred.CredentialBlobSize);
            AgyCredentialData data = new AgyCredentialData();
            data.UserName = cred.UserName != IntPtr.Zero ? Marshal.PtrToStringUni(cred.UserName) : "";
            data.BlobBase64 = Convert.ToBase64String(blob);
            return data;
        } finally {
            if (ptr != IntPtr.Zero) {
                CredFree(ptr);
            }
        }
    }
}
'@
    }
}

# ------------------------------------------------------------------------------
# Embedded Sandbox Scripts
# ------------------------------------------------------------------------------
function Get-InjectCredScript {
    return @'
$ErrorActionPreference = 'Stop'

if (-not ('AgyCredentialWriter' -as [type])) {
    $csCode = '
using System;
using System.Runtime.InteropServices;
using FILETIME = System.Runtime.InteropServices.ComTypes.FILETIME;

public static class AgyCredentialWriter {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWriteW(ref CREDENTIAL userCredential, uint flags);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public uint Flags;
        public uint Type;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
    }

    public static bool Write(string target, string userName, string base64Blob, out int win32Error) {
        win32Error = 0;
        byte[] blob = Convert.FromBase64String(base64Blob);
        if (blob.Length == 0) {
            throw new ArgumentException("Credential blob is empty.");
        }
        IntPtr blobPtr = Marshal.AllocHGlobal(blob.Length);
        try {
            Marshal.Copy(blob, 0, blobPtr, blob.Length);
            CREDENTIAL cred = new CREDENTIAL();
            cred.Flags = 0;
            cred.Type = 1; // CRED_TYPE_GENERIC
            cred.TargetName = target;
            cred.Comment = null;
            cred.LastWritten = new FILETIME();
            cred.CredentialBlobSize = (uint)blob.Length;
            cred.CredentialBlob = blobPtr;
            cred.Persist = 2; // CRED_PERSIST_LOCAL_MACHINE
            cred.AttributeCount = 0;
            cred.Attributes = IntPtr.Zero;
            cred.TargetAlias = null;
            cred.UserName = string.IsNullOrWhiteSpace(userName) ? "antigravity" : userName;

            if (!CredWriteW(ref cred, 0)) {
                win32Error = Marshal.GetLastWin32Error();
                return false;
            }
            return true;
        } finally {
            Marshal.FreeHGlobal(blobPtr);
        }
    }
}
'
    Add-Type -TypeDefinition $csCode
}

$tokenPath = 'C:\agy-bootstrap\keyring_token.json'
if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
    throw "Token file not found at $tokenPath (host may have timed out)."
}
$raw = Get-Content -LiteralPath $tokenPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Token file $tokenPath is empty."
}
$data = $raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$data.target) -or [string]::IsNullOrWhiteSpace([string]$data.blobBase64)) {
    throw "Token JSON is missing required target or blobBase64."
}

[int]$err = 0
$ok = [AgyCredentialWriter]::Write([string]$data.target, [string]$data.userName, [string]$data.blobBase64, [ref]$err)
if (-not $ok) {
    throw "CredWriteW failed with Win32 error $err."
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText('C:\agy-outbox\cred_ok.flag', (Get-Date).ToString('o'), $utf8)
Write-Host "  Credential injected into Sandbox Credential Manager (target=$($data.target), user=$($data.userName))."
'@
}

function Get-SandboxInitScript {
    return @'
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$desktopDir = [Environment]::GetFolderPath('Desktop')
$logFile = Join-Path $desktopDir 'agy-bootstrap.log'

function Write-BootLog {
    param([string]$Msg, [string]$Color = 'Gray')
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Msg
    [IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine, $utf8NoBom)
    Write-Host $line -ForegroundColor $Color
}

try {
    $cfg = Get-Content -LiteralPath 'C:\agy-bootstrap\bootstrap-config.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-BootLog "Bootstrapping Antigravity Sandbox (mode=$($cfg.mode), project=$($cfg.projectName))..." 'Cyan'

    # Step 1/7: Inject Credential FIRST so host can wipe token immediately
    Write-BootLog '[1/7] Injecting authentication into Credential Manager...' 'Yellow'
    $pwshExe = Join-Path ("C:\agy-tools\" + $cfg.toolDirs.pwsh) 'pwsh.exe'
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -File 'C:\agy-bootstrap\inject_cred.ps1'
    if ($LASTEXITCODE -ne 0) {
        throw "Credential injection failed with exit code $LASTEXITCODE."
    }

    # Step 2/7: Copy .gemini locally (robocopy handles long paths + exclusions safely)
    Write-BootLog '[2/7] Copying .gemini configuration locally...' 'Yellow'
    $localGemini = Join-Path $env:USERPROFILE '.gemini'
    if (-not (Test-Path -LiteralPath $localGemini)) {
        $null = New-Item -ItemType Directory -Path $localGemini -Force
    }
    $rcArgs = @(
        'C:\host-gemini-config', $localGemini,
        '/E', '/A-:R', '/XJ', '/MT:8', '/R:1', '/W:1', '/NP', '/NFL', '/NDL', '/NJH', '/NJS'
    )
    $exclDirs = @($cfg.geminiExcludeDirs)
    if ($exclDirs.Count -gt 0) {
        $rcArgs += '/XD'
        $rcArgs += $exclDirs
    }
    $exclFiles = @($cfg.geminiExcludeFiles)
    if ($exclFiles.Count -gt 0) {
        $rcArgs += '/XF'
        $rcArgs += $exclFiles
    }
    & robocopy.exe @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy of .gemini failed with exit code $LASTEXITCODE."
    }
    Write-BootLog "  .gemini copied (robocopy exit=$LASTEXITCODE)." 'Green'

    if ($cfg.createHostJunction -and (-not [string]::IsNullOrWhiteSpace([string]$cfg.hostUser)) -and
        (-not [string]::Equals([string]$cfg.hostUser, $env:USERNAME, [StringComparison]::OrdinalIgnoreCase))) {
        $hostUserDir = Join-Path 'C:\Users' ([string]$cfg.hostUser)
        $junctionPath = Join-Path $hostUserDir '.gemini'
        try {
            if (-not (Test-Path -LiteralPath $hostUserDir)) {
                $null = New-Item -ItemType Directory -Path $hostUserDir -Force
            }
            if (-not (Test-Path -LiteralPath $junctionPath)) {
                $null = New-Item -ItemType Junction -Path $junctionPath -Target $localGemini
                Write-BootLog "  Created host-path compatibility junction: $junctionPath -> $localGemini" 'DarkGray'
            }
        } catch {
            Write-BootLog "  Warning: could not create junction at ${junctionPath}: $($_.Exception.Message)" 'DarkYellow'
        }
    }

    # Step 3/7: Setup Workspace (YOLO RW vs Read-Only local copy)
    if ($cfg.mode -eq 'readonly') {
        $workDir = 'C:\work'
        Write-BootLog '[3/7] Read-Only mode: copying C:\workspace-ro to native C:\work...' 'Yellow'
        $null = New-Item -ItemType Directory -Path $workDir -Force
        & robocopy.exe 'C:\workspace-ro' $workDir /E /A-:R /XJ /MT:8 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "Failed to copy read-only workspace to C:\work (robocopy exit=$LASTEXITCODE)."
        }
        Write-BootLog '  Native workspace ready at C:\work (host project remains untouched).' 'Green'
    } else {
        $workDir = 'C:\workspace'
        Write-BootLog '[3/7] Full YOLO mode: workspace mapped read-write at C:\workspace.' 'Yellow'
    }

    # Step 4/7: Configure PATH, npm, MinGit, and Windows Terminal settings
    Write-BootLog '[4/7] Configuring portable tools, PATH, MinGit, and Windows Terminal...' 'Yellow'
    $agyBinDir = Split-Path -Parent ([string]$cfg.agyExe)
    $nodeDir = Join-Path 'C:\agy-tools' ([string]$cfg.toolDirs.node)
    $pwshDir = Join-Path 'C:\agy-tools' ([string]$cfg.toolDirs.pwsh)
    $wtDir   = Join-Path 'C:\agy-tools' ([string]$cfg.toolDirs.wt)
    $npmPrefix = Join-Path $env:LOCALAPPDATA 'npm'
    $npmCache  = Join-Path $env:LOCALAPPDATA 'npm-cache'
    $null = New-Item -ItemType Directory -Path $npmPrefix -Force
    $null = New-Item -ItemType Directory -Path $npmCache -Force

    $toolPathEntries = @($agyBinDir, $nodeDir, $pwshDir, $wtDir, $npmPrefix)
    if (-not [string]::IsNullOrWhiteSpace([string]$cfg.toolDirs.mingit)) {
        $gitCmdDir = Join-Path ("C:\agy-tools\" + [string]$cfg.toolDirs.mingit) 'cmd'
        $toolPathEntries += $gitCmdDir
    }

    $envRegPath = 'HKCU:\Environment'
    $regKey = Get-Item -LiteralPath $envRegPath
    $rawUserPath = [string]$regKey.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $segments = New-Object System.Collections.Generic.List[string]
    foreach ($s in ($rawUserPath -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($s)) { $segments.Add($s.Trim()) }
    }
    foreach ($entry in $toolPathEntries) {
        $exists = $false
        foreach ($seg in $segments) {
            if ([string]::Equals($seg, $entry, [StringComparison]::OrdinalIgnoreCase)) { $exists = $true; break }
        }
        if (-not $exists) { $segments.Add($entry) }
    }
    $newUserPath = ($segments.ToArray() -join ';')
    $rwKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    if (-not $rwKey) {
        $rwKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    }
    try {
        $rwKey.SetValue('Path', $newUserPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        $rwKey.SetValue('NPM_CONFIG_PREFIX', $npmPrefix, [Microsoft.Win32.RegistryValueKind]::String)
        $rwKey.SetValue('NPM_CONFIG_CACHE', $npmCache, [Microsoft.Win32.RegistryValueKind]::String)
    } finally {
        $rwKey.Dispose()
    }
    $env:NPM_CONFIG_PREFIX = $npmPrefix
    $env:NPM_CONFIG_CACHE  = $npmCache
    $env:PATH = (($toolPathEntries -join ';') + ';' + $env:PATH)

    if (-not [string]::IsNullOrWhiteSpace([string]$cfg.toolDirs.mingit)) {
        $gitExe = Join-Path ("C:\agy-tools\" + [string]$cfg.toolDirs.mingit) 'cmd\git.exe'
        if (Test-Path -LiteralPath $gitExe -PathType Leaf) {
            & $gitExe config --global --add safe.directory '*' | Out-Null
            & $gitExe config --global core.longpaths true | Out-Null
            Write-BootLog '  MinGit configured (safe.directory=*, core.longpaths=true).' 'DarkGray'
        }
    }

    $wtSettingsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal'
    $null = New-Item -ItemType Directory -Path $wtSettingsDir -Force
    $wtProfileGuid = '{a6f7c2d0-8e34-4b2a-9f1a-1234567890ab}'
    $wtSettingsObj = [ordered]@{
        '$schema' = 'https://aka.ms/terminal-profiles-schema'
        defaultProfile = $wtProfileGuid
        confirmCloseAllTabs = $false
        profiles = [ordered]@{
            defaults = [ordered]@{
                startingDirectory = $workDir
                font = [ordered]@{ face = 'Cascadia Mono' }
            }
            list = @(
                [ordered]@{
                    guid = $wtProfileGuid
                    name = 'PowerShell 7 (Sandbox)'
                    commandline = "`"$pwshExe`" -NoLogo"
                }
            )
        }
    }
    [IO.File]::WriteAllText((Join-Path $wtSettingsDir 'settings.json'), ($wtSettingsObj | ConvertTo-Json -Depth 6), $utf8NoBom)

    # Step 5/7: Install local closer scripts, Desktop shortcut, and optional safe autosave
    Write-BootLog '[5/7] Setting up closer shortcut and safe autosave...' 'Yellow'
    $localDir = 'C:\agy-local'
    $null = New-Item -ItemType Directory -Path $localDir -Force
    Copy-Item -LiteralPath 'C:\agy-bootstrap\bootstrap-config.json' -Destination (Join-Path $localDir 'bootstrap-config.json') -Force
    Copy-Item -LiteralPath 'C:\agy-bootstrap\sandbox-close.ps1'     -Destination (Join-Path $localDir 'sandbox-close.ps1')     -Force
    Copy-Item -LiteralPath 'C:\agy-bootstrap\sandbox-autosave.ps1'  -Destination (Join-Path $localDir 'sandbox-autosave.ps1')  -Force

    $shortcutName = if ($cfg.mode -eq 'readonly') { 'Export_Changes_and_Close_Sandbox.cmd' } else { 'Save_History_and_Close_Sandbox.cmd' }
    $shortcutPath = Join-Path $desktopDir $shortcutName
    $shortcutCmd = @"
@echo off
title Saving and Closing Antigravity Sandbox...
"$pwshExe" -NoProfile -ExecutionPolicy Bypass -File "C:\agy-local\sandbox-close.ps1"
if errorlevel 1 (
    echo.
    echo ERROR: Sync or export failed. Sandbox was NOT shut down so your data is preserved.
    pause
)
"@
    [IO.File]::WriteAllText($shortcutPath, ($shortcutCmd -replace "`r?`n", "`r`n"), [System.Text.Encoding]::ASCII)

    if ([int]$cfg.autosaveIntervalMinutes -gt 0) {
        Start-Process -FilePath $pwshExe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-File', (Join-Path $localDir 'sandbox-autosave.ps1')) -WindowStyle Hidden
        Write-BootLog "  Periodic non-SQLite autosave started (every $($cfg.autosaveIntervalMinutes) min)." 'DarkGray'
    }

    # Step 6/7: Wait briefly for sandbox NIC/DNS readiness
    Write-BootLog '[6/7] Waiting for sandbox network/DNS readiness...' 'Yellow'
    $dnsReady = $false
    for ($attempt = 0; $attempt -lt 15; $attempt++) {
        try {
            $addrs = [Net.Dns]::GetHostAddresses('googleapis.com')
            if ($addrs -and $addrs.Count -gt 0) { $dnsReady = $true; break }
        } catch {}
        Start-Sleep -Seconds 1
    }
    if ($dnsReady) {
        Write-BootLog '  Network/DNS ready.' 'Green'
    } else {
        Write-BootLog '  Warning: DNS check timed out after 15s; continuing anyway.' 'DarkYellow'
    }

    # Step 7/7: Launch agy inside Windows Terminal (with pwsh fallback if WT fails)
    Write-BootLog '[7/7] Launching Antigravity inside Windows Terminal...' 'Yellow'
    $runCfgPath = Join-Path $localDir 'run-args.json'
    $runPayload = [ordered]@{
        mode       = [string]$cfg.mode
        workDir    = $workDir
        agyExe     = [string]$cfg.agyExe
        agyArgs    = @($cfg.agyArgs)
        toolPaths  = $toolPathEntries
        npmPrefix  = $npmPrefix
        npmCache   = $npmCache
    }
    [IO.File]::WriteAllText($runCfgPath, ($runPayload | ConvertTo-Json -Depth 4), $utf8NoBom)

    $agyRunPath = Join-Path $localDir 'agy-run.ps1'
    Copy-Item -LiteralPath 'C:\agy-bootstrap\agy-run.ps1' -Destination $agyRunPath -Force

    $wtExe = Join-Path $wtDir 'wt.exe'
    $wtStarted = $false
    if (Test-Path -LiteralPath $wtExe -PathType Leaf) {
        try {
            Start-Process -FilePath $wtExe -WorkingDirectory $workDir -ArgumentList @(
                '--window', '0', '-d', $workDir, '--inheritEnvironment', '--', $pwshExe, '-NoExit', '-File', $agyRunPath
            ) | Out-Null
            Start-Sleep -Milliseconds 2500
            if (Get-Process -Name 'WindowsTerminal' -ErrorAction SilentlyContinue) {
                $wtStarted = $true
            }
        } catch {
            Write-BootLog "  Windows Terminal launch error: $($_.Exception.Message)" 'DarkYellow'
        }
    }
    if (-not $wtStarted) {
        Write-BootLog '  Windows Terminal unavailable or missing VC++ runtime; falling back to PowerShell 7 window.' 'DarkYellow'
        Start-Process -FilePath $pwshExe -WorkingDirectory $workDir -ArgumentList @('-NoExit', '-File', $agyRunPath) | Out-Null
    }
    Write-BootLog 'Bootstrap complete!' 'Green'
    exit 0
} catch {
    Write-BootLog "FATAL ERROR: $($_.Exception.Message)" 'Red'
    Write-Host ''
    Read-Host 'Bootstrap failed. Press Enter to close this window'
    exit 1
}
'@
}

function Get-AgyRunScript {
    return @'
$ErrorActionPreference = 'Continue'
chcp 65001 > $null
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding           = [System.Text.UTF8Encoding]::new($false)

$run = Get-Content -LiteralPath 'C:\agy-local\run-args.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$env:NPM_CONFIG_PREFIX = [string]$run.npmPrefix
$env:NPM_CONFIG_CACHE  = [string]$run.npmCache
$env:PATH = ((@($run.toolPaths) -join ';') + ';' + $env:PATH)
Set-Location -LiteralPath ([string]$run.workDir)

if ($run.mode -eq 'readonly') {
    Write-Host '====================================================================' -ForegroundColor Cyan
    Write-Host '  Antigravity Sandbox -- READ-ONLY / DIFF-ONLY MODE (C:\work)'        -ForegroundColor Cyan
    Write-Host '  Host project is read-only. Double-click Desktop shortcut to'       -ForegroundColor Cyan
    Write-Host '  export changes (.patch + files) and close safely.'                  -ForegroundColor Cyan
    Write-Host '====================================================================' -ForegroundColor Cyan
} else {
    Write-Host '====================================================================' -ForegroundColor Yellow
    Write-Host '  Antigravity Sandbox -- FULL YOLO MODE (C:\workspace, Read-Write)'   -ForegroundColor Yellow
    Write-Host '  Double-click Desktop shortcut "Save_History_and_Close_Sandbox"'     -ForegroundColor Yellow
    Write-Host '  when finished so your history is synced safely to the host.'        -ForegroundColor Yellow
    Write-Host '====================================================================' -ForegroundColor Yellow
}
Write-Host ''

$extraArgs = @($run.agyArgs)
& ([string]$run.agyExe) '--dangerously-skip-permissions' @extraArgs
'@
}

function Get-SandboxAutosaveScript {
    return @'
$ErrorActionPreference = 'SilentlyContinue'
$cfg = Get-Content -LiteralPath 'C:\agy-local\bootstrap-config.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$intervalSec = [int]$cfg.autosaveIntervalMinutes * 60
if ($intervalSec -le 0) { exit 0 }

$geminiSrc = Join-Path $env:USERPROFILE '.gemini'
$outboxAuto = 'C:\agy-outbox\autosave'

while ($true) {
    for ($t = 0; $t -lt $intervalSec; $t += 5) {
        if (Test-Path -LiteralPath 'C:\agy-local\closing.flag') { exit 0 }
        Start-Sleep -Seconds 5
    }
    if (Test-Path -LiteralPath 'C:\agy-local\closing.flag') { exit 0 }

    foreach ($relDir in @($cfg.syncAllowListDirs)) {
        $src = Join-Path $geminiSrc $relDir
        if (Test-Path -LiteralPath $src -PathType Container) {
            $dst = Join-Path $outboxAuto $relDir
            $null = New-Item -ItemType Directory -Path $dst -Force
            & robocopy.exe $src $dst /E /XO /XJ /R:0 /W:0 /NP /NFL /NDL /NJH /NJS /XF '*.db' '*.db-wal' '*.db-shm' | Out-Null
        }
    }

    $histSrc = Join-Path $geminiSrc 'antigravity-cli\history.jsonl'
    if (Test-Path -LiteralPath $histSrc -PathType Leaf) {
        $histDstDir = Join-Path $outboxAuto 'antigravity-cli'
        $null = New-Item -ItemType Directory -Path $histDstDir -Force
        Copy-Item -LiteralPath $histSrc -Destination (Join-Path $histDstDir 'history.jsonl') -Force
    }
}
'@
}

function Get-SandboxCloseScript {
    return @'
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    $cfg = Get-Content -LiteralPath 'C:\agy-local\bootstrap-config.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $null = New-Item -ItemType Directory -Path 'C:\agy-local' -Force
    [IO.File]::WriteAllText('C:\agy-local\closing.flag', (Get-Date).ToString('o'), $utf8NoBom)

    Write-Host '[1/5] Stopping Antigravity and child processes cleanly...' -ForegroundColor Yellow

    # Collect ancestor PIDs so running closer from inside pwsh never self-terminates
    $ancestorPids = New-Object 'System.Collections.Generic.HashSet[int]'
    $procMap = @{}
    foreach ($p in (Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue)) {
        $procMap[[int]$p.ProcessId] = [int]$p.ParentProcessId
    }
    $cur = $PID
    while ($cur -gt 0 -and $ancestorPids.Add($cur)) {
        if ($procMap.ContainsKey($cur)) { $cur = $procMap[$cur] } else { break }
    }

    # Try polite close of non-ancestor WindowsTerminal windows first
    foreach ($wt in (Get-Process -Name 'WindowsTerminal' -ErrorAction SilentlyContinue)) {
        if (-not $ancestorPids.Contains($wt.Id)) {
            try { $null = $wt.CloseMainWindow() } catch {}
        }
    }
    Start-Sleep -Milliseconds 1500

    foreach ($name in @('agy', 'node', 'webm_encoder')) {
        foreach ($proc in (Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            if (-not $ancestorPids.Contains($proc.Id)) {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }
    foreach ($pw in (Get-Process -Name 'pwsh' -ErrorAction SilentlyContinue)) {
        if (-not $ancestorPids.Contains($pw.Id)) {
            try { Stop-Process -Id $pw.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
    Start-Sleep -Milliseconds 500

    # Step 2/5: SQLite WAL checkpoint using built-in node:sqlite
    Write-Host '[2/5] Checkpointing SQLite database WAL...' -ForegroundColor Yellow
    $geminiSrc = Join-Path $env:USERPROFILE '.gemini'
    $dbPath = Join-Path $geminiSrc 'antigravity-cli\conversation_summaries.db'
    $nodeExe = Join-Path ("C:\agy-tools\" + [string]$cfg.toolDirs.node) 'node.exe'
    if ((Test-Path -LiteralPath $dbPath -PathType Leaf) -and (Test-Path -LiteralPath $nodeExe -PathType Leaf)) {
        $ckptJs = @(
            "const { DatabaseSync } = require('node:sqlite');",
            "const db = new DatabaseSync(process.argv[1]);",
            "const res = db.prepare('PRAGMA wal_checkpoint(TRUNCATE);').get();",
            "db.close();",
            "console.log(JSON.stringify(res || {}));"
        ) -join "`n"
        $ckptPath = 'C:\agy-local\ckpt.cjs'
        [IO.File]::WriteAllText($ckptPath, $ckptJs, $utf8NoBom)
        $ckptOut = & $nodeExe $ckptPath $dbPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "SQLite WAL checkpoint failed: $($ckptOut -join ' ')"
        }
        Write-Host "  SQLite WAL checkpointed: $($ckptOut -join ' ')" -ForegroundColor Green
    }

    # Step 3/5: Copy allow-listed history to C:\agy-outbox\final
    Write-Host '[3/5] Exporting allow-listed session history to outbox...' -ForegroundColor Yellow
    $finalOut = 'C:\agy-outbox\final'
    $null = New-Item -ItemType Directory -Path $finalOut -Force

    foreach ($relDir in @($cfg.syncAllowListDirs)) {
        $src = Join-Path $geminiSrc $relDir
        if (Test-Path -LiteralPath $src -PathType Container) {
            $dst = Join-Path $finalOut $relDir
            $null = New-Item -ItemType Directory -Path $dst -Force
            & robocopy.exe $src $dst /E /XJ /R:2 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
            if ($LASTEXITCODE -ge 8) {
                throw "Failed copying $relDir to outbox (robocopy exit=$LASTEXITCODE)."
            }
        }
    }

    $cliOut = Join-Path $finalOut 'antigravity-cli'
    $null = New-Item -ItemType Directory -Path $cliOut -Force
    $histSrc = Join-Path $geminiSrc 'antigravity-cli\history.jsonl'
    if (Test-Path -LiteralPath $histSrc -PathType Leaf) {
        Copy-Item -LiteralPath $histSrc -Destination (Join-Path $cliOut 'history.jsonl') -Force
    }
    if (Test-Path -LiteralPath $dbPath -PathType Leaf) {
        Copy-Item -LiteralPath $dbPath -Destination (Join-Path $cliOut 'conversation_summaries.db') -Force
        foreach ($sidecar in @('conversation_summaries.db-wal', 'conversation_summaries.db-shm')) {
            $scPath = Join-Path $geminiSrc ("antigravity-cli\" + $sidecar)
            if ((Test-Path -LiteralPath $scPath -PathType Leaf) -and ((Get-Item -LiteralPath $scPath).Length -gt 0)) {
                Copy-Item -LiteralPath $scPath -Destination (Join-Path $cliOut $sidecar) -Force
            }
        }
    }

    if ($cfg.syncKnowledge) {
        $knSrc = Join-Path $geminiSrc 'antigravity-cli\knowledge'
        if (Test-Path -LiteralPath $knSrc -PathType Container) {
            $knDst = 'C:\agy-outbox\knowledge_pending'
            $null = New-Item -ItemType Directory -Path $knDst -Force
            & robocopy.exe $knSrc $knDst /E /XJ /R:2 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
            if ($LASTEXITCODE -ge 8) {
                throw "Failed copying knowledge_pending (robocopy exit=$LASTEXITCODE)."
            }
        }
    }

    # Step 4/5: Read-Only Mode diff & changed-file export
    if ($cfg.mode -eq 'readonly') {
        Write-Host '[4/5] Exporting Read-Only workspace changes (.patch + modified files)...' -ForegroundColor Yellow
        $chgRoot  = 'C:\agy-outbox\workspace_changes'
        $filesOut = Join-Path $chgRoot 'files'
        $null = New-Item -ItemType Directory -Path $filesOut -Force

        $gitExe = $null
        if (-not [string]::IsNullOrWhiteSpace([string]$cfg.toolDirs.mingit)) {
            $cand = Join-Path ("C:\agy-tools\" + [string]$cfg.toolDirs.mingit) 'cmd\git.exe'
            if (Test-Path -LiteralPath $cand -PathType Leaf) { $gitExe = $cand }
        }
        if ($gitExe -and (Test-Path -LiteralPath 'C:\work\.git')) {
            $stOut = @(& $gitExe -C 'C:\work' status --porcelain 2>$null)
            if ($stOut.Count -gt 0) {
                [IO.File]::WriteAllLines((Join-Path $chgRoot 'git_status.txt'), [string[]]$stOut, $utf8NoBom)
            }
            $hasHead = $false
            & $gitExe -C 'C:\work' rev-parse --verify HEAD 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $hasHead = $true }
            $diffOut = if ($hasHead) { @(& $gitExe -C 'C:\work' diff HEAD 2>$null) } else { @(& $gitExe -C 'C:\work' diff 2>$null) }
            if ($diffOut.Count -gt 0) {
                [IO.File]::WriteAllLines((Join-Path $chgRoot 'changes.patch'), [string[]]$diffOut, $utf8NoBom)
            }
        }

        function Get-RelFileMap {
            param([string]$Root)
            $map = @{}
            $normRoot = $Root.TrimEnd('\')
            $prefixLen = $normRoot.Length + 1
            $queue = New-Object System.Collections.Generic.Queue[string]
            $queue.Enqueue($normRoot)
            while ($queue.Count -gt 0) {
                $dir = $queue.Dequeue()
                foreach ($entry in (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
                    if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    if ($entry.PSIsContainer) {
                        if ($entry.Name -ieq '.git') { continue }
                        $queue.Enqueue($entry.FullName)
                    } elseif ($entry.FullName.Length -gt $prefixLen) {
                        $rel = $entry.FullName.Substring($prefixLen)
                        $map[$rel] = $entry
                    }
                }
            }
            return $map
        }

        $roMap   = Get-RelFileMap 'C:\workspace-ro'
        $workMap = Get-RelFileMap 'C:\work'
        $addedCount = 0
        $modCount   = 0
        $deleted    = New-Object System.Collections.Generic.List[string]

        foreach ($rel in $workMap.Keys) {
            $wf = $workMap[$rel]
            $changed = $false
            if (-not $roMap.ContainsKey($rel)) {
                $changed = $true
                $addedCount++
            } else {
                $rf = $roMap[$rel]
                if ($wf.Length -ne $rf.Length) {
                    $changed = $true
                    $modCount++
                } else {
                    $wh = (Get-FileHash -LiteralPath $wf.FullName -Algorithm SHA256).Hash
                    $rh = (Get-FileHash -LiteralPath $rf.FullName -Algorithm SHA256).Hash
                    if ($wh -ne $rh) {
                        $changed = $true
                        $modCount++
                    }
                }
            }
            if ($changed) {
                $destFile = Join-Path $filesOut $rel
                $destDir  = Split-Path -Parent $destFile
                if (-not (Test-Path -LiteralPath $destDir)) {
                    $null = New-Item -ItemType Directory -Path $destDir -Force
                }
                Copy-Item -LiteralPath $wf.FullName -Destination $destFile -Force
            }
        }

        foreach ($rel in $roMap.Keys) {
            if (-not $workMap.ContainsKey($rel)) {
                $deleted.Add($rel)
            }
        }
        if ($deleted.Count -gt 0) {
            [IO.File]::WriteAllLines((Join-Path $chgRoot 'deleted_files.txt'), $deleted.ToArray(), $utf8NoBom)
        }
        $summaryText = "Added: $addedCount`r`nModified: $modCount`r`nDeleted: $($deleted.Count)`r`n"
        [IO.File]::WriteAllText((Join-Path $chgRoot 'summary.txt'), $summaryText, $utf8NoBom)
        Write-Host "  Workspace diff exported (Added=$addedCount, Modified=$modCount, Deleted=$($deleted.Count))." -ForegroundColor Green
    } else {
        Write-Host '[4/5] Full YOLO mode: workspace edits already applied at C:\workspace.' -ForegroundColor DarkGray
    }

    # Step 5/5: Signal host completion and shut down VM
    Write-Host '[5/5] Writing completion marker and shutting down Sandbox...' -ForegroundColor Yellow
    $doneObj = [ordered]@{
        completedUtc = (Get-Date).ToUniversalTime().ToString('o')
        mode         = [string]$cfg.mode
    }
    [IO.File]::WriteAllText('C:\agy-outbox\done.flag', ($doneObj | ConvertTo-Json), $utf8NoBom)
    & shutdown.exe /p
    if ($LASTEXITCODE -ne 0) {
        & shutdown.exe /s /t 0 /f
    }
} catch {
    Write-Host "ERROR during sandbox close/sync: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Sandbox was NOT shut down so no history or edits are lost.' -ForegroundColor Yellow
    Read-Host 'Press Enter to exit'
    exit 1
}
'@
}

# ------------------------------------------------------------------------------
# Host Tool Caching (Pre-Extracted Portable ZIPs Mapped Read-Only)
# ------------------------------------------------------------------------------
function Ensure-PortableTools {
    param(
        [Parameter(Mandatory = $true)][string]$Arch,
        [Parameter(Mandatory = $true)][hashtable]$Cfg
    )
    $cacheRoot = [string]$Cfg.ToolsCacheDir
    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        $null = New-Item -ItemType Directory -Path $cacheRoot -Force
    }
    $stagingRoot = Join-Path $cacheRoot '_staging'
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $toolNames = @('node', 'pwsh', 'wt')
    if ($Cfg.InstallMinGit) { $toolNames += 'mingit' }

    $resolvedDirs = @{}
    $missing = @()

    foreach ($name in $toolNames) {
        $toolDef = $Cfg.Tools[$name]
        $archDef = $toolDef[$Arch]
        $folderName = "$name-$($toolDef.Version)-$Arch"
        $targetDir  = Join-Path $cacheRoot $folderName
        $verFile    = Join-Path $targetDir '.verified'
        $sentinel   = Join-Path $targetDir $toolDef.Sentinel

        $isCached = $false
        if ((Test-Path -LiteralPath $targetDir -PathType Container) -and
            (Test-Path -LiteralPath $verFile -PathType Leaf) -and
            (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
            $storedHash = (Get-Content -LiteralPath $verFile -Raw -Encoding UTF8).Trim()
            if ([string]::Equals($storedHash, [string]$archDef.Sha256, [StringComparison]::OrdinalIgnoreCase)) {
                $isCached = $true
            }
        }
        if ($isCached) {
            $resolvedDirs[$name] = $folderName
        } else {
            $missing += [ordered]@{
                Name       = $name
                FolderName = $folderName
                TargetDir  = $targetDir
                Sentinel   = [string]$toolDef.Sentinel
                Url        = [string]$archDef.Url
                Sha256     = ([string]$archDef.Sha256).ToUpperInvariant()
                ZipPath    = Join-Path $stagingRoot "$name.zip.tmp"
            }
        }
    }

    if ($missing.Count -eq 0) {
        Write-Host "[Init] All portable tools cached and verified in $($cacheRoot)." -ForegroundColor Green
        return $resolvedDirs
    }

    $null = New-Item -ItemType Directory -Path $stagingRoot -Force
    $curlCmd = Get-Command 'curl.exe' -ErrorAction SilentlyContinue
    $curlExe = if ($curlCmd) { $curlCmd.Source } else { $null }

    Write-Host "[Init] Downloading $($missing.Count) portable tool archive(s) in parallel ($Arch)..." -ForegroundColor Yellow
    if ($curlExe) {
        $jobs = @()
        foreach ($item in $missing) {
            Write-Host "  -> $($item.FolderName): $($item.Url)" -ForegroundColor DarkGray
            $proc = Start-Process -FilePath $curlExe -ArgumentList @(
                '--fail', '--silent', '--show-error', '--location',
                '--retry', '3', '--retry-delay', '2', '--connect-timeout', '20',
                $item.Url, '-o', $item.ZipPath
            ) -PassThru -NoNewWindow
            $null = $proc.Handle
            $jobs += [pscustomobject]@{ Item = $item; Proc = $proc }
        }
        foreach ($j in $jobs) {
            $j.Proc.WaitForExit()
            if ($j.Proc.ExitCode -ne 0) {
                throw "Download failed for $($j.Item.FolderName) (network/HTTP error, curl exit code $($j.Proc.ExitCode)). Check your internet connection."
            }
        }
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $tasks = @()
        foreach ($item in $missing) {
            Write-Host "  -> $($item.FolderName): $($item.Url)" -ForegroundColor DarkGray
            $wc = New-Object System.Net.WebClient
            $t = $wc.DownloadFileTaskAsync($item.Url, $item.ZipPath)
            $tasks += [pscustomobject]@{ Item = $item; Client = $wc; Task = $t }
        }
        foreach ($tk in $tasks) {
            try {
                $tk.Task.GetAwaiter().GetResult()
            } catch {
                throw "Download failed for $($tk.Item.FolderName): $($_.Exception.Message)"
            } finally {
                $tk.Client.Dispose()
            }
        }
    }

    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    try {
        foreach ($item in $missing) {
            if (-not (Test-Path -LiteralPath $item.ZipPath -PathType Leaf)) {
                throw "Downloaded archive missing for $($item.FolderName)."
            }
            $actualHash = (Get-FileHash -LiteralPath $item.ZipPath -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($actualHash -ne $item.Sha256) {
                Remove-Item -LiteralPath $item.ZipPath -Force -ErrorAction SilentlyContinue
                throw "SHA-256 verification FAILED for $($item.FolderName)! Expected $($item.Sha256), got $actualHash."
            }

            $extractDir = Join-Path $stagingRoot ("extract_" + $item.Name)
            [System.IO.Compression.ZipFile]::ExtractToDirectory($item.ZipPath, $extractDir)

            # Locate sentinel file and normalize root folder (handles wrapped vs flat zips)
            $directSentinel = Join-Path $extractDir $item.Sentinel
            $normalizedRoot = $null
            if (Test-Path -LiteralPath $directSentinel -PathType Leaf) {
                $normalizedRoot = $extractDir
            } else {
                $sentinelLeaf = Split-Path -Leaf $item.Sentinel
                $depth = ($item.Sentinel -split '\\').Count
                $found = Get-ChildItem -LiteralPath $extractDir -Recurse -Filter $sentinelLeaf -File -ErrorAction SilentlyContinue | Where-Object {
                    $_.FullName.EndsWith(('\' + $item.Sentinel), [StringComparison]::OrdinalIgnoreCase)
                } | Select-Object -First 1
                if (-not $found) {
                    throw "Extracted archive for $($item.FolderName) does not contain expected binary '$($item.Sentinel)'."
                }
                $cur = $found.Directory.FullName
                for ($d = 1; $d -lt $depth; $d++) {
                    $cur = Split-Path -Parent $cur
                }
                $normalizedRoot = $cur
            }

            if (Test-Path -LiteralPath $item.TargetDir) {
                Remove-Item -LiteralPath $item.TargetDir -Recurse -Force
            }
            Move-Item -LiteralPath $normalizedRoot -Destination $item.TargetDir
            [IO.File]::WriteAllText((Join-Path $item.TargetDir '.verified'), $item.Sha256, $Utf8NoBom)

            # Prune superseded cached versions of this tool
            foreach ($old in (Get-ChildItem -LiteralPath $cacheRoot -Directory -Filter "$($item.Name)-*" -ErrorAction SilentlyContinue)) {
                if ($old.Name -ne $item.FolderName) {
                    Remove-Item -LiteralPath $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            $resolvedDirs[$item.Name] = $item.FolderName
            Write-Host "  Verified & cached: $($item.FolderName)" -ForegroundColor Green
        }
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    return $resolvedDirs
}

# ------------------------------------------------------------------------------
# Mode Selection Dialog (WinForms + Console Fallback)
# ------------------------------------------------------------------------------
function Show-ModeSelectionDialog {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectDir,
        [AllowNull()][string]$RequestedMode,
        [bool]$NoDialog
    )
    if ($RequestedMode) { return $RequestedMode }
    if ($NoDialog) { return 'readonly' }

    $interactive = $false
    try {
        $interactive = [Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)
    } catch {
        $interactive = $false
    }
    if (-not $interactive) {
        throw 'Non-interactive session detected with no mode specified. Pass --readonly or --yolo.'
    }

    try {
        Add-Type -AssemblyName 'System.Windows.Forms'
        Add-Type -AssemblyName 'System.Drawing'
        [System.Windows.Forms.Application]::EnableVisualStyles()

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Antigravity Sandbox v$($Config.Version) - Mode Selection"
        $form.Size = New-Object System.Drawing.Size(560, 315)
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.TopMost = $true

        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = "Choose how to map your project inside Windows Sandbox:"
        $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 16)
        $lblTitle.Size = New-Object System.Drawing.Size(510, 24)
        $form.Controls.Add($lblTitle)

        $lblPath = New-Object System.Windows.Forms.Label
        $lblPath.Text = "Project: $ProjectDir"
        $lblPath.Font = New-Object System.Drawing.Font('Segoe UI', 9)
        $lblPath.Location = New-Object System.Drawing.Point(20, 44)
        $lblPath.Size = New-Object System.Drawing.Size(510, 36)
        $form.Controls.Add($lblPath)

        $lblRoDesc = New-Object System.Windows.Forms.Label
        $lblRoDesc.Text = "Read-Only / Diff-Only (Safest): Host folder is mapped read-only. Agent works on a copy at C:\work and exports a .patch + changed files to %TEMP% on close."
        $lblRoDesc.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
        $lblRoDesc.Location = New-Object System.Drawing.Point(20, 88)
        $lblRoDesc.Size = New-Object System.Drawing.Size(510, 42)
        $form.Controls.Add($lblRoDesc)

        $lblRwDesc = New-Object System.Windows.Forms.Label
        $lblRwDesc.Text = "Full YOLO (Read-Write): Host folder is mapped read-write at C:\workspace. Edits apply immediately to your workspace (host OS remains isolated)."
        $lblRwDesc.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
        $lblRwDesc.Location = New-Object System.Drawing.Point(20, 138)
        $lblRwDesc.Size = New-Object System.Drawing.Size(510, 42)
        $form.Controls.Add($lblRwDesc)

        $script:DialogChoice = $null

        $btnRo = New-Object System.Windows.Forms.Button
        $btnRo.Text = 'Read-Only (Diff-Only)'
        $btnRo.Location = New-Object System.Drawing.Point(20, 210)
        $btnRo.Size = New-Object System.Drawing.Size(175, 40)
        $btnRo.Add_Click({ $script:DialogChoice = 'readonly'; $form.DialogResult = [System.Windows.Forms.DialogResult]::OK; $form.Close() })
        $form.Controls.Add($btnRo)

        $btnRw = New-Object System.Windows.Forms.Button
        $btnRw.Text = 'Full YOLO (Read-Write)'
        $btnRw.Location = New-Object System.Drawing.Point(210, 210)
        $btnRw.Size = New-Object System.Drawing.Size(175, 40)
        $btnRw.Add_Click({ $script:DialogChoice = 'yolo'; $form.DialogResult = [System.Windows.Forms.DialogResult]::Yes; $form.Close() })
        $form.Controls.Add($btnRw)

        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = 'Cancel'
        $btnCancel.Location = New-Object System.Drawing.Point(410, 210)
        $btnCancel.Size = New-Object System.Drawing.Size(110, 40)
        $btnCancel.Add_Click({ $script:DialogChoice = $null; $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
        $form.Controls.Add($btnCancel)

        $form.AcceptButton = $btnRo
        $form.CancelButton = $btnCancel
        $null = $form.ShowDialog()
        $form.Dispose()
        return $script:DialogChoice
    } catch {
        Write-Host ''
        Write-Host "Select Sandbox Mode for: $ProjectDir" -ForegroundColor Cyan
        Write-Host '  [1] Read-Only / Diff-Only (Safest -- exports .patch + changed files to %TEMP%)'
        Write-Host '  [2] Full YOLO (Read-Write -- C:\workspace mapped directly to project)'
        Write-Host '  [Q] Cancel'
        while ($true) {
            $ans = (Read-Host 'Choice [1/2/Q]').Trim().ToUpperInvariant()
            switch ($ans) {
                '1' { return 'readonly' }
                '2' { return 'yolo' }
                'Q' { return $null }
            }
        }
    }
}

# ------------------------------------------------------------------------------
# SQLite Host Merge via Cached Node 24
# ------------------------------------------------------------------------------
function Merge-HostSqliteDb {
    param(
        [Parameter(Mandatory = $true)][string]$NodeExe,
        [Parameter(Mandatory = $true)][string]$HostDb,
        [Parameter(Mandatory = $true)][string]$OutboxDb
    )
    if (-not (Test-Path -LiteralPath $OutboxDb -PathType Leaf)) { return $false }
    if ((Get-Item -LiteralPath $OutboxDb -Force).Length -eq 0) { return $false }
    $hostDir = Split-Path -Parent $HostDb
    if (-not (Test-Path -LiteralPath $hostDir)) {
        $null = New-Item -ItemType Directory -Path $hostDir -Force
    }
    if (-not (Test-Path -LiteralPath $HostDb -PathType Leaf)) {
        Copy-Item -LiteralPath $OutboxDb -Destination $HostDb -Force
        return $true
    }

    $bakPath = "$HostDb.bak"
    Copy-Item -LiteralPath $HostDb -Destination $bakPath -Force

    $mergeJs = @'
const { DatabaseSync } = require('node:sqlite');
const hostPath = process.argv[2];
const srcPath  = process.argv[3];
const db = new DatabaseSync(hostPath);
db.exec('PRAGMA foreign_keys = OFF;');
db.exec(`ATTACH DATABASE '${srcPath.replace(/'/g, "''")}' AS src;`);
const srcTables = db.prepare("SELECT name FROM src.sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").all().map(r => r.name);
const mainTables = new Set(db.prepare("SELECT name FROM main.sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").all().map(r => r.name));
let mergedTables = 0;
db.exec('BEGIN IMMEDIATE;');
try {
    for (const tbl of srcTables) {
        if (!mainTables.has(tbl)) continue;
        const escTbl = tbl.replace(/"/g, '""');
        const mainCols = new Set(db.prepare(`PRAGMA main.table_info("${escTbl}")`).all().map(c => c.name));
        const commonCols = db.prepare(`PRAGMA src.table_info("${escTbl}")`).all().map(c => c.name).filter(c => mainCols.has(c));
        if (commonCols.length === 0) continue;
        const colList = commonCols.map(c => `"${c.replace(/"/g, '""')}"`).join(', ');
        db.exec(`INSERT OR REPLACE INTO main."${escTbl}" (${colList}) SELECT ${colList} FROM src."${escTbl}";`);
        mergedTables++;
    }
    db.exec('COMMIT;');
} catch (err) {
    try { db.exec('ROLLBACK;'); } catch {}
    throw err;
}
db.exec('PRAGMA wal_checkpoint(TRUNCATE);');
db.exec('DETACH DATABASE src;');
db.close();
console.log(JSON.stringify({ mergedTables }));
'@
    $jsTmp = Join-Path $env:TEMP ("agy_sql_merge_" + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.cjs')
    try {
        [IO.File]::WriteAllText($jsTmp, $mergeJs, $Utf8NoBom)
        $out = & $NodeExe $jsTmp $HostDb $OutboxDb 2>&1
        if ($LASTEXITCODE -ne 0) {
            Copy-Item -LiteralPath $bakPath -Destination $HostDb -Force -ErrorAction SilentlyContinue
            throw "SQLite merge failed (restored .bak): $($out -join ' ')"
        }
        return $true
    } finally {
        Remove-Item -LiteralPath $jsTmp -Force -ErrorAction SilentlyContinue
    }
}

function Clear-TokenFile {
    param([string]$TokenFile)
    if ([string]::IsNullOrWhiteSpace($TokenFile)) { return }
    if (Test-Path -LiteralPath $TokenFile -PathType Leaf) {
        try {
            $len = (Get-Item -LiteralPath $TokenFile -Force).Length
            if ($len -gt 0) {
                $zeros = New-Object byte[] $len
                [IO.File]::WriteAllBytes($TokenFile, $zeros)
            }
        } catch {}
        Remove-Item -LiteralPath $TokenFile -Force -ErrorAction SilentlyContinue
    }
}

function Set-PrivateRunDirAcl {
    param([Parameter(Mandatory = $true)][string]$Path)
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        & icacls.exe $Path /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' "*${userSid}:(OI)(CI)F" 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

# ------------------------------------------------------------------------------
# Built-in Offline Self-Test Mode (--self-test)
# ------------------------------------------------------------------------------
function Invoke-SelfTest {
    Write-Host '[Self-Test] Running offline verification suite...' -ForegroundColor Cyan
    $script:SelfTestFailures = 0
    function Assert-True {
        param([bool]$Cond, [string]$Label)
        if ($Cond) {
            Write-Host "  [PASS] $Label" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $Label" -ForegroundColor Red
            $script:SelfTestFailures++
        }
    }

    # 1. Split-CmdLine
    $t1 = Split-CmdLine '"C:\Work\R&D $foo ''bar'' (1)!" --continue --model "a|b"'
    Assert-True ($t1.Count -eq 4 -and $t1[0] -eq 'C:\Work\R&D $foo ''bar'' (1)!' -and $t1[1] -eq '--continue' -and $t1[3] -eq 'a|b') 'Split-CmdLine special chars & quotes'
    $t2 = Split-CmdLine '"D:\" --readonly'
    Assert-True ($t2.Count -eq 2 -and $t2[0] -eq 'D:\' -and $t2[1] -eq '--readonly') 'Split-CmdLine drive root trailing backslash'

    # 2. Normalize-DirPath
    Assert-True ((Normalize-DirPath 'D:\') -eq 'D:\') 'Normalize-DirPath preserves drive root backslash'
    Assert-True ((Normalize-DirPath 'C:\Work\App!\') -eq 'C:\Work\App!') 'Normalize-DirPath trims non-root trailing backslash and keeps !'

    # 3. Test-DangerousRootPath
    $fakeGem = Join-Path $env:USERPROFILE '.gemini'
    Assert-True ($null -ne (Test-DangerousRootPath 'C:\' $fakeGem)) 'DangerousRoot blocks C:\'
    Assert-True ($null -ne (Test-DangerousRootPath $env:USERPROFILE $fakeGem)) 'DangerousRoot blocks USERPROFILE'
    Assert-True ($null -ne (Test-DangerousRootPath (Join-Path $env:USERPROFILE 'Downloads') $fakeGem)) 'DangerousRoot blocks Downloads'
    Assert-True ($null -ne (Test-DangerousRootPath $fakeGem $fakeGem)) 'DangerousRoot blocks .gemini'
    Assert-True ($null -eq (Test-DangerousRootPath (Join-Path $env:USERPROFILE 'Downloads\my-safe-repo') $fakeGem)) 'DangerousRoot allows project subfolder inside Downloads'

    # 4. Get-AutoMemoryInMB
    Assert-True ((Get-AutoMemoryInMB 6144) -eq 6144) 'Get-AutoMemoryInMB honors explicit config'
    $autoMem = Get-AutoMemoryInMB 0
    Assert-True ($autoMem -ge 4096 -and $autoMem -le 8192) "Get-AutoMemoryInMB auto range 4096..8192 ($autoMem)"

    # 5. Build-WsbXml with &, !, Unicode, D:\, both modes
    $unicodeName = 'Jos' + [char]0x00E9 + '_R&D!'
    $projTest = "D:\"
    $xmlYolo = Build-WsbXml -Mode 'yolo' -ProjectDir $projTest -GeminiDir "C:\Users\$unicodeName\.gemini" `
        -AgyHostDir 'C:\Apps\agy' -AgySandboxDir 'C:\Users\WDAGUtilityAccount\AppData\Local\agy' `
        -ToolsCacheDir 'C:\Tools' -BootstrapDir 'C:\Boot' -OutboxDir 'C:\Out' -MemoryInMB 4096 -WsbSettings $Config
    [xml]$parsedYolo = $xmlYolo
    $mYolo = @($parsedYolo.Configuration.MappedFolders.MappedFolder)
    Assert-True ($mYolo.Count -eq 6) 'Build-WsbXml emits 6 mapped folders'
    Assert-True ($mYolo[0].HostFolder -eq 'D:\' -and $mYolo[0].SandboxFolder -eq 'C:\workspace' -and $mYolo[0].ReadOnly -eq 'false') 'Build-WsbXml YOLO mode mapping'
    Assert-True ($mYolo[1].ReadOnly -eq 'true' -and $mYolo[1].HostFolder.Contains('&')) 'Build-WsbXml read-only .gemini and XML-escaped &'
    Assert-True ($mYolo[4].ReadOnly -eq 'true' -and $mYolo[5].ReadOnly -eq 'false') 'Build-WsbXml bootstrap RO and outbox RW'

    $xmlRo = Build-WsbXml -Mode 'readonly' -ProjectDir "C:\Projects\$unicodeName" -GeminiDir "C:\Users\u\.gemini" `
        -AgyHostDir 'C:\Apps\agy' -AgySandboxDir 'C:\Users\WDAGUtilityAccount\AppData\Local\agy' `
        -ToolsCacheDir 'C:\Tools' -BootstrapDir 'C:\Boot' -OutboxDir 'C:\Out' -MemoryInMB 4096 -WsbSettings $Config
    [xml]$parsedRo = $xmlRo
    $mRo = @($parsedRo.Configuration.MappedFolders.MappedFolder)
    Assert-True ($mRo[0].SandboxFolder -eq 'C:\workspace-ro' -and $mRo[0].ReadOnly -eq 'true') 'Build-WsbXml Read-Only workspace mapping'

    # 6. AST Parse all embedded sandbox scripts
    $scripts = @{
        'inject_cred.ps1'      = (Get-InjectCredScript)
        'sandbox-init.ps1'     = (Get-SandboxInitScript)
        'agy-run.ps1'          = (Get-AgyRunScript)
        'sandbox-autosave.ps1' = (Get-SandboxAutosaveScript)
        'sandbox-close.ps1'    = (Get-SandboxCloseScript)
    }
    foreach ($k in $scripts.Keys) {
        $parseErrors = $null
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($scripts[$k], [ref]$tokens, [ref]$parseErrors)
        Assert-True ($parseErrors.Count -eq 0) "AST parse 0 errors for embedded $k"
    }

    # 7. Compile host CredentialReader & test error reporting on missing target; extract & parse sandbox CredentialWriter
    Initialize-HostCredentialTypes
    [int]$err = 0
    $missingCred = [AgyCredentialReader]::Read('agy_nonexistent_selftest_target_99999', [ref]$err)
    Assert-True ($null -eq $missingCred -and ($err -in @(1168, 5, 1312))) "Host AgyCredentialReader reports expected Win32 error on missing target (got $err)"

    $injText = Get-InjectCredScript
    $csMarker = '$csCode = '''
    $startIdx = $injText.IndexOf($csMarker)
    $endIdx   = $injText.IndexOf("`n'", $startIdx + $csMarker.Length)
    $csBlock  = $injText.Substring($startIdx + $csMarker.Length, $endIdx - ($startIdx + $csMarker.Length)).Trim()
    if (-not ('AgyCredentialWriter' -as [type])) {
        Add-Type -TypeDefinition $csBlock
    }
    Assert-True ($null -ne ('AgyCredentialWriter' -as [type])) 'Sandbox AgyCredentialWriter compiles cleanly'

    # 8. Test path traversal protection, argument parser, NTFS junction rejection & concurrent history.jsonl merge
    $travRejected = $false
    try { $null = Resolve-SafeSubPath -BaseDir 'C:\TestBase' -RelPath '..\escape.txt' } catch { $travRejected = $true }
    Assert-True $travRejected 'Resolve-SafeSubPath blocks ..\ traversal'

    $pa1 = Parse-LauncherArguments -Tokens @('--yolo', '--no-dialog', '--continue', '--model', 'test', '--', '--ro') -DefaultDir $env:TEMP
    Assert-True ($pa1.RequestedMode -eq 'yolo' -and $pa1.NoDialog -and $pa1.PassThroughArgs.Count -eq 4 -and $pa1.PassThroughArgs[0] -eq '--continue' -and $pa1.PassThroughArgs[3] -eq '--ro') 'Parse-LauncherArguments forwards agy flags without leaking launcher flags'
    $missingPathRejected = $false
    try { $null = Parse-LauncherArguments -Tokens @('Z:\DefinitelyMissingFolder_99999\proj') -DefaultDir $env:TEMP } catch { $missingPathRejected = $true }
    Assert-True $missingPathRejected 'Parse-LauncherArguments rejects explicit nonexistent drive path'

    $testDir = Join-Path $env:TEMP ('agy_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        $null = New-Item -ItemType Directory -Path (Join-Path $testDir 'real') -Force
        $juncOut = Join-Path $testDir 'outbox'
        $null = New-Item -ItemType Directory -Path $juncOut -Force
        $juncPath = Join-Path $juncOut 'evil_link'
        $juncCreated = $false
        try {
            $null = New-Item -ItemType Junction -Path $juncPath -Target (Join-Path $testDir 'real') -ErrorAction Stop
            $juncCreated = $true
        } catch {
            Write-Host "  [SKIP] Test-SafeOutboxTree junction check skipped ($($_.Exception.Message))" -ForegroundColor DarkYellow
        }
        if ($juncCreated) {
            $rejected = $false
            try { $null = Test-SafeOutboxTree $juncOut } catch { $rejected = $true }
            Assert-True $rejected 'Test-SafeOutboxTree rejects NTFS junction'
        } else {
            Assert-True (Test-SafeOutboxTree $juncOut) 'Test-SafeOutboxTree validates clean outbox directory'
        }

        $aclDir = Join-Path $testDir 'acl_test'
        $null = New-Item -ItemType Directory -Path $aclDir -Force
        $aclOk = Set-PrivateRunDirAcl -Path $aclDir
        $dirSec = [IO.Directory]::GetAccessControl($aclDir)
        $rules = $dirSec.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])
        $sids = @($rules | ForEach-Object { $_.IdentityReference.Value })
        $mySid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        Assert-True ($aclOk -and ($sids -contains 'S-1-5-18') -and ($sids -contains 'S-1-5-32-544') -and ($sids -contains $mySid) -and ($sids -notcontains 'S-1-1-0') -and ($sids -notcontains 'S-1-5-32-545')) 'Set-PrivateRunDirAcl preserves SYSTEM, Administrators, and current user without Everyone/Users'

        $hostHist = Join-Path $testDir 'host_history.jsonl'
        $outHist  = Join-Path $testDir 'outbox_history.jsonl'
        [IO.File]::WriteAllLines($hostHist, [string[]]@('{"id":"host-1"}', '{"id":"host-concurrent"}'), $Utf8NoBom)
        [IO.File]::WriteAllLines($outHist,  [string[]]@('{"id":"host-1"}', '{"id":"sandbox-new"}'),     $Utf8NoBom)
        $baseline = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $null = $baseline.Add('{"id":"host-1"}')
        $added = Merge-HistoryJsonl -HostFile $hostHist -OutboxFile $outHist -BaselineLines $baseline
        $mergedLines = [IO.File]::ReadAllLines($hostHist, $Utf8NoBom)
        Assert-True ($added -eq 1 -and $mergedLines.Count -eq 3 -and ($mergedLines -contains '{"id":"host-concurrent"}') -and ($mergedLines -contains '{"id":"sandbox-new"}')) 'Merge-HistoryJsonl preserves concurrent host entries and appends new sandbox entries'
    } finally {
        Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    if ($script:SelfTestFailures -gt 0) {
        Write-Host "[Self-Test] FAILED ($($script:SelfTestFailures) failure(s))." -ForegroundColor Red
        return 1
    }
    Write-Host '[Self-Test] All checks PASSED.' -ForegroundColor Green
    return 0
}

# ------------------------------------------------------------------------------
# Main Orchestrator
# ------------------------------------------------------------------------------
function Invoke-Main {
    $rawLine = [string]$env:AGY_CMDLINE
    $tokens = Split-CmdLine $rawLine
    $defaultDir = if ([string]::IsNullOrWhiteSpace($env:AGY_LAUNCHER_DIR)) { (Get-Location).Path } else { $env:AGY_LAUNCHER_DIR }
    $parsed = Parse-LauncherArguments -Tokens $tokens -DefaultDir $defaultDir

    if ($parsed.ShowHelp) {
        Show-HelpText
        return 0
    }
    if ($parsed.SelfTest) {
        return (Invoke-SelfTest)
    }

    Write-Host "[Init] Antigravity Safe YOLO Sandbox Launcher v$($Config.Version)" -ForegroundColor Cyan

    # Preflight 1: CPU Architecture
    $arch = Get-HostArch

    # Preflight 2: Windows Sandbox enabled
    $wsbExePath = Join-Path $env:SystemRoot 'System32\WindowsSandbox.exe'
    if (-not (Test-Path -LiteralPath $wsbExePath -PathType Leaf)) {
        throw 'Windows Sandbox is not enabled or not supported on this OS. Enable it via "Turn Windows features on or off".'
    }

    # Preflight 3: Prevent concurrent sandbox collision
    if ((Get-Process -Name 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue)) {
        throw 'A Windows Sandbox instance is already running. Windows Sandbox supports only one active session at a time.'
    }

    # Preflight 4: Locate agy.exe (standard path or PATH fallback)
    $agyExePath = Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'
    if (-not (Test-Path -LiteralPath $agyExePath -PathType Leaf)) {
        $agyCmd = Get-Command 'agy.exe' -ErrorAction SilentlyContinue
        if ($agyCmd -and (Test-Path -LiteralPath $agyCmd.Source -PathType Leaf)) {
            $agyExePath = $agyCmd.Source
        } else {
            throw 'Google Antigravity (agy.exe) was not found on this host machine. Install it first.'
        }
    }
    $agyBinDir  = Split-Path -Parent $agyExePath
    $agyParent  = Split-Path -Parent $agyBinDir
    if (((Split-Path -Leaf $agyBinDir) -ieq 'bin') -and ($agyParent.Length -gt 3)) {
        $agyHostDir    = $agyParent
        $agySandboxDir = 'C:\Users\WDAGUtilityAccount\AppData\Local\agy'
    } else {
        $agyHostDir    = $agyBinDir
        $agySandboxDir = 'C:\Users\WDAGUtilityAccount\AppData\Local\agy\bin'
    }
    $agySandboxExe = 'C:\Users\WDAGUtilityAccount\AppData\Local\agy\bin\agy.exe'

    # Preflight 5: .gemini directory & Dangerous Root guardrail
    $geminiDir = Normalize-DirPath (Join-Path $env:USERPROFILE '.gemini')
    if (-not (Test-Path -LiteralPath $geminiDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $geminiDir -Force
    }
    $projectDir = $parsed.ProjectDir
    $dangerReason = Test-DangerousRootPath -Path $projectDir -GeminiDir $geminiDir
    if ($dangerReason) {
        Write-Host ''
        Write-Host "WARNING: Dangerous workspace root detected: $dangerReason" -ForegroundColor Red
        Write-Host 'Mapping a user/system root into an autonomous AI sandbox risks mass data exposure or destruction.' -ForegroundColor Yellow
        $canPrompt = [Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)
        if (-not $canPrompt) {
            throw "Refusing to launch on dangerous root '$projectDir' in non-interactive mode."
        }
        $confirm = Read-Host 'Type YES (all caps) to proceed anyway, or press Enter to abort'
        if ($confirm -cne 'YES') {
            Write-Host 'Aborted.' -ForegroundColor Yellow
            return 1
        }
    }

    # Preflight 6: Mode Selection Dialog
    $mode = Show-ModeSelectionDialog -ProjectDir $projectDir -RequestedMode $parsed.RequestedMode -NoDialog $parsed.NoDialog
    if (-not $mode) {
        Write-Host '[Init] Cancelled by user.' -ForegroundColor Yellow
        return 0
    }

    # Preflight 7: Check if host agy.exe is concurrently running
    $hostAgyRunning = [bool](Get-Process -Name 'agy' -ErrorAction SilentlyContinue)
    if ($hostAgyRunning) {
        Write-Host '[Warn] agy.exe is currently running on your host. Close it before closing the sandbox to safely merge conversation_summaries.db.' -ForegroundColor Yellow
    }

    $memoryMB = Get-AutoMemoryInMB -ConfiguredMB ([int]$Config.MemoryInMB)
    $allAgyArgs = @($Config.ExtraAgyArgs) + @($parsed.PassThroughArgs.ToArray())

    # Pre-launch Summary Banner
    Write-Host ''
    Write-Host '------------------------------------------------------------------' -ForegroundColor DarkCyan
    Write-Host "  Mode        : $(if ($mode -eq 'readonly') { 'Read-Only / Diff-Only (host workspace RO)' } else { 'Full YOLO (host workspace RW)' })"
    Write-Host "  Project     : $projectDir"
    Write-Host "  Host Arch   : $arch"
    Write-Host "  Memory      : $memoryMB MB | vGPU: $($Config.vGPU) | Clipboard: $($Config.ClipboardRedirection)"
    Write-Host "  MinGit      : $($Config.InstallMinGit) | Autosave: $($Config.AutosaveIntervalMinutes) min | SyncKnowledge: $($Config.SyncKnowledgeBack)"
    if ($allAgyArgs.Count -gt 0) {
        Write-Host "  Extra Args  : $($allAgyArgs -join ' ')"
    }
    Write-Host '------------------------------------------------------------------' -ForegroundColor DarkCyan
    Write-Host ''

    # Step 1: Ensure portable tools are downloaded, SHA256-verified, and pre-extracted on host
    $toolDirs = Ensure-PortableTools -Arch $arch -Cfg $Config

    # Step 2: Extract host credential in memory (extract logic never touches mapped folders)
    Write-Host '[Init] Extracting authentication from Windows Credential Manager...' -ForegroundColor Yellow
    Initialize-HostCredentialTypes
    [int]$credErr = 0
    $credData = [AgyCredentialReader]::Read($Config.CredentialTarget, [ref]$credErr)
    if (-not $credData) {
        throw "Could not read credential '$($Config.CredentialTarget)' from Windows Credential Manager (Win32 error $credErr). Log into agy on the host first."
    }
    Write-Host '  Credential read in memory.' -ForegroundColor Green

    # Record host history.jsonl baseline before launching sandbox
    $hostHistPath = Join-Path $geminiDir 'antigravity-cli\history.jsonl'
    $baselineHist = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $hostHistPath -PathType Leaf) {
        try {
            foreach ($line in ([IO.File]::ReadAllLines($hostHistPath, $Utf8NoBom))) {
                if (-not [string]::IsNullOrWhiteSpace($line)) { $null = $baselineHist.Add($line) }
            }
        } catch {}
    }

    # Step 3: Stage unique per-run directories with strict ACLs
    $runId        = [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $runRoot      = Join-Path $env:TEMP "agy_yolo_run_$runId"
    $bootstrapDir = Join-Path $runRoot 'bootstrap'
    $outboxDir    = Join-Path $runRoot 'outbox'
    $wsbPath      = Join-Path $runRoot 'yolo-sandbox.wsb'
    $tokenPath    = Join-Path $bootstrapDir 'keyring_token.json'

    $null = New-Item -ItemType Directory -Path $runRoot -Force
    if (-not (Set-PrivateRunDirAcl -Path $runRoot)) {
        Write-Host '[Warn] Could not restrict temporary run directory ACLs; continuing with default %TEMP% ACLs.' -ForegroundColor Yellow
    }
    $null = New-Item -ItemType Directory -Path $bootstrapDir -Force
    $null = New-Item -ItemType Directory -Path $outboxDir    -Force

    $launchUtc = [DateTime]::UtcNow

    try {
        # Write credential blob JSON
        $tokenObj = [ordered]@{
            target     = [string]$Config.CredentialTarget
            userName   = [string]$credData.UserName
            blobBase64 = [string]$credData.BlobBase64
        }
        [IO.File]::WriteAllText($tokenPath, ($tokenObj | ConvertTo-Json), $Utf8NoBom)
        $credData = $null

        # Write sandbox bootstrap config & scripts into read-only bootstrap folder
        $bootCfg = [ordered]@{
            mode               = $mode
            hostUser           = $env:USERNAME
            projectName        = (Split-Path -Leaf $projectDir)
            toolDirs           = $toolDirs
            agyExe             = $agySandboxExe
            agyArgs            = $allAgyArgs
            geminiExcludeDirs  = @($Config.GeminiCopyExcludeDirs)
            geminiExcludeFiles = @($Config.GeminiCopyExcludeFiles)
            autosaveIntervalMinutes = [int]$Config.AutosaveIntervalMinutes
            createHostJunction = [bool]$Config.CreateHostProfileJunction
            syncAllowListDirs  = @($Config.SyncAllowListDirs)
            syncKnowledge      = [bool]$Config.SyncKnowledgeBack
        }
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'bootstrap-config.json'), ($bootCfg | ConvertTo-Json -Depth 5), $Utf8NoBom)
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'inject_cred.ps1'),      (Get-InjectCredScript),      $Utf8NoBom)
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'sandbox-init.ps1'),     (Get-SandboxInitScript),     $Utf8NoBom)
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'agy-run.ps1'),          (Get-AgyRunScript),          $Utf8NoBom)
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'sandbox-autosave.ps1'), (Get-SandboxAutosaveScript), $Utf8NoBom)
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'sandbox-close.ps1'),    (Get-SandboxCloseScript),    $Utf8NoBom)

        $pwshRel = "C:\agy-tools\$($toolDirs.pwsh)\pwsh.exe"
        $initCmd = @"
@echo off
title Bootstrapping Antigravity Sandbox...
if exist "$pwshRel" (
    "$pwshRel" -NoProfile -ExecutionPolicy Bypass -File "C:\agy-bootstrap\sandbox-init.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\agy-bootstrap\sandbox-init.ps1"
)
if errorlevel 1 (
    echo ERROR: Bootstrap exited with error %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)
"@
        [IO.File]::WriteAllText((Join-Path $bootstrapDir 'sandbox-init.cmd'), ($initCmd -replace "`r?`n", "`r`n"), [System.Text.Encoding]::ASCII)

        $wsbXml = Build-WsbXml -Mode $mode -ProjectDir $projectDir -GeminiDir $geminiDir `
            -AgyHostDir $agyHostDir -AgySandboxDir $agySandboxDir `
            -ToolsCacheDir $Config.ToolsCacheDir -BootstrapDir $bootstrapDir -OutboxDir $outboxDir `
            -MemoryInMB $memoryMB -WsbSettings $Config

        # Step 4: Launch Windows Sandbox (wsb.exe CLI when available -> direct WindowsSandbox.exe fallback)
        $usedWsbCli = $false
        $wsbSandboxId = $null
        $wsbProc = $null
        $wsbCliCmd = if ($Config.PreferWsbCli) { Get-Command 'wsb.exe' -ErrorAction SilentlyContinue } else { $null }

        if ($wsbCliCmd) {
            Write-Host '[Init] Starting Windows Sandbox via wsb.exe CLI...' -ForegroundColor Yellow
            $wsbXmlCompact = ($wsbXml -replace "`r?`n\s*", '')
            $prevEap = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $startOut = & $wsbCliCmd.Source start --config $wsbXmlCompact 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $joined = ($startOut -join "`n")
                    $m = [regex]::Match($joined, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
                    if ($m.Success) {
                        $wsbSandboxId = $m.Value
                        $connOut = & $wsbCliCmd.Source connect --id $wsbSandboxId 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $usedWsbCli = $true
                            Write-Host "  Connected to sandbox ID: $wsbSandboxId" -ForegroundColor Green
                        } else {
                            Write-Host "  wsb.exe connect failed (exit=$LASTEXITCODE): $($connOut -join ' ')" -ForegroundColor DarkYellow
                            try { & $wsbCliCmd.Source stop --id $wsbSandboxId 2>&1 | Out-Null } catch {}
                            $wsbSandboxId = $null
                        }
                    } else {
                        Write-Host "  wsb.exe start did not return a sandbox ID: $($startOut -join ' ')" -ForegroundColor DarkYellow
                    }
                } else {
                    Write-Host "  wsb.exe start failed (exit=$LASTEXITCODE): $($startOut -join ' ')" -ForegroundColor DarkYellow
                }
                if (-not $usedWsbCli) {
                    Write-Host '  Falling back to WindowsSandbox.exe.' -ForegroundColor DarkYellow
                }
            } catch {
                if ($wsbSandboxId) {
                    try { & $wsbCliCmd.Source stop --id $wsbSandboxId 2>&1 | Out-Null } catch {}
                    $wsbSandboxId = $null
                }
                Write-Host "  wsb.exe error ($($_.Exception.Message)); falling back to WindowsSandbox.exe." -ForegroundColor DarkYellow
            } finally {
                $ErrorActionPreference = $prevEap
            }
        }

        if (-not $usedWsbCli) {
            [IO.File]::WriteAllText($wsbPath, $wsbXml, $Utf8NoBom)
            Write-Host '[Init] Launching Windows Sandbox...' -ForegroundColor Yellow
            $wsbProc = Start-Process -FilePath $wsbExePath -ArgumentList @($wsbPath) -PassThru
            $null = $wsbProc.Handle
        }

        Write-Host '[Host] Monitoring sandbox session (leave this console window open to wipe auth token and sync history on exit)...' -ForegroundColor Cyan

        # Step 5: Monitor sandbox, wipe token on cred_ok.flag or timeout, wait for close
        $credOkFlag = Join-Path $outboxDir 'cred_ok.flag'
        $doneFlag   = Join-Path $outboxDir 'done.flag'
        $tokenWiped = $false
        $wsbDeleted = $false
        $clientSeen = $false
        $sw         = [Diagnostics.Stopwatch]::StartNew()

        while ($true) {
            Start-Sleep -Milliseconds 500

            if (-not $tokenWiped) {
                if ((Test-Path -LiteralPath $credOkFlag) -or ($sw.Elapsed.TotalSeconds -ge $Config.TokenTimeoutSeconds)) {
                    Clear-TokenFile $tokenPath
                    $tokenWiped = $true
                    if (Test-Path -LiteralPath $credOkFlag) {
                        Write-Host '[Host] Auth token injected into sandbox and wiped from host disk.' -ForegroundColor Green
                    } else {
                        Write-Host '[Host] Token timeout reached; wiped auth token from host disk.' -ForegroundColor Yellow
                    }
                }
            }

            $clientProcs = Get-Process -Name 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue
            if ($clientProcs) {
                $clientSeen = $true
                if ((-not $wsbDeleted) -and (Test-Path -LiteralPath $wsbPath)) {
                    Start-Sleep -Seconds 2
                    Remove-Item -LiteralPath $wsbPath -Force -ErrorAction SilentlyContinue
                    $wsbDeleted = $true
                }
            } elseif ((-not $clientSeen) -and $wsbProc -and $wsbProc.HasExited -and ($wsbProc.ExitCode -ne 0)) {
                $hexCode = ('0x{0:X8}' -f $wsbProc.ExitCode)
                Write-Host "[Host] WindowsSandbox.exe exited early with error $($wsbProc.ExitCode) ($hexCode)." -ForegroundColor Red
                break
            }

            if (Test-Path -LiteralPath $doneFlag) {
                Write-Host '[Host] Sandbox signaled clean shutdown and export completion.' -ForegroundColor Green
                # Give WindowsSandboxClient a moment to close; clear any lingering "connection lost" dialog
                for ($w = 0; $w -lt 20; $w++) {
                    if (-not (Get-Process -Name 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue)) { break }
                    Start-Sleep -Milliseconds 500
                }
                $lingering = Get-Process -Name 'WindowsSandboxClient', 'WindowsSandboxRemoteSession' -ErrorAction SilentlyContinue
                if ($lingering) {
                    Write-Host '[Host] Closing lingering Sandbox client window...' -ForegroundColor DarkGray
                    $lingering | Stop-Process -Force -ErrorAction SilentlyContinue
                }
                if ($usedWsbCli -and $wsbSandboxId -and $wsbCliCmd) {
                    try { & $wsbCliCmd.Source stop --id $wsbSandboxId 2>&1 | Out-Null } catch {}
                }
                break
            }

            if ($clientSeen -and (-not $clientProcs)) {
                Write-Host '[Host] Sandbox window closed.' -ForegroundColor Yellow
                break
            }
            if ((-not $clientSeen) -and ($sw.Elapsed.TotalSeconds -ge 90)) {
                Write-Host '[Host] Sandbox client process did not appear within 90s; exiting wait loop.' -ForegroundColor Red
                break
            }
        }

        Clear-TokenFile $tokenPath

        # Step 6: Validate outbox against symlinks/junctions & merge results safely
        $null = Test-SafeOutboxTree $outboxDir

        $syncSource = $null
        if (Test-Path -LiteralPath $doneFlag) {
            $syncSource = Join-Path $outboxDir 'final'
        } elseif (Test-Path -LiteralPath (Join-Path $outboxDir 'autosave')) {
            Write-Host '[Warn] Sandbox exited without using the Desktop closer shortcut; recovering latest periodic autosave (SQLite DB omitted).' -ForegroundColor Yellow
            $syncSource = Join-Path $outboxDir 'autosave'
        }

        $copiedHistoryFiles = 0
        $appendedJsonlLines = 0
        $mergedSqlite = $false

        if ($syncSource -and (Test-Path -LiteralPath $syncSource -PathType Container)) {
            foreach ($relDir in $Config.SyncAllowListDirs) {
                $srcDir = Join-Path $syncSource $relDir
                if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) { continue }
                $srcPrefixLen = $srcDir.TrimEnd('\').Length + 1
                foreach ($f in (Get-ChildItem -LiteralPath $srcDir -Recurse -File -Force)) {
                    $relFile = $f.FullName.Substring($srcPrefixLen)
                    $destPath = Resolve-SafeSubPath -BaseDir $geminiDir -RelPath (Join-Path $relDir $relFile)
                    $copyIt = $false
                    if (-not (Test-Path -LiteralPath $destPath -PathType Leaf)) {
                        $copyIt = $true
                    } else {
                        $destItem = Get-Item -LiteralPath $destPath -Force
                        if ($f.LastWriteTimeUtc -ge $launchUtc.AddSeconds(-5) -and $f.LastWriteTimeUtc -gt $destItem.LastWriteTimeUtc) {
                            $copyIt = $true
                        }
                    }
                    if ($copyIt) {
                        $destParent = Split-Path -Parent $destPath
                        if (-not (Test-Path -LiteralPath $destParent)) {
                            $null = New-Item -ItemType Directory -Path $destParent -Force
                        }
                        Copy-Item -LiteralPath $f.FullName -Destination $destPath -Force
                        $copiedHistoryFiles++
                    }
                }
            }

            $outHistFile = Join-Path $syncSource 'antigravity-cli\history.jsonl'
            $appendedJsonlLines = Merge-HistoryJsonl -HostFile $hostHistPath -OutboxFile $outHistFile -BaselineLines $baselineHist

            $outDbFile  = Join-Path $syncSource 'antigravity-cli\conversation_summaries.db'
            $hostDbFile = Join-Path $geminiDir 'antigravity-cli\conversation_summaries.db'
            if (Test-Path -LiteralPath $outDbFile -PathType Leaf) {
                if (Get-Process -Name 'agy' -ErrorAction SilentlyContinue) {
                    Write-Host ''
                    Write-Host '[Warn] Host agy.exe is currently running. Merging conversation_summaries.db while open could conflict.' -ForegroundColor Yellow
                    $canPrompt = [Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)
                    if ($canPrompt) {
                        $ans = Read-Host 'Close host agy.exe then press Enter to merge DB, or type S to skip DB merge'
                        if ($ans.Trim().ToUpperInvariant() -ne 'S' -and (-not (Get-Process -Name 'agy' -ErrorAction SilentlyContinue))) {
                            $nodeExe = Join-Path (Join-Path $Config.ToolsCacheDir $toolDirs.node) 'node.exe'
                            $mergedSqlite = Merge-HostSqliteDb -NodeExe $nodeExe -HostDb $hostDbFile -OutboxDb $outDbFile
                        } else {
                            Write-Host '[Warn] Skipped conversation_summaries.db merge.' -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host '[Warn] Non-interactive and host agy.exe is running; skipped conversation_summaries.db merge.' -ForegroundColor Yellow
                    }
                } else {
                    $nodeExe = Join-Path (Join-Path $Config.ToolsCacheDir $toolDirs.node) 'node.exe'
                    $mergedSqlite = Merge-HostSqliteDb -NodeExe $nodeExe -HostDb $hostDbFile -OutboxDb $outDbFile
                }
            }
        }

        $knPending = Join-Path $outboxDir 'knowledge_pending'
        if ((Test-Path -LiteralPath $knPending -PathType Container) -and $Config.SyncKnowledgeBack) {
            $knFiles = @(Get-ChildItem -LiteralPath $knPending -Recurse -File -Force)
            if ($knFiles.Count -gt 0 -and [Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)) {
                Write-Host ''
                Write-Host "[Review] Sandbox exported $($knFiles.Count) knowledge file(s):" -ForegroundColor Yellow
                $knFiles | ForEach-Object { Write-Host "  - $($_.FullName.Substring($knPending.Length + 1))" }
                $yn = (Read-Host 'Merge knowledge files into host .gemini? [y/N]').Trim().ToUpperInvariant()
                if ($yn -eq 'Y') {
                    foreach ($kf in $knFiles) {
                        $relKf = $kf.FullName.Substring($knPending.Length + 1)
                        $destKf = Resolve-SafeSubPath -BaseDir $geminiDir -RelPath (Join-Path 'antigravity-cli\knowledge' $relKf)
                        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destKf) -Force
                        Copy-Item -LiteralPath $kf.FullName -Destination $destKf -Force
                    }
                }
            }
        }

        # Step 7: Export Read-Only mode workspace patch/files to %TEMP%
        $patchExportedTo = $null
        $chgSrc = Join-Path $outboxDir 'workspace_changes'
        if ($mode -eq 'readonly' -and (Test-Path -LiteralPath $chgSrc -PathType Container)) {
            $hasFiles   = (Get-ChildItem -LiteralPath (Join-Path $chgSrc 'files') -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
            $hasDeleted = (Test-Path -LiteralPath (Join-Path $chgSrc 'deleted_files.txt') -PathType Leaf)
            $hasPatch   = (Test-Path -LiteralPath (Join-Path $chgSrc 'changes.patch') -PathType Leaf)
            if ($hasFiles -or $hasDeleted -or $hasPatch) {
                $safeProj = ((Split-Path -Leaf $projectDir) -replace '[^A-Za-z0-9_.-]', '_')
                if ([string]::IsNullOrWhiteSpace($safeProj)) { $safeProj = 'workspace' }
                $exportName = "{0}_{1}" -f $safeProj, (Get-Date -Format 'yyyyMMdd_HHmmss')
                $patchExportedTo = Join-Path $Config.PatchExportRoot $exportName
                if (Test-Path -LiteralPath $patchExportedTo) {
                    $patchExportedTo = Join-Path $Config.PatchExportRoot "${exportName}_$runId"
                }
                $null = New-Item -ItemType Directory -Path $patchExportedTo -Force
                foreach ($chgItem in (Get-ChildItem -LiteralPath $chgSrc -Force)) {
                    Copy-Item -LiteralPath $chgItem.FullName -Destination $patchExportedTo -Recurse -Force
                }
            }
        }

        # Step 8: Summary & Safety Reminder
        Write-Host ''
        Write-Host '================ Session Summary ================' -ForegroundColor Cyan
        Write-Host "  History files synced : $copiedHistoryFiles"
        Write-Host "  history.jsonl lines  : +$appendedJsonlLines"
        Write-Host "  SQLite DB merged     : $mergedSqlite"
        if ($mode -eq 'readonly') {
            if ($patchExportedTo) {
                Write-Host "  Exported Changes     : $patchExportedTo" -ForegroundColor Green
                if (Test-Path -LiteralPath (Join-Path $patchExportedTo 'summary.txt')) {
                    Get-Content -LiteralPath (Join-Path $patchExportedTo 'summary.txt') | ForEach-Object { Write-Host "    $_" }
                }
                Write-Host "  Review files in 'files\' or apply patch with: git apply `"$patchExportedTo\changes.patch`"" -ForegroundColor DarkGray
            } else {
                Write-Host '  Exported Changes     : None (no workspace modifications detected)'
            }
        } else {
            Write-Host '  Reminder: Review workspace changes with `git status` and inspect `.git\hooks` before running project scripts on your host.' -ForegroundColor Yellow
        }
        Write-Host '=================================================' -ForegroundColor Cyan
        return 0
    } finally {
        Clear-TokenFile $tokenPath
        if (Test-Path -LiteralPath $runRoot) {
            Remove-Item -LiteralPath $runRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    $code = Invoke-Main
    exit $code
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ([Environment]::UserInteractive -and (-not [Console]::IsInputRedirected)) {
        Write-Host ''
        Read-Host 'Press Enter to exit'
    }
    exit 1
}
