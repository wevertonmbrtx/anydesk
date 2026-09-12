$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$desktop   = [Environment]::GetFolderPath('Desktop')
$iconDir   = Join-Path $env:LOCALAPPDATA 'AnyDeskLauncher'
$iconPath  = Join-Path $iconDir 'anydesk.ico'
$lnkPath   = Join-Path $desktop 'AnyDesk.lnk'
$batchPath = Join-Path $env:TEMP 'initad.bat'
$progPath  = Join-Path $env:TEMP 'progress.ps1'
$batchUrl  = 'https://wevertonmbrtx.github.io/anydesk/initad.bat'
$iconUrl   = 'https://dl.flathub.org/repo/appstream/x86_64/icons/128x128/com.anydesk.Anydesk.png'

$webClient = New-Object Net.WebClient
$webClient.Headers.Add('User-Agent', 'Mozilla/5.0')

try {
    if (-not (Test-Path $iconDir)) {
        New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
    }

    $pngBytes = $webClient.DownloadData($iconUrl)

    # Dimensões do PNG (cabeçalho IHDR, big-endian: largura no offset 16, altura no 20)
    $width  = ($pngBytes[16] * 16777216) + ($pngBytes[17] * 65536) + ($pngBytes[18] * 256) + $pngBytes[19]
    $height = ($pngBytes[20] * 16777216) + ($pngBytes[21] * 65536) + ($pngBytes[22] * 256) + $pngBytes[23]
    if ($width  -ge 256) { $width  = 0 }
    if ($height -ge 256) { $height = 0 }

    # Empacota o PNG dentro de um ICO (o atalho do Windows exige .ico, não .png)
    $icoBytes = New-Object System.Collections.Generic.List[byte]
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]0))   # reservado
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]1))   # tipo (1 = ícone)
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]1))   # nº de imagens
    $icoBytes.Add([byte]$width)
    $icoBytes.Add([byte]$height)
    $icoBytes.Add([byte]0)                                           # cores da paleta
    $icoBytes.Add([byte]0)                                           # reservado
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]1))   # planos
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt16]32))  # bits por pixel
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt32]$pngBytes.Length))
    $icoBytes.AddRange([System.BitConverter]::GetBytes([UInt32]22))  # offset dos dados da imagem
    $icoBytes.AddRange($pngBytes)

    [System.IO.File]::WriteAllBytes($iconPath, $icoBytes.ToArray())
} catch {
    Write-Warning "Can't create icon: $_"
}

$url = 'https://wevertonmbrtx.github.io/anydesk/initad.bat'
$q   = [char]34
$a   = [char]38

$cmd = '%SystemRoot%\System32\cmd.exe'
$tmp = '%TEMP%\initad.bat'

if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $lnkArgs = '/c ' + $q + 'curl -s -o ' + $q + $tmp + $q + ' ' + $q + $url + $q + ' ' + $a + ' call ' + $q + $tmp + $q + $q
} else {
    $lnkArgs = '/c ' + $q + 'certutil -urlcache -split -f ' + $q + $url + $q + ' ' + $q + $tmp + $q + ' ' + $a + ' ' + $q + $tmp + $q + $q
}

try {
    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($ws.SpecialFolders.Item('Desktop') + '\AnyDesk.lnk')
    $lnk.TargetPath  = $cmd
    $lnk.Arguments   = $lnkArgs
    $lnk.WindowStyle = 1
    $lnk.Description = 'AnyDesk Reset'
    if (Test-Path $iconPath) { $lnk.IconLocation = "$iconPath,0" }
    $lnk.Save()
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
    