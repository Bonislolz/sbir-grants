@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM SBIR Skill 自動安裝程式 (OpenCode - Windows)
REM 將 SBIR MCP Server 設定到 OpenCode 的 opencode.json
REM 重要：不會覆蓋您現有的 OpenCode 設定（plugin、provider、其他 MCP 等）

cd /d "%~dp0"

echo ==========================================
echo    SBIR Skill 安裝程式 (OpenCode - Windows)
echo ==========================================
echo.

REM ============================================
REM 步驟 0: 環境檢查
REM ============================================
if not exist "mcp-server\server.py" (
    echo [X] 錯誤：請在 sbir-grants 資料夾中執行此程式
    pause
    exit /b 1
)

echo [OK] 找到專案資料夾
echo.

REM ============================================
REM 步驟 1/4: 檢查 uv 或 Python
REM ============================================
echo 步驟 1/4: 檢查執行環境...

set "USE_UV=0"

uv --version >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%i in ('uv --version') do set "UV_VERSION=%%i"
    echo [OK] 找到 uv: !UV_VERSION!
    set "USE_UV=1"
    goto :step2
)

python --version >nul 2>&1
if errorlevel 1 (
    echo [X] 找不到 uv 或 Python
    echo.
    echo 請先安裝其中之一：
    echo   方法 1 ^(推薦^): powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    echo   方法 2: 前往 https://www.python.org/downloads/
    echo   安裝時勾選 Add Python to PATH
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do set "PYTHON_VERSION=%%i"
echo [*] 未找到 uv，改用 Python: !PYTHON_VERSION!
echo   建議安裝 uv: powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
echo.

:step2
echo.

REM ============================================
REM 步驟 2/4: 安裝依賴
REM ============================================
echo 步驟 2/4: 安裝依賴套件...
echo 首次安裝可能需要 5-10 分鐘，請耐心等候...
echo.

if "!USE_UV!"=="1" (
    echo [OK] 使用 uv 管理依賴 - 自動隔離，不影響您的系統環境
    echo   依賴會在首次啟動時由 uv run 自動安裝到專案內的 .venv 目錄
    echo   跳過預安裝步驟 - uv run 會自動處理
) else (
    if not exist "venv" (
        echo 正在建立虛擬環境...
        python -m venv venv
        if errorlevel 1 (
            echo [X] 虛擬環境建立失敗
            pause
            exit /b 1
        )
    )

    "venv\Scripts\python.exe" -m pip install --upgrade pip --quiet
    "venv\Scripts\python.exe" -m pip install -r "mcp-server\requirements.txt" --quiet
    if errorlevel 1 (
        echo [X] 套件安裝失敗
        echo.
        echo 常見原因：
        echo   1. 網路連線問題
        echo   2. 磁碟空間不足
        echo   3. Python 版本太舊 - 需要 3.10+
        pause
        exit /b 1
    )
    echo [OK] 依賴安裝成功 ^(venv^)
)
echo.

REM ============================================
REM 步驟 3/4: 設定 OpenCode
REM ============================================
echo 步驟 3/4: 設定 OpenCode...

set "PROJECT_PATH=%~dp0"
if "!PROJECT_PATH:~-1!"=="\" set "PROJECT_PATH=!PROJECT_PATH:~0,-1!"

set "OPENCODE_CONFIG_DIR=!USERPROFILE!\.config\opencode"
set "OPENCODE_CONFIG_FILE=!OPENCODE_CONFIG_DIR!\opencode.json"

if not exist "!OPENCODE_CONFIG_DIR!" mkdir "!OPENCODE_CONFIG_DIR!"

if exist "!OPENCODE_CONFIG_FILE!" (
    copy /y "!OPENCODE_CONFIG_FILE!" "!OPENCODE_CONFIG_FILE!.bak" >nul
    echo [i] 已備份現有設定至 opencode.json.bak
)

set "SERVER_DIR=!PROJECT_PATH!\mcp-server"
set "SERVER_DIR_JSON=!SERVER_DIR:\=/!"

if "!USE_UV!"=="1" (
    REM uv 模式：command = ["uv", "--directory", "<server_dir>", "run", "server.py"]
    python "!PROJECT_PATH!\mcp-server\update_opencode_config.py" "!OPENCODE_CONFIG_FILE!" "!SERVER_DIR_JSON!" 2>nul
    if errorlevel 1 (
        REM 如果系統沒有 python，嘗試用 uv run
        uv run --no-project python "!PROJECT_PATH!\mcp-server\update_opencode_config.py" "!OPENCODE_CONFIG_FILE!" "!SERVER_DIR_JSON!"
    )
) else (
    REM venv 模式：command = ["<python_exe>", "<server_script>"]
    set "PYTHON_PATH=!PROJECT_PATH!\venv\Scripts\python.exe"
    set "SERVER_PATH=!PROJECT_PATH!\mcp-server\server.py"
    set "PYTHON_JSON=!PYTHON_PATH:\=/!"
    set "SERVER_JSON=!SERVER_PATH:\=/!"
    "venv\Scripts\python.exe" "mcp-server\update_opencode_config.py" "!OPENCODE_CONFIG_FILE!" "!PYTHON_JSON!" "!SERVER_JSON!"
)

if !errorlevel! neq 0 (
    echo [X] 設定檔更新失敗
    if exist "!OPENCODE_CONFIG_FILE!.bak" (
        copy /y "!OPENCODE_CONFIG_FILE!.bak" "!OPENCODE_CONFIG_FILE!" >nul
        echo   已從備份還原設定檔
    )
    pause
    exit /b 1
)

echo [OK] OpenCode 設定已安全更新
echo   [i] 設定檔位置: !OPENCODE_CONFIG_FILE!
echo   [i] 已保留其他設定 - plugin、provider、其他 MCP 等
echo.

REM ============================================
REM 步驟 4/4: 驗證安裝
REM ============================================
echo 步驟 4/4: 驗證安裝...

if "!USE_UV!"=="1" (
    uv run --directory "%~dp0mcp-server" python -c "import mcp; import pydantic; import httpx; import yaml; import docx; print('CORE_OK')" >nul 2>&1
) else (
    "venv\Scripts\python.exe" -c "import mcp; import pydantic; import httpx; import yaml; import docx; print('CORE_OK')" >nul 2>&1
)

if errorlevel 1 (
    echo [*] 部分核心模組驗證失敗，Server 可能無法正常啟動
) else (
    echo [OK] 核心模組驗證通過
)

findstr /C:"sbir-data" "!OPENCODE_CONFIG_FILE!" >nul 2>&1
if errorlevel 1 (
    echo [*] OpenCode 設定檔可能未正確更新
) else (
    echo [OK] OpenCode 設定檔包含 sbir-data MCP
)
echo.

REM ============================================
REM 完成
REM ============================================
echo ==========================================
echo   安裝成功！
echo ==========================================
echo.
echo 下一步：
echo 1. 重新啟動 OpenCode
echo   - 完全關閉 OpenCode
echo   - 重新開啟 OpenCode
echo.
echo 2. 驗證 MCP Server 是否掛載成功：
echo   [i] 在 OpenCode 中嘗試使用 SBIR 相關工具
echo.
echo 3. 查看使用指南：
echo   - FIRST_TIME_USE.md
echo   - HOW_TO_USE.md
echo.
echo 注意事項：
echo   [i] 已保留您原有的 OpenCode 設定
echo   [i] 備份檔案：opencode.json.bak
echo.
echo ==========================================

endlocal
pause
