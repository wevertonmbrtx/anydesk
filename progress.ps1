param(
    [ValidateSet('installed', 'portable', 'auto')]
    [string]$Mode = 'auto'
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::CursorVisible = $false

$windowCols   = 36
$windowRows   = 3
$fallbackRows = 4

try {
    $sz = New-Object System.Management.Automation.Host.Size($windowCols, $windowRows)
    $host.UI.RawUI.WindowSize = $sz
    $host.UI.RawUI.BufferSize = $sz
} catch {
    try {
        $sz = New-Object System.Management.Automation.Host.Size($windowCols, $fallbackRows)
        $host.UI.RawUI.WindowSize = $sz
        $host.UI.RawUI.BufferSize = $sz
    } catch {}
}

[Console]::Clear()

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern int    GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")]   public static extern int    SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")]   public static extern bool   ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]   public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr LoadImage(IntPtr hinst, string name, uint type, int cx, int cy, uint fuLoad);
    public const int  GWL_EXSTYLE      = -20;
    public const int  WS_EX_TOOLWINDOW = 0x00000080;
    public const int  WS_EX_APPWINDOW  = 0x00040000;
    public const uint WM_SETICON       = 0x0080;
    public const uint IMAGE_ICON       = 1;
    public const uint LR_LOADFROMFILE  = 0x0010;
    public const uint LR_DEFAULTSIZE   = 0x0040;
}
"@ -ErrorAction SilentlyContinue

try {
    $hwnd  = [WinConsole]::GetConsoleWindow()
    $style = [WinConsole]::GetWindowLong($hwnd, [WinConsole]::GWL_EXSTYLE)
    $style = ($style -bor [WinConsole]::WS_EX_TOOLWINDOW) -band (-bnot [WinConsole]::WS_EX_APPWINDOW)
    [WinConsole]::ShowWindow($hwnd, 0) | Out-Null
    [WinConsole]::SetWindowLong($hwnd, [WinConsole]::GWL_EXSTYLE, $style) | Out-Null
    [WinConsole]::ShowWindow($hwnd, 5) | Out-Null

    $iconPath = Join-Path $env:LOCALAPPDATA 'AnyDeskLauncher\anydesk.ico'
    if (Test-Path $iconPath) {
        $hIcon = [WinConsole]::LoadImage([IntPtr]::Zero, $iconPath, [WinConsole]::IMAGE_ICON, 0, 0,
            [WinConsole]::LR_LOADFROMFILE -bor [WinConsole]::LR_DEFAULTSIZE)
        if ($hIcon -ne [IntPtr]::Zero) {
            [WinConsole]::SendMessage($hwnd, [WinConsole]::WM_SETICON, [IntPtr]1, $hIcon) | Out-Null
            [WinConsole]::SendMessage($hwnd, [WinConsole]::WM_SETICON, [IntPtr]0, $hIcon) | Out-Null
        }
    }
} catch {}

if ($Mode -eq 'auto') {
    $p86  = "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
    $p64  = "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
    $Mode = if ((Test-Path $p86) -or (Test-Path $p64)) { 'installed' } else { 'portable' }
}

$barWidth = 20
$confDir  = Join-Path $env:ALLUSERSPROFILE 'AnyDesk'
$porPath0 = Join-Path $env:TEMP 'AnyDesk.exe'

function Limit-Text([string]$Text, [int]$MaxLength = $windowCols) {
    if ($null -eq $Text) { return '' }
    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, [math]::Max(0, $MaxLength - 3)) + '...'
}

function Write-Bar([int]$p, [string]$status = '') {
    $f      = [math]::Floor($p * $barWidth / 100)
    $e      = $barWidth - $f
    $status = Limit-Text $status $windowCols
    $host.UI.RawUI.WindowTitle = "AnyDesk  $p%"
    try {
        [Console]::SetCursorPosition(0, 0)
        [Console]::Write(('AnyDesk Reset').PadRight($windowCols))
        [Console]::SetCursorPosition(0, 1)
        [Console]::Write('[' + ('=' * $f) + ('-' * $e) + ']' + "$p%".PadLeft(5))
        [Console]::SetCursorPosition(0, 2)
        [Console]::Write($status.PadRight($windowCols))
    } catch {}
}

