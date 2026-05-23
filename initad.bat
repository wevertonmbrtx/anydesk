@echo off
cls
title AnyDesk
mode con:cols=70 lines=27
chcp 437 >nul

echo.
echo.
echo                         @                 @@@
echo                       @@@@@             @@@@@@@
echo                     @@@@@@@@@         @@@@@@@@@@@
echo                   @@@@@@@@@@@@@         @@@@@@@@@@@
echo                 @@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo               @@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo             @@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo             @@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo               @@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo                 @@@@@@@@@@@@@@@@@         @@@@@@@@@@@
echo                   @@@@@@@@@@@@@         @@@@@@@@@@@
echo                     @@@@@@@@@         @@@@@@@@@@@
echo                       @@@@@             @@@@@@@
echo                         @                 @@@
timeout 2 >nul
cls

:init
    setlocal EnableExtensions DisableDelayedExpansion
    set "cmdInvoke=1"
    set "winSysFolder=System32"
    set "batchPath=%~f0"
    set "service=AnyDesk"
    set "insPath0=%ProgramFiles(x86)%\AnyDesk\AnyDesk.exe"
    set "insPath1=%ProgramFiles%\AnyDesk\AnyDesk.exe"
    set "porPath0=%TEMP%\AnyDesk.exe"
    set "progPath=%TEMP%\progress.ps1"
    set "url=https://download.anydesk.com/AnyDesk.exe"
    set "lnkUrl=https://raw.githubusercontent.com/wevertonmbrtx/anydesk/refs/heads/main/AnyDesk.lnk"
    set "progUrl=https://raw.githubusercontent.com/wevertonmbrtx/anydesk/refs/heads/main/progress.ps1"
    set "sysConf=%ALLUSERSPROFILE%\AnyDesk\system.conf"
    set "userConf=%APPDATA%\AnyDesk\user.conf"
    set "userConfBak=%TEMP%\anydesk_user.conf"
    for %%k in ("%~f0") do set "batchName=%%~nk"
    set "elevScript=%TEMP%\elev_%batchName%.vbs"
    setlocal EnableDelayedExpansion

:check_privileges
    %SystemRoot%\%winSysFolder%\whoami.exe /groups /nh | %SystemRoot%\%winSysFolder%\find.exe "S-1-16-12288" 1>nul
    if errorlevel 1 goto get_privileges

    %SystemRoot%\%winSysFolder%\net.exe session 1>nul 2>nul
    if not errorlevel 1 goto got_privileges

