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

:run
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
            echo Success.
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
    rd /s /q "%LOCALAPPDATA%\AnyDesk" 2>nul

    call :detect_install
    if not defined _exe exit /b 0

    call :create_shortcut
    exit /b 0

:create_shortcut
    del /f /q "%USERPROFILE%\Desktop\AnyDesk*.lnk" 2>nul
    del /f /q "%PUBLIC%\Desktop\AnyDesk*.lnk"      2>nul

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$wc = New-Object System.Net.WebClient;" ^
    "$dp = [Environment]::GetFolderPath('Desktop');" ^
    "$lp = Join-Path $dp 'AnyDesk.lnk';" ^
    "if (-not (Test-Path $lp)) { $wc.DownloadFile('%lnkUrl%', $lp) }"

    timeout /t 2 >nul
    exit /b 0

:start_progress
    if not exist "%progPath%" curl -L -s --max-time 30 -o "%progPath%" "%progUrl%" 2>nul
    if not exist "%progPath%" certutil -urlcache -split -f "%progUrl%" "%progPath%" >nul 2>&1
    if exist "%progPath%" start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "%progPath%" -Mode %~1
    exit /b 0

:download
    if exist "%porPath0%" exit /b 0

    curl -L -s --max-time 120 -o "%porPath0%" "%url%" 2>nul
    if exist "%porPath0%" exit /b 0

    certutil -urlcache -f "%url%" nul >nul 2>&1
    certutil -urlcache -split -f "%url%" "%porPath0%" >nul 2>&1
    if exist "%porPath0%" exit /b 0

    set "dlVbs=%TEMP%\dl.vbs"
    >  "%dlVbs%" echo Const T = 120000
    >> "%dlVbs%" echo Set x = CreateObject("MSXML2.XMLHTTP")
    >> "%dlVbs%" echo x.Open "GET", WScript.Arguments(0), False
    >> "%dlVbs%" echo x.setTimeouts T, T, T, T
    >> "%dlVbs%" echo x.Send
    >> "%dlVbs%" echo If x.Status = 200 Then
    >> "%dlVbs%" echo   Set s = CreateObject("ADODB.Stream")
    >> "%dlVbs%" echo   s.Type = 1 : s.Open : s.Write x.ResponseBody
    >> "%dlVbs%" echo   s.SaveToFile WScript.Arguments(1), 2 : s.Close
    >> "%dlVbs%" echo End If
    cscript //nologo "%dlVbs%" "%url%" "%porPath0%"
    del /f /q "%dlVbs%" >nul 2>&1
    if exist "%porPath0%" exit /b 0

    echo Download error. File "AnyDesk.exe" can't download.
    pause >nul
    exit /b 1
