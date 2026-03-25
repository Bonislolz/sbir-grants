# SBIR Skill 自動安裝程式 (OpenCode - Windows)
# 將 SBIR MCP Server 設定到 OpenCode 的 opencode.json
# 重要：不會覆蓋您現有的 OpenCode 設定（plugin、provider、其他 MCP 等）

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "=========================================="
Write-Host "   SBIR Skill 安裝程式 (OpenCode - Windows)"
Write-Host "=========================================="
Write-Host ""

# 切換到腳本所在目錄
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# ============================================
# 步驟 0: 環境檢查
# ============================================
if (-not (Test-Path "mcp-server\server.py")) {
    Write-Host "[X] 錯誤：請在 sbir-grants 資料夾中執行此程式" -ForegroundColor Red
    Read-Host "按 Enter 結束"
    exit 1
}

Write-Host "[OK] 找到專案資料夾" -ForegroundColor Green
Write-Host ""

# ============================================
# 步驟 1/4: 檢查 uv 或 Python
# ============================================
Write-Host "步驟 1/4: 檢查執行環境..."

$UseUV = $false

try {
    $uvVersion = & uv --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $uvVersion) {
        Write-Host "[OK] 找到 uv: $uvVersion" -ForegroundColor Green
        $UseUV = $true
    } else {
        throw "uv not found"
    }
} catch {
    try {
        $pyVersion = & python --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $pyVersion) {
            Write-Host "[!] 未找到 uv，改用 Python: $pyVersion" -ForegroundColor Yellow
            Write-Host "    建議安裝 uv: powershell -ExecutionPolicy ByPass -c `"irm https://astral.sh/uv/install.ps1 | iex`""
        } else {
            throw "python not found"
        }
    } catch {
        Write-Host "[X] 找不到 uv 或 Python" -ForegroundColor Red
        Write-Host ""
        Write-Host "請先安裝其中之一："
        Write-Host "  方法 1 (推薦): powershell -ExecutionPolicy ByPass -c `"irm https://astral.sh/uv/install.ps1 | iex`""
        Write-Host "  方法 2: 前往 https://www.python.org/downloads/"
        Write-Host "          安裝時勾選 Add Python to PATH"
        Read-Host "按 Enter 結束"
        exit 1
    }
}
Write-Host ""

# ============================================
# 步驟 2/4: 安裝依賴
# ============================================
Write-Host "步驟 2/4: 安裝依賴套件..."
Write-Host "首次安裝可能需要 5-10 分鐘，請耐心等候..."
Write-Host ""

if ($UseUV) {
    Write-Host "[OK] 使用 uv 管理依賴（自動隔離，不影響您的系統環境）" -ForegroundColor Green
    Write-Host "    依賴會在首次啟動時由 uv run 自動安裝到專案內的 .venv 目錄"
    Write-Host "    跳過預安裝步驟（uv run 會自動處理）"
} else {
    if (-not (Test-Path "venv")) {
        Write-Host "正在建立虛擬環境..."
        & python -m venv venv
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] 虛擬環境建立失敗" -ForegroundColor Red
            Read-Host "按 Enter 結束"
            exit 1
        }
    }

    & "venv\Scripts\python.exe" -m pip install --upgrade pip --quiet 2>$null
    & "venv\Scripts\python.exe" -m pip install -r "mcp-server\requirements.txt" --quiet

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] 套件安裝失敗" -ForegroundColor Red
        Write-Host ""
        Write-Host "常見原因："
        Write-Host "  1. 網路連線問題"
        Write-Host "  2. 磁碟空間不足"
        Write-Host "  3. Python 版本太舊（需要 3.10+）"
        Read-Host "按 Enter 結束"
        exit 1
    }
    Write-Host "[OK] 依賴安裝成功 (venv)" -ForegroundColor Green
}
Write-Host ""

# ============================================
# 步驟 3/4: 設定 OpenCode（安全合併）
# ============================================
Write-Host "步驟 3/4: 設定 OpenCode..."

