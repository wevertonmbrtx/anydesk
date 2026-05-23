@echo off
cls
title AnyDesk
mode con:cols=70 lines=27
chcp 437 >nul

cls
 
setlocal EnableExtensions EnableDelayedExpansion
 
set "batchPath=%~f0"
set "service=AnyDesk"
set "sys=%SystemRoot%\System32"

set "insPath0=%ProgramFiles(x86)%\AnyDesk\AnyDesk.exe"
set "insPath1=%ProgramFiles%\AnyDesk\AnyDesk.exe"
set "porPath0=%TEMP%\AnyDesk.exe"

set "selfPath=%TEMP%\initad.bat"
set "progPath=%TEMP%\progress.ps1"
set "selfUrl=https://wevertonmbrtx.github.io/anydesk/initad.bat"
set "progUrl=https://wevertonmbrtx.github.io/anydesk/progress.ps1"
 
set "url=https://download.anydesk.com/AnyDesk.exe"
 
set "sysConf=%ALLUSERSPROFILE%\AnyDesk\system.conf"
set "userConf=%APPDATA%\AnyDesk\user.conf"
set "userConfBak=%TEMP%\anydesk_user.conf"
 
for %%k in ("%~f0") do set "batchName=%%~nk"
set "_elev=%TEMP%\elev_!batchName!.vbs"
 
:check_privileges
"%sys%\whoami.exe" /groups /nh | "%sys%\find.exe" "S-1-16-12288" 1>nul
if errorlevel 1 goto get_privileges
"%sys%\net.exe" session 1>nul 2>nul
if not errorlevel 1 goto got_privileges
 
