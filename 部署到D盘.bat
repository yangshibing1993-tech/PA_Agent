@echo off
chcp 936 >nul 2>&1
title PA Agent - 部署到 D 盘
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\deploy-to-d-drive.ps1"
if errorlevel 1 (
    echo.
    echo [错误] 部署失败，请查看上方错误信息。
    pause
    exit /b 1
)
echo.
echo 部署完成，按任意键关闭窗口...
pause >nul