$ProjectPath = $ScriptDir.TrimEnd('\')
$OpenCodeConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
$OpenCodeConfigFile = Join-Path $OpenCodeConfigDir "opencode.json"

if (-not (Test-Path $OpenCodeConfigDir)) {
    New-Item -ItemType Directory -Path $OpenCodeConfigDir -Force | Out-Null
}

if (Test-Path $OpenCodeConfigFile) {
    Copy-Item $OpenCodeConfigFile "$OpenCodeConfigFile.bak" -Force
    Write-Host "[i] 已備份現有設定至 opencode.json.bak"
}

$ServerDir = Join-Path $ProjectPath "mcp-server"
# update_opencode_config.py 使用正斜線路徑
$ServerDirJson = $ServerDir -replace '\\', '/'

$Updater = Join-Path $ProjectPath "mcp-server\update_opencode_config.py"

if ($UseUV) {
    # uv 模式：command = ["uv", "--directory", "<server_dir>", "run", "server.py"]
    $updateOk = $false

    # 先嘗試系統 python
    try {
        & python $Updater $OpenCodeConfigFile $ServerDirJson 2>$null
        if ($LASTEXITCODE -eq 0) { $updateOk = $true }
    } catch {}

    # 若系統沒有 python，用 uv run
    if (-not $updateOk) {
        & uv run --no-project python $Updater $OpenCodeConfigFile $ServerDirJson
        if ($LASTEXITCODE -eq 0) { $updateOk = $true }
    }

    if (-not $updateOk) {
        Write-Host "[X] 設定檔更新失敗" -ForegroundColor Red
        if (Test-Path "$OpenCodeConfigFile.bak") {
            Copy-Item "$OpenCodeConfigFile.bak" $OpenCodeConfigFile -Force
            Write-Host "    已從備份還原設定檔"
        }
        Read-Host "按 Enter 結束"
        exit 1
    }
} else {
    # venv 模式：command = ["<python_exe>", "<server_script>"]
    $PythonExe = Join-Path $ProjectPath "venv\Scripts\python.exe"
    $ServerScript = Join-Path $ProjectPath "mcp-server\server.py"
    $PythonJson = $PythonExe -replace '\\', '/'
    $ServerJson = $ServerScript -replace '\\', '/'

    & "venv\Scripts\python.exe" "mcp-server\update_opencode_config.py" $OpenCodeConfigFile $PythonJson $ServerJson

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] 設定檔更新失敗" -ForegroundColor Red
        if (Test-Path "$OpenCodeConfigFile.bak") {
            Copy-Item "$OpenCodeConfigFile.bak" $OpenCodeConfigFile -Force
            Write-Host "    已從備份還原設定檔"
        }
        Read-Host "按 Enter 結束"
        exit 1
    }
}

Write-Host "[OK] OpenCode 設定已安全更新" -ForegroundColor Green
Write-Host "    設定檔位置: $OpenCodeConfigFile"
Write-Host "    已保留其他設定（plugin、provider、其他 MCP 等）"
Write-Host ""

# ============================================
# 步驟 4/4: 驗證安裝
# ============================================
Write-Host "步驟 4/4: 驗證安裝..."

$verifyCmd = 'import mcp; import pydantic; import httpx; import yaml; import docx; print("CORE_OK")'

if ($UseUV) {
    $verifyResult = & uv run --directory (Join-Path $ScriptDir "mcp-server") python -c $verifyCmd 2>$null
} else {
    $verifyResult = & "venv\Scripts\python.exe" -c $verifyCmd 2>$null
}

if ($verifyResult -match "CORE_OK") {
    Write-Host "[OK] 核心模組驗證通過" -ForegroundColor Green
} else {
    Write-Host "[!] 部分核心模組驗證失敗，Server 可能無法正常啟動" -ForegroundColor Yellow
}

$configContent = Get-Content $OpenCodeConfigFile -Raw -ErrorAction SilentlyContinue
if ($configContent -match "sbir-data") {
    Write-Host "[OK] OpenCode 設定檔包含 sbir-data MCP" -ForegroundColor Green
} else {
    Write-Host "[!] OpenCode 設定檔可能未正確更新" -ForegroundColor Yellow
}
Write-Host ""

# ============================================
# 完成
# ============================================
Write-Host "=========================================="
Write-Host "   安裝成功！"
Write-Host "=========================================="
Write-Host ""
Write-Host "下一步："
Write-Host "1. 重新啟動 OpenCode"
Write-Host "   - 完全關閉 OpenCode"
Write-Host "   - 重新開啟 OpenCode"
Write-Host ""
Write-Host "2. 驗證 MCP Server 是否掛載成功："
Write-Host "   在 OpenCode 中嘗試使用 SBIR 相關工具"
Write-Host ""
Write-Host "3. 查看使用指南："
Write-Host "   - FIRST_TIME_USE.md"
Write-Host "   - HOW_TO_USE.md"
Write-Host ""
Write-Host "注意事項："
Write-Host "   - 已保留您原有的 OpenCode 設定"
Write-Host "   - 備份檔案：opencode.json.bak"
Write-Host ""
Write-Host "=========================================="
Write-Host ""
Read-Host "按 Enter 結束"
