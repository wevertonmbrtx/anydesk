param(
    [ValidateSet('installed', 'portable', 'auto')]
    [string]$Mode = 'auto'
)

$ErrorActionPreference = 'SilentlyContinue'
$host.UI.RawUI.WindowTitle = 'AnyDesk'
[Console]::CursorVisible = $false

$windowCols = 36
$windowRows = 3
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

if ($Mode -eq 'auto') {
    $p86 = "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe"
    $p64 = "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
    $Mode = if ((Test-Path $p86) -or (Test-Path $p64)) { 'installed' } else { 'portable' }
}

$barWidth = 20
$sysConf  = Join-Path $env:ALLUSERSPROFILE 'AnyDesk\system.conf'
$insPath0 = Join-Path ${env:ProgramFiles(x86)} 'AnyDesk\AnyDesk.exe'
$insPath1 = Join-Path $env:ProgramFiles 'AnyDesk\AnyDesk.exe'
$porPath0 = Join-Path $env:TEMP 'AnyDesk.exe'

function Limit-Text([string]$Text, [int]$MaxLength = $windowCols) {
    if ($null -eq $Text) { return '' }
    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, [math]::Max(0, $MaxLength - 3)) + '...'
}

function Draw-Bar([int]$p, [string]$status = '') {
    $f = [math]::Floor($p * $barWidth / 100)
    $e = $barWidth - $f
    $status = Limit-Text $status $windowCols
    try {
        [Console]::SetCursorPosition(0, 0)
        [Console]::Write(('Loading AnyDesk...').PadRight($windowCols))
        [Console]::SetCursorPosition(0, 1)
        [Console]::Write('[' + ('O' * $f) + (' ' * $e) + ']' + "$p%".PadLeft(5))
        [Console]::SetCursorPosition(0, 2)
        [Console]::Write($status.PadRight($windowCols))
    } catch {}
}

function Test-AnyDeskWindow {
    $p = Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue
    return $p -and ($p | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
}

function Test-ServiceRegistered {
    sc.exe query 'AnyDesk' > $null 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Test-InstalledAnyDesk {
    return (Test-Path $insPath0) -or (Test-Path $insPath1)
}

function Test-NewId {
    if (-not (Test-Path $sysConf)) { return $false }
    return Select-String -Path $sysConf -Pattern '^ad\.anynet\.id=' -Quiet
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
            Draw-Bar $EndPct $Label
            return $true
        }

        $elapsedMs = [int]$sw.ElapsedMilliseconds
        if ($elapsedMs -ge $TimeoutMs) {
            Draw-Bar $EndPct $Label
            return $false
        }

        $ratio = if ($null -ne $RatioProvider) {
            [double](& $RatioProvider)
        } else {
            [double]$elapsedMs / [double]$TimeoutMs
        }

        if ($ratio -lt 0) { $ratio = 0 }
        if ($ratio -gt 0.99) { $ratio = 0.99 }

        $span = [math]::Max(1, $EndPct - $StartPct)
        $pct  = [int]([math]::Floor($StartPct + ($span * $ratio)))
        if ($pct -lt $StartPct) { $pct = $StartPct }
        if ($pct -ge $EndPct) { $pct = $EndPct - 1 }

        Draw-Bar $pct $Label
        Start-Sleep -Milliseconds $PollMs
    }
}

Draw-Bar 0 'Initializing'

$sawAbsent = -not (Test-AnyDeskWindow)

if ($Mode -eq 'portable') {
    Invoke-Stage 'Downloading portable' 0 35 180000 400 {
        (Test-Path $porPath0) -and ((Get-Item $porPath0 -ErrorAction SilentlyContinue).Length -ge 2097152)
    } {
        if (-not (Test-Path $porPath0)) { return 0 }
        $size = (Get-Item $porPath0 -ErrorAction SilentlyContinue).Length
        return [math]::Min(0.99, [double]$size / 6000000)
    } | Out-Null

    Invoke-Stage 'Waiting install/service registration...' 35 60 120000 600 {
        (Test-InstalledAnyDesk) -and (Test-ServiceRegistered)
    } $null | Out-Null
}

Invoke-Stage 'Resetting session' (if ($Mode -eq 'portable') { 60 } else { 0 }) (if ($Mode -eq 'portable') { 78 } else { 28 }) 35000 400 {
    $visible = Test-AnyDeskWindow
    if (-not $visible) { $script:sawAbsent = $true }
    return $script:sawAbsent
} $null | Out-Null

Invoke-Stage 'Generating new ID' (if ($Mode -eq 'portable') { 78 } else { 28 }) (if ($Mode -eq 'portable') { 95 } else { 90 }) 70000 500 {
    Test-NewId
} $null | Out-Null

$opened = Invoke-Stage 'Opening app' (if ($Mode -eq 'portable') { 95 } else { 90 }) 100 90000 400 {
    $visible = Test-AnyDeskWindow
    if (-not $visible) { $script:sawAbsent = $true }
    return $visible
} $null

if (-not $opened) {
    while (-not (Test-AnyDeskWindow)) {
        Draw-Bar 99 'Waiting for app'
        Start-Sleep -Milliseconds 400
    }
}

Draw-Bar 100 'Finished.'

Start-Sleep -Milliseconds 800
[Console]::CursorVisible = $true
