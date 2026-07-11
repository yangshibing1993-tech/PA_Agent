#Requires -Version 5.1
<#
.SYNOPSIS
  将 PA_Agent 部署到本地 D 盘 D:\PA_Agent 目录。

.DESCRIPTION
  自动完成：克隆/更新仓库、安装依赖、生成「运行智能体.bat」、基础验收。
  适用环境：Windows 10/11 + Python 3.11+ +（可选）MT5 已安装。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\deploy-to-d-drive.ps1
#>

$ErrorActionPreference = "Stop"

$PROJECT_ROOT = "D:\PA_Agent"
$REPO_URL = "https://github.com/yangshibing1993-tech/PA_Agent.git"
$PIP_INDEX = "https://pypi.tuna.tsinghua.edu.cn/simple"
$PIP_TRUSTED = "pypi.tuna.tsinghua.edu.cn"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-PythonReady {
    Write-Step "检查 Python 环境"
    $versionOutput = python --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "未找到 Python。请先安装 Python 3.11+ 并勾选 Add Python to PATH。"
    }
    Write-Host $versionOutput
    if ($versionOutput -notmatch "Python 3\.(1[1-9]|[2-9]\d)") {
        throw "需要 Python 3.11 或更高版本，当前：$versionOutput"
    }
}

function Ensure-ProjectDir {
    Write-Step "准备项目目录：$PROJECT_ROOT"
    if (-not (Test-Path "D:\")) {
        throw "未找到 D 盘。请确认 D 盘存在后再运行本脚本。"
    }
    if (-not (Test-Path $PROJECT_ROOT)) {
        New-Item -ItemType Directory -Path $PROJECT_ROOT -Force | Out-Null
        Write-Host "已创建目录：$PROJECT_ROOT"
    }
}

function Sync-Repository {
    Write-Step "同步代码仓库"
    $gitDir = Join-Path $PROJECT_ROOT ".git"
    if (Test-Path $gitDir) {
        Set-Location $PROJECT_ROOT
        git pull origin main
        if ($LASTEXITCODE -ne 0) {
            throw "git pull 失败，请检查网络或手动处理冲突。"
        }
        Write-Host "已更新到最新代码。"
    }
    else {
        if ((Get-ChildItem -Path $PROJECT_ROOT -Force | Measure-Object).Count -gt 0) {
            throw "$PROJECT_ROOT 已存在但不是 git 仓库。请清空该目录或更换路径。"
        }
        git clone $REPO_URL $PROJECT_ROOT
        if ($LASTEXITCODE -ne 0) {
            throw "git clone 失败，请检查网络连接。"
        }
        Set-Location $PROJECT_ROOT
        Write-Host "已克隆仓库到 $PROJECT_ROOT"
    }
}

function Upgrade-Pip {
    Write-Step "升级 pip"
    python -m pip install --upgrade pip -i $PIP_INDEX --trusted-host $PIP_TRUSTED
}

function Install-Dependencies {
    Write-Step "安装项目依赖（开发模式）"
    Set-Location $PROJECT_ROOT
    pip install -e . -i $PIP_INDEX --trusted-host $PIP_TRUSTED
}

function Test-CoreImports {
    Write-Step "验收：核心依赖导入"
    $checks = @(
        "import PyQt6; print('PyQt6 OK')",
        "import pyqtgraph; print('pyqtgraph OK')",
        "import numpy; print('numpy OK')",
        "import pandas; print('pandas OK')",
        "import openai; print('openai OK')",
        "import tiktoken; print('tiktoken OK')",
        "import jsonschema; print('jsonschema OK')",
        "import pydantic; print('pydantic OK')",
        "import MetaTrader5; print('MetaTrader5 OK')",
        "import cryptography; print('cryptography OK')",
        "import win32crypt; print('pywin32 OK')",
        "from tvDatafeed import TvDatafeed; print('tvDatafeed OK')",
        "import akshare; print('akshare OK')",
        "import baostock; print('baostock OK')",
        "import curl_cffi; print('curl_cffi OK')"
    )
    foreach ($cmd in $checks) {
        python -c $cmd
        if ($LASTEXITCODE -ne 0) {
            throw "依赖导入失败：$cmd"
        }
    }
}

function Test-ProjectStructure {
    Write-Step "验收：项目目录结构"
    $required = @(
        "pa_agent\main.py",
        "pa_agent\gui\main_window.py",
        "prompt_engineering",
        "run.py",
        "pyproject.toml"
    )
    foreach ($rel in $required) {
        $full = Join-Path $PROJECT_ROOT $rel
        if (-not (Test-Path $full)) {
            throw "缺少必要文件/目录：$rel"
        }
        Write-Host "OK  $rel"
    }
}

function New-LauncherBat {
    Write-Step "生成「运行智能体.bat」"
    $batPath = Join-Path $PROJECT_ROOT "运行智能体.bat"
    $batContent = @"
@echo off
chcp 936 >nul 2>&1
title PA Agent - AI K线分析助手
cd /d "%~dp0"
python run.py
if errorlevel 1 (
    echo.
    echo [错误] 程序异常退出，请查看上方错误信息。
    pause
)
"@
    [System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.Encoding]::GetEncoding("gbk"))
    Write-Host "已生成：$batPath"
}

function Test-MainImport {
    Write-Step "验收：主模块导入"
    Set-Location $PROJECT_ROOT
    python -c "from pa_agent.main import main; print('Import OK')"
    if ($LASTEXITCODE -ne 0) {
        throw "pa_agent.main 导入失败。"
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  PA_Agent 已部署到 D:\PA_Agent" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "启动方式（任选其一）："
    Write-Host "  1. 双击：D:\PA_Agent\运行智能体.bat"
    Write-Host "  2. 命令行："
    Write-Host "       cd D:\PA_Agent"
    Write-Host "       python run.py"
    Write-Host ""
    Write-Host "首次使用请在 GUI「设置」中填写 API Key。"
    Write-Host "若使用 MT5 数据源，请保持 MT5 终端已打开并登录。"
    Write-Host ""
}

try {
    if ([System.Environment]::OSVersion.Platform -ne "Win32NT") {
        throw "当前不是 Windows 系统。请在 Windows 上运行本脚本。"
    }

    Test-PythonReady
    Ensure-ProjectDir
    Sync-Repository
    Upgrade-Pip
    Install-Dependencies
    Test-CoreImports
    Test-ProjectStructure
    New-LauncherBat
    Test-MainImport
    Show-Summary
}
catch {
    Write-Host ""
    Write-Host "[部署失败] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "详细排错请参考项目根目录「把这个扔给龙虾-智能体部署方法.txt」" -ForegroundColor Yellow
    exit 1
}
