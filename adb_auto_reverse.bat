@echo off
setlocal enabledelayedexpansion
title ADB Auto Reverse (8080)

set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set CONNECTED=0

echo [ADB] 기기 연결 감지 대기 중... (3초마다 확인)
echo [ADB] 이 창을 최소화해두세요.
echo.

:LOOP
    %ADB% devices 2>nul | findstr /r "device$" >nul 2>&1
    if !errorlevel!==0 (
        if !CONNECTED!==0 (
            %ADB% reverse tcp:8080 tcp:8080 >nul 2>&1
            echo [%time:~0,8%] 기기 연결 감지 - adb reverse tcp:8080 설정 완료
            set CONNECTED=1
        )
    ) else (
        if !CONNECTED!==1 (
            echo [%time:~0,8%] 기기 연결 해제
            set CONNECTED=0
        )
    )

    timeout /t 3 /nobreak >nul
    goto LOOP