:get_privileges
    if "%~1"=="ELEV" (echo ELEV & shift /1 & goto got_privileges)
    echo Set UAC = CreateObject^("Shell.Application"^) > "%elevScript%"
    echo args = "ELEV " >> "%elevScript%"
    echo For Each strArg in WScript.Arguments >> "%elevScript%"
    echo args = args ^& strArg ^& " " >> "%elevScript%"
    echo Next >> "%elevScript%"

    if "%cmdInvoke%"=="1" (
        echo args = "/c """ + "!batchPath!" + """ " + args >> "%elevScript%"
        echo UAC.ShellExecute "%SystemRoot%\%winSysFolder%\cmd.exe", args, "", "runas", 0 >> "%elevScript%"
    ) else (
        echo UAC.ShellExecute "!batchPath!", args, "", "runas", 0 >> "%elevScript%"
    )

    "%SystemRoot%\%winSysFolder%\WScript.exe" "%elevScript%" %*
    exit /B

:got_privileges
    endlocal
    setlocal EnableExtensions EnableDelayedExpansion
    cd /d "%~dp0"
    if "%~1"=="ELEV" (del "%elevScript%" 1>nul 2>nul & shift /1)
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v SecureProtocols /t REG_DWORD /d 0x00000A80 /f >nul 2>&1

:run
    call :check_ps
    if errorlevel 1 goto :eof
    call :create_shortcut
    call :detect_install
    if defined _exe (
        call :start_progress installed
    ) else (
        call :start_progress portable
    )
    if not defined _exe (
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

    echo Success.
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
    rd /s /q "%LOCALAPPDATA%\AnyDesk"            2>nul

    cls
    echo Initializing AnyDesk...
    sc start "%service%" >nul 2>&1

    call :wait_new_id
    exit /b 0

:wait_service_registered
    set /a _c=0

:_wsg_loop
    sc query "%service%" >nul 2>&1
    if not errorlevel 1 exit /b 0
    timeout /t 1 >nul
    set /a _c+=1
    if !_c! lss 30 goto _wsg_loop
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
    call :download
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
    del /f /q "%TEMP%\gcapi.dll"      2>nul
    rd /s /q "%APPDATA%\AnyDesk"      2>nul

    call :detect_install
    if not defined _exe exit /b 0

    call :create_shortcut
    exit /b 0

:create_shortcut
    del /f /q "%USERPROFILE%\Desktop\AnyDesk*.lnk" 2>nul
    del /f /q "%PUBLIC%\Desktop\AnyDesk*.lnk"      2>nul

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([Net.SecurityProtocolType],3072);" ^
    "$wc = New-Object System.Net.WebClient;" ^
    "$dp = [Environment]::GetFolderPath('Desktop');" ^
    "$lp = Join-Path $dp 'AnyDesk.lnk';" ^
    "if (-not (Test-Path $lp)) { $wc.DownloadFile('%lnkUrl%', $lp) }"

    timeout /t 2 >nul
    exit /b 0

:start_progress
    if not exist "%progPath%" (
        where curl >nul 2>&1 && curl -L -s --max-time 30 -o "%progPath%" "%progUrl%"
    )
    if not exist "%progPath%" certutil -urlcache -split -f "%progUrl%" "%progPath%" >nul 2>&1
    if not exist "%progPath%" (
        set "_vdl_url=%progUrl%"
        set "_vdl_out=%progPath%"
        call :vbs_download
    )
    if exist "%progPath%" start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "%progPath%" -Mode %~1
    exit /b 0

:download
    if exist "%porPath0%" exit /b 0

    where curl >nul 2>&1 && curl -L -s --max-time 120 -o "%porPath0%" "%url%"
    if exist "%porPath0%" exit /b 0

    certutil -urlcache -f "%url%" nul >nul 2>&1
    certutil -urlcache -split -f "%url%" "%porPath0%" >nul 2>&1
    if exist "%porPath0%" exit /b 0

    set "_vdl_url=%url%"
    set "_vdl_out=%porPath0%"
    call :vbs_download
    if exist "%porPath0%" exit /b 0

    echo Download error. File "AnyDesk.exe" can't download.
    pause >nul
    exit /b 1

:check_ps
    if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
        echo PowerShell not found. Cannot continue.
        pause
        exit /b 1
    )
    powershell -NoProfile -Command "exit ([int]$PSVersionTable.PSVersion.Major)" 2>nul
    set "_psver=%errorlevel%"
    if %_psver% GEQ 3 exit /b 0
    echo.
    echo PowerShell %_psver%.x found. Version 3+ required.
    echo Preparing automatic setup of prerequisites...
    echo.
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
    if not exist "%_dnFile%" (
        bitsadmin /transfer "DotNet45" /download /priority normal "%_dnUrl%" "%_dnFile%" >nul 2>&1
        if not exist "%_dnFile%" certutil -urlcache -split -f "%_dnUrl%" "%_dnFile%" >nul 2>&1
        if not exist "%_dnFile%" (
            set "_vdl_url=%_dnUrl%"
            set "_vdl_out=%_dnFile%"
            call :vbs_download
        )
    )
    if not exist "%_dnFile%" (
        echo ERROR: Could not download .NET 4.5. Check internet connection.
        pause
        exit /b 1
    )
    echo Installing .NET Framework 4.5 (this may take several minutes^)...
    "%_dnFile%" /q /norestart
    set "_ec=%errorlevel%"
    del /f /q "%_dnFile%" >nul 2>&1
    if %_ec%==0    exit /b 0
    if %_ec%==3010 goto _dn45_reboot
    if %_ec%==1641 goto _dn45_reboot
    echo ERROR: .NET 4.5 setup failed (code %_ec%^).
    pause
    exit /b 1

:_dn45_reboot
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "AnyDeskSetup" /t REG_SZ /d "cmd /c \"%TEMP%\initad.bat\"" /f >nul 2>&1
    echo.
    echo  .NET 4.5 installed. Restart required.
    echo  After restart, AnyDesk setup continues automatically.
    echo.
    timeout /t 15 >nul
    shutdown /r /t 0
    exit

:install_wmf50
    set "_arch=x86"
    if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64"   set "_arch=x64"
    if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64"   set "_arch=x64"
    set "_wmfFile=%TEMP%\wmf50_%_arch%.msu"
    if "%_arch%"=="x64" (
        set "_wmfUrl=https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win7AndW2K8R2-KB3134760-x64.msu"
    ) else (
        set "_wmfUrl=https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/Win7-KB3134760-x86.msu"
    )
    if not exist "%_wmfFile%" (
        echo Downloading Windows Management Framework 5.0 (%_arch%^)...
        bitsadmin /transfer "WMF50" /download /priority normal "%_wmfUrl%" "%_wmfFile%" >nul 2>&1
        if not exist "%_wmfFile%" certutil -urlcache -split -f "%_wmfUrl%" "%_wmfFile%" >nul 2>&1
        if not exist "%_wmfFile%" (
            set "_vdl_url=%_wmfUrl%"
            set "_vdl_out=%_wmfFile%"
            call :vbs_download
        )
    )
    if not exist "%_wmfFile%" (
        echo ERROR: Could not download WMF 5.0. Check internet connection.
        pause
        exit /b 1
    )
    echo Installing Windows Management Framework 5.0...
    wusa "%_wmfFile%" /quiet /norestart
    set "_ec=%errorlevel%"
    del /f /q "%_wmfFile%" >nul 2>&1
    if %_ec%==2359302 ( echo WMF 5.0 already installed. & exit /b 0 )
    if %_ec%==0    goto _wmf50_reboot
    if %_ec%==3010 goto _wmf50_reboot
    echo ERROR: WMF 5.0 installation failed (code %_ec%^).
    echo Make sure Windows 7 SP1 is installed and try again.
    pause
    exit /b 1

:_wmf50_reboot
    powershell -NoProfile -Command "Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' 'AnyDeskSetup' 'powershell -NoProfile -ExecutionPolicy Bypass -Command {[Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([Net.SecurityProtocolType],3072); irm bit.ly/wgitad | iex}'" 2>nul
    echo.
    echo  WMF 5.0 installed. Restart required.
    echo  After restart, AnyDesk setup continues automatically.
    echo.
    timeout /t 15 >nul
    shutdown /r /t 0
    exit

:vbs_download
    set "_vdl_tmp=%TEMP%\_dl.vbs"
    >  "%_vdl_tmp%" echo Const T = 120000
    >> "%_vdl_tmp%" echo Set x = CreateObject("MSXML2.XMLHTTP")
    >> "%_vdl_tmp%" echo x.Open "GET", WScript.Arguments(0), False
    >> "%_vdl_tmp%" echo x.setTimeouts T, T, T, T
    >> "%_vdl_tmp%" echo x.Send
    >> "%_vdl_tmp%" echo If x.Status = 200 Then
    >> "%_vdl_tmp%" echo   Set s = CreateObject("ADODB.Stream")
    >> "%_vdl_tmp%" echo   s.Type = 1 : s.Open : s.Write x.ResponseBody
    >> "%_vdl_tmp%" echo   s.SaveToFile WScript.Arguments(1), 2 : s.Close
    >> "%_vdl_tmp%" echo End If
    cscript //nologo "%_vdl_tmp%" "%_vdl_url%" "%_vdl_out%" >nul 2>&1
    del /f /q "%_vdl_tmp%" >nul 2>&1
    exit /b 0