:get_privileges
if "%~1"=="ELEV" (shift /1 & goto got_privileges)
>  "!_elev!" echo Set UAC = CreateObject^("Shell.Application"^)
>> "!_elev!" echo args = "ELEV "
>> "!_elev!" echo For Each strArg in WScript.Arguments
>> "!_elev!" echo args = args ^& strArg ^& " "
>> "!_elev!" echo Next
>> "!_elev!" echo args = "/c """ + "!batchPath!" + """ " + args
>> "!_elev!" echo UAC.ShellExecute "%sys%\cmd.exe", args, "", "runas", 0
"%sys%\WScript.exe" "!_elev!" %*
exit /B
 
:got_privileges
cd /d "%~dp0"
if "%~1"=="ELEV" (del "!_elev!" 1>nul 2>nul & shift /1)
 
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v SecureProtocols /t REG_DWORD /d 0x00000A80 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f >nul 2>&1
 
:run
call :check_ps
if errorlevel 1 goto :eof
 
call :create_shortcut
call :detect_install
 
if defined _exe (
    call :start_progress installed
) else (
    call :start_progress portable
    call :install_portable
    if errorlevel 1 goto :eof
    call :detect_install
    if not defined _exe (
        echo Finished.
        timeout /t 2 >nul
        goto :eof
    )
)
 
sc query "%service%" >nul 2>&1
if errorlevel 1 (
    echo Service not registered.
    timeout /t 2 >nul
    goto :eof
)
 
del /f /q "%porPath0%" >nul 2>&1
call :reset_id
call :open_app
echo Finished.
timeout /t 2 >nul
goto :eof
 
 
:detect_install
set "_exe="
if exist "%insPath0%" set "_exe=%insPath0%"
if not defined _exe if exist "%insPath1%" set "_exe=%insPath1%"
exit /b 0
 
 
:reset_id
echo Stopping AnyDesk...
sc stop "%service%" >nul 2>&1
taskkill /f /im "AnyDesk.exe" >nul 2>&1
timeout /t 2 >nul
 
copy /y "%userConf%" "%userConfBak%" >nul 2>&1
del /f /q "%ALLUSERSPROFILE%\AnyDesk\*.conf" 2>nul
del /f /q "%APPDATA%\AnyDesk\*.conf"         2>nul
rd  /s /q "%LOCALAPPDATA%\AnyDesk"           2>nul
 
cls
echo Initializing AnyDesk...
sc start "%service%" >nul 2>&1
call :wait_new_id
exit /b 0
 
 
:wait_service_registered
set /a _c=0
:_wsr_loop
sc query "%service%" >nul 2>&1
if not errorlevel 1 exit /b 0
timeout /t 1 >nul
set /a _c+=1
if !_c! lss 30 goto _wsr_loop
exit /b 1
 
 
:wait_new_id
set /a _c=0
:_wni_loop
find "ad.anynet.id=" "%sysConf%" >nul 2>&1
if not errorlevel 1 goto _wni_found
timeout /t 1 >nul
set /a _c+=1
if !_c! lss 60 goto _wni_loop
echo Warning: timeout waiting new ID.
exit /b 1
:_wni_found
for /f "tokens=2 delims==" %%i in ('find "ad.anynet.id=" "%sysConf%" 2^>nul') do echo ID: %%i
exit /b 0
 
 
:open_app
if exist "%userConfBak%" move /y "%userConfBak%" "%userConf%" >nul 2>&1
sc stop "%service%" >nul 2>&1
taskkill /f /im "AnyDesk.exe" >nul 2>&1
timeout /t 2 >nul
start "" /wait "%_exe%"
taskkill /f /im "AnyDesk.exe" >nul 2>&1
exit /b 0
 
 
:install_portable
echo Downloading "AnyDesk.exe"...
call :download "%url%" "%porPath0%"
if errorlevel 1 exit /b 1
 
echo Executing portable version...
start "" /wait "%porPath0%"
 
echo Waiting installation to finish...
set /a _c=0
:_wip_loop
if exist "%insPath0%" goto _wip_check_service
if exist "%insPath1%" goto _wip_check_service
timeout /t 1 >nul
set /a _c+=1
if !_c! lss 60 goto _wip_loop
goto _wip_cleanup
 
:_wip_check_service
echo Waiting service registration...
call :wait_service_registered
 
:_wip_cleanup
taskkill /f /im "AnyDesk.exe" >nul 2>&1
timeout /t 2 >nul
del /f /q "%porPath0%"            2>nul
del /f /q "%TEMP%\gcapi.dll"     2>nul
rd  /s /q "%APPDATA%\AnyDesk"    2>nul
call :detect_install
if not defined _exe exit /b 0
call :create_shortcut
exit /b 0
 
 
:create_shortcut
del /f /q "%USERPROFILE%\Desktop\AnyDesk*.lnk" 2>nul
del /f /q "%PUBLIC%\Desktop\AnyDesk*.lnk"      2>nul
set "_lnk=%TEMP%\_lnk.ps1"
>  "%_lnk%" echo $dp  = [Environment]::GetFolderPath('Desktop')
>> "%_lnk%" echo $lp  = Join-Path $dp 'AnyDesk.lnk'
>> "%_lnk%" echo $q   = [char]34
>> "%_lnk%" echo $aa  = [char]38 + [char]38
>> "%_lnk%" echo $oo  = [char]124 + [char]124
>> "%_lnk%" echo $gt  = [char]62
>> "%_lnk%" echo $url = 'https://wevertonmbrtx.github.io/anydesk/initad.bat'
>> "%_lnk%" echo $tmp = '%%TEMP%%\initad.bat'
>> "%_lnk%" echo $cmdExe  = $env:SystemRoot + '\System32\cmd.exe'
>> "%_lnk%" echo $curlCmd = 'curl -s -o ' + $q + $tmp + $q + ' ' + $q + $url + $q + ' ' + $aa + ' call ' + $q + $tmp + $q
>> "%_lnk%" echo $certCmd = 'certutil -urlcache -split -f ' + $q + $url + $q + ' ' + $q + $tmp + $q + ' ' + $aa + ' ' + $q + $tmp + $q
>> "%_lnk%" echo $check   = 'where curl 1' + $gt + 'nul 2' + $gt + 'nul'
>> "%_lnk%" echo $lnkArgs = '/c ' + $q + $check + ' ' + $aa + ' (' + $curlCmd + ') ' + $oo + ' (' + $certCmd + ')' + $q
>> "%_lnk%" echo $ws  = New-Object -ComObject WScript.Shell
>> "%_lnk%" echo $lnk = $ws.CreateShortcut($lp)
>> "%_lnk%" echo $lnk.TargetPath  = $cmdExe
>> "%_lnk%" echo $lnk.Arguments   = $lnkArgs
>> "%_lnk%" echo $lnk.WindowStyle = 1
>> "%_lnk%" echo $lnk.Description = 'AnyDesk Reset'
>> "%_lnk%" echo $ic = Join-Path $env:LOCALAPPDATA 'AnyDeskLauncher\anydesk.ico'
>> "%_lnk%" echo if (Test-Path $ic) { $lnk.IconLocation = $ic + ',0' }
>> "%_lnk%" echo $lnk.Save()
powershell -NoProfile -ExecutionPolicy Bypass -File "%_lnk%"
del /f /q "%_lnk%" >nul 2>&1
exit /b 0
 
 
:start_progress
if not exist "%progPath%" call :download "%progUrl%" "%progPath%"
if exist "%progPath%" start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "%progPath%" -Mode %~1
exit /b 0
 
 
:download
set "_dlUrl=%~1"
set "_dlOut=%~2"
if exist "%_dlOut%" exit /b 0
 
where curl >nul 2>&1 && curl -L -s --max-time 120 -o "%_dlOut%" "!_dlUrl!"
if exist "%_dlOut%" exit /b 0
 
certutil -urlcache -split -f "!_dlUrl!" "%_dlOut%" >nul 2>&1
if exist "%_dlOut%" exit /b 0
 
call :vbs_download "!_dlUrl!" "%_dlOut%"
if exist "%_dlOut%" exit /b 0
 
echo Download error: "!_dlOut!"
exit /b 1
 
 
:check_ps
if not exist "%sys%\WindowsPowerShell\v1.0\powershell.exe" (
    echo PowerShell not found. Cannot continue.
    pause
    exit /b 1
)
powershell -NoProfile -Command "exit ([int]$PSVersionTable.PSVersion.Major)" 2>nul
set "_psver=%errorlevel%"
if %_psver% GEQ 3 exit /b 0

echo PowerShell %_psver%.x found. Version 3+ required.
echo Preparing automatic setup of prerequisites...

if /i not "!batchPath!"=="%selfPath%" copy /y "!batchPath!" "%selfPath%" >nul 2>&1
call :install_dotnet45
if errorlevel 1 exit /b 1
call :install_wmf50
exit /b %errorlevel%
 
 
:install_dotnet45
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >nul 2>&1
if not errorlevel 1 exit /b 0
echo .NET Framework 4.5 not found. Downloading (~65 MB^)...
set "_dnFile=%TEMP%\dotnet45_setup.exe"
set "_dnUrl=https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe"
call :download "!_dnUrl!" "!_dnFile!"
if not exist "!_dnFile!" (
    echo ERROR: Could not download .NET 4.5. Check internet connection.
    pause
    exit /b 1
)
echo Installing .NET Framework 4.5 (this may take several minutes^)...
"!_dnFile!" /q /norestart
set "_ec=%errorlevel%"
del /f /q "!_dnFile!" >nul 2>&1
if %_ec%==0    exit /b 0
if %_ec%==3010 goto _setup_reboot
if %_ec%==1641 goto _setup_reboot
echo ERROR: .NET 4.5 setup failed (code %_ec%^).
pause
exit /b 1
 
 
:install_wmf50
set "_arch=x86"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "_arch=x64"
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "_arch=x64"
set "_wmfFile=%TEMP%\wmf50_!_arch!.msu"
if /i "!_arch!"=="x64" (
    set "_wmfUrl=https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win7AndW2K8R2-KB3134760-x64.msu"
) else (
    set "_wmfUrl=https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win7-KB3134760-x86.msu"
)
echo Downloading Windows Management Framework 5.0 (!_arch!^)...
call :download "!_wmfUrl!" "!_wmfFile!"
if not exist "!_wmfFile!" (
    echo ERROR: Could not download WMF 5.0. Check internet connection.
    pause
    exit /b 1
)
echo Installing Windows Management Framework 5.0...
wusa "!_wmfFile!" /quiet /norestart
set "_ec=%errorlevel%"
del /f /q "!_wmfFile!" >nul 2>&1
if %_ec%==2359302 ( echo WMF 5.0 already installed. & exit /b 0 )
if %_ec%==0    goto _setup_reboot
if %_ec%==3010 goto _setup_reboot
echo ERROR: WMF 5.0 installation failed (code %_ec%^).
echo Make sure Windows 7 SP1 is installed and try again.
pause
exit /b 1
 
 
:_setup_reboot
if not exist "%selfPath%" copy /y "!batchPath!" "%selfPath%" >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "AnyDeskSetup" /t REG_SZ /d "cmd /c \"%selfPath%\"" /f >nul 2>&1

echo  Component installed. Restart required.
echo  After restart, AnyDesk setup continues automatically.

timeout /t 15 >nul
shutdown /r /t 0
exit
 
 
:vbs_download
set "_vu=%~1"
set "_vo=%~2"
set "_vt=%TEMP%\_dl.vbs"
>  "%_vt%" echo Const T = 120000
>> "%_vt%" echo Set x = CreateObject("MSXML2.XMLHTTP")
>> "%_vt%" echo x.Open "GET", WScript.Arguments(0), False
>> "%_vt%" echo x.setTimeouts T, T, T, T
>> "%_vt%" echo x.Send
>> "%_vt%" echo If x.Status = 200 Then
>> "%_vt%" echo   Set s = CreateObject("ADODB.Stream")
>> "%_vt%" echo   s.Type = 1 : s.Open : s.Write x.ResponseBody
>> "%_vt%" echo   s.SaveToFile WScript.Arguments(1), 2 : s.Close
>> "%_vt%" echo End If
cscript //nologo "%_vt%" "!_vu!" "!_vo!" >nul 2>&1
del /f /q "%_vt%" >nul 2>&1
exit /b 0