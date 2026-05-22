param(
    [ValidateSet('installed', 'portable', 'auto')]
    [string]$Mode = 'auto'
)

$ErrorActionPreference = 'SilentlyContinue'
$host.UI.RawUI.WindowTitle = 'AnyDesk'
[Console]::CursorVisible = $false

try {
    $sz = New-Object System.Management.Automation.Host.Size(28, 2)
    $host.UI.RawUI.WindowSize = $sz
    $host.UI.RawUI.BufferSize = $sz
} catch {
    try {
        $sz = New-Object System.Management.Automation.Host.Size(28, 4)
        $host.UI.RawUI.WindowSize = $sz
        $host.UI.RawUI.BufferSize = $sz
    } catch {}
}

[Console]::Clear()

if ($Mode -eq 'auto') {
    $p86 = "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
    $p64 = "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
    $Mode = if ((Test-Path $p86) -or (Test-Path $p64)) { 'installed' } else { 'portable' }
}

# Installed: ~45s to fill 95% (only service restart + wait new ID)
# Portable : ~120s to fill 95% (includes download + install)
$barWidth = 20
$budget   = if ($Mode -eq 'portable') { 120 } else { 45 }
$stepMs   = [int]($budget * 1000 / 95)

function Draw-Bar([int]$p) {
    $f = [math]::Floor($p * $barWidth / 100)
    $e = $barWidth - $f
    try {
        [Console]::SetCursorPosition(0, 0)
        [Console]::Write('Loading AnyDesk...          ')
        [Console]::SetCursorPosition(0, 1)
        [Console]::Write('[' + ('0' * $f) + (' ' * $e) + ']' + "$p%".PadLeft(5))
    } catch {}
}

function Test-AnyDeskWindow {
    $p = Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue
    return $p -and ($p | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
}

Draw-Bar 0
$pct = 0

while ($true) {
    if (Test-AnyDeskWindow) {
        Draw-Bar 100
        break
    }
    if ($pct -lt 95) {
        Start-Sleep -Milliseconds $stepMs
        $pct++
        Draw-Bar $pct
    } else {
        Start-Sleep -Milliseconds 500
    }
}

Start-Sleep -Milliseconds 800
[Console]::CursorVisible = $true