function Test-AnyDeskRunning {
    return [bool](Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue)
}

function Test-AnyDeskWindow {
    $p = Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue
    return $p -and ($p | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
}

function Test-ServiceStopped {
    $s = Get-Service -Name 'AnyDesk' -ErrorAction SilentlyContinue
    if (-not $s) { return $true }
    return $s.Status -eq 'Stopped'
}

function Test-ConfCleared {
    if (-not (Test-Path $confDir)) { return $true }
    return -not (Get-ChildItem "$confDir\*.conf" -ErrorAction SilentlyContinue)
}

function Invoke-Stage {
    param(
        [string]$Label,
        [int]$StartPct,
        [int]$EndPct,
        [int]$TimeoutMs,
        [int]$PollMs,
        [scriptblock]$DoneCondition,
        [scriptblock]$RatioProvider
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($true) {
        if (& $DoneCondition) {
            Write-Bar $EndPct $Label
            return $true
        }

        $elapsedMs = [int]$sw.ElapsedMilliseconds
        if ($elapsedMs -ge $TimeoutMs) {
            Write-Bar $EndPct $Label
            return $false
        }

        $ratio = if ($null -ne $RatioProvider) {
            [double](& $RatioProvider)
        } else {
            [double]$elapsedMs / [double]$TimeoutMs
        }

        $ratio = [math]::Max(0.0, [math]::Min(0.99, $ratio))
        $span  = [math]::Max(1, $EndPct - $StartPct)
        $pct   = [math]::Max($StartPct, [math]::Min($EndPct - 1, [int][math]::Floor($StartPct + $span * $ratio)))

        Write-Bar $pct $Label
        Start-Sleep -Milliseconds $PollMs
    }
}

Write-Bar 0 'Initializing...'

if ($Mode -eq 'portable') {
    Invoke-Stage 'Downloading AnyDesk...' 0 30 180000 400 {
        (Test-Path $porPath0) -and ((Get-Item $porPath0 -ErrorAction SilentlyContinue).Length -ge 4000000)
    } {
        if (-not (Test-Path $porPath0)) { return 0.0 }
        [math]::Min(0.99, [double](Get-Item $porPath0 -ErrorAction SilentlyContinue).Length / 5000000)
    } | Out-Null

    $opened = Invoke-Stage 'Opening AnyDesk...' 30 100 300000 400 {
        Test-AnyDeskWindow
    } $null

    if (-not $opened) {
        while (-not (Test-AnyDeskWindow)) {
            Write-Bar 99 'Opening AnyDesk...'
            Start-Sleep -Milliseconds 400
        }
    }

    Write-Bar 100 'Done.'
    Start-Sleep -Milliseconds 1200
    [Console]::CursorVisible = $true
    exit 0
}

Invoke-Stage 'Stopping AnyDesk...' 0 18 30000 400 {
    (-not (Test-AnyDeskRunning)) -and (Test-ServiceStopped)
} $null | Out-Null

Invoke-Stage 'Clearing configuration...' 18 30 20000 300 {
    Test-ConfCleared
} $null | Out-Null

$opened = Invoke-Stage 'Opening AnyDesk...' 30 100 120000 400 {
    Test-AnyDeskWindow
} $null

if (-not $opened) {
    while (-not (Test-AnyDeskWindow)) {
        Write-Bar 99 'Opening AnyDesk...'
        Start-Sleep -Milliseconds 400
    }
}

Write-Bar 100 'Done.'
Start-Sleep -Milliseconds 1200
[Console]::CursorVisible = $true
