#!/bin/bash

# SBIR Skill 自動安裝腳本（OpenCode 版 - Mac）
# 將 SBIR MCP Server 設定到 OpenCode 的 opencode.json
# 重要：不會覆蓋您現有的 OpenCode 設定（plugin、provider、其他 MCP 等）

set -e

echo "=========================================="
echo "   SBIR Skill 安裝程式 (OpenCode - Mac)"
echo "=========================================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR" || exit 1

echo "📁 工作目錄: $SCRIPT_DIR"
echo ""

if [ ! -f "mcp-server/server.py" ]; then
    echo "❌ 錯誤：找不到 mcp-server/server.py"
    echo ""
    echo "請確認："
    echo "1. 您已經下載完整的專案"
    echo "2. 專案資料夾名稱是 sbir-grants"
    echo "3. 資料夾內有 mcp-server 子資料夾"
    echo ""
    echo "目前位置: $SCRIPT_DIR"
    exit 1
fi

echo "✅ 找到專案資料夾"
echo ""

# ============================================
# 步驟 1/4: 檢查 uv 或 Python
# ============================================
echo "步驟 1/4: 檢查執行環境..."

USE_UV=false

if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version 2>/dev/null || echo "unknown")
    echo "✅ 找到 uv: $UV_VERSION"
    USE_UV=true
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "⚠️  未找到 uv，改用 Python: $PYTHON_VERSION"
    echo "   建議安裝 uv 以獲得更好的體驗: curl -LsSf https://astral.sh/uv/install.sh | sh"
    USE_UV=false
else
    echo "❌ 找不到 uv 或 Python"
    echo ""
    echo "請先安裝其中之一："
    echo "  方法 1 (推薦): curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "  方法 2: brew install python3"
    echo "  方法 3: 前往 https://www.python.org/downloads/"
    exit 1
fi
echo ""

# ============================================
# 步驟 2/4: 安裝依賴
# ============================================
echo "步驟 2/4: 安裝依賴套件..."
echo "⏳ 首次安裝可能需要 3-5 分鐘（需下載 AI 模型），請耐心等候..."
echo ""

if [ "$USE_UV" = true ]; then
    echo "✅ 使用 uv 管理依賴（自動隔離，不影響您的系統環境）"
    echo "   依賴會在首次啟動時由 uv run 自動安裝到專案內的 .venv 目錄"
    echo "   位置: $SCRIPT_DIR/mcp-server/.venv/"
    echo "   ℹ️  跳過預安裝步驟（uv run 會自動處理）"
else
    if [ ! -d "venv" ]; then
        echo "正在建立虛擬環境..."
        if ! python3 -m venv venv; then
            echo "❌ 虛擬環境建立失敗"
            exit 1
        fi
    fi

    if ! "$SCRIPT_DIR/venv/bin/python" -m pip install --upgrade pip --quiet 2>/dev/null; then
        echo "⚠️  pip 升級失敗，繼續使用現有版本..."
    fi

    if ! "$SCRIPT_DIR/venv/bin/python" -m pip install -r "$SCRIPT_DIR/mcp-server/requirements.txt" --quiet; then
        echo "❌ 套件安裝失敗"
        echo ""
        echo "常見原因："
        echo "  1. 網路連線問題"
        echo "  2. 磁碟空間不足（需要約 1.5 GB）"
        echo "  3. Python 版本太舊（需要 3.10+）"
        exit 1
    fi
    echo "✅ 依賴安裝成功 (venv)"
fi
echo ""

# ============================================
# 步驟 3/4: 設定 OpenCode（安全合併）
# ============================================
echo "步驟 3/4: 設定 OpenCode..."

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
SERVER_DIR="$SCRIPT_DIR/mcp-server"

mkdir -p "$OPENCODE_CONFIG_DIR"

if [ -f "$OPENCODE_CONFIG_FILE" ]; then
    cp "$OPENCODE_CONFIG_FILE" "$OPENCODE_CONFIG_FILE.bak"
    echo "ℹ️  已備份現有設定至 opencode.json.bak"
fi

if [ "$USE_UV" = true ]; then
    # 用系統 python3（或 uv 自帶的 python）執行設定更新
    UPDATER="$SCRIPT_DIR/mcp-server/update_opencode_config.py"

    if command -v python3 &> /dev/null; then
        python3 "$UPDATER" "$OPENCODE_CONFIG_FILE" "$SERVER_DIR"
    else
        uv run --no-project python "$UPDATER" "$OPENCODE_CONFIG_FILE" "$SERVER_DIR"
    fi
else
    PYTHON_EXE="$SCRIPT_DIR/venv/bin/python"
    SERVER_SCRIPT="$SCRIPT_DIR/mcp-server/server.py"

    "$PYTHON_EXE" "$SCRIPT_DIR/mcp-server/update_opencode_config.py" \
        "$OPENCODE_CONFIG_FILE" "$PYTHON_EXE" "$SERVER_SCRIPT"
fi

if [ $? -eq 0 ]; then
    echo "✅ OpenCode 設定已安全更新"
    echo "   設定檔位置: $OPENCODE_CONFIG_FILE"
    echo "   已保留其他設定（plugin、provider、其他 MCP 等）"
else
    echo "❌ 設定檔更新失敗"
    if [ -f "$OPENCODE_CONFIG_FILE.bak" ]; then
        cp "$OPENCODE_CONFIG_FILE.bak" "$OPENCODE_CONFIG_FILE"
        echo "   已從備份還原設定檔"
    fi
    exit 1
fi
echo ""

# ============================================
# 步驟 4/4: 驗證安裝
# ============================================
echo "步驟 4/4: 驗證安裝..."

if [ "$USE_UV" = true ]; then
    VERIFY_RESULT=$(uv run --directory "$SCRIPT_DIR/mcp-server" python -c "
import sys
errors = []
for mod_name, pkg_name in [('mcp','mcp'), ('pydantic','pydantic'), ('httpx','httpx'), ('yaml','pyyaml'), ('docx','python-docx')]:
    try:
        __import__(mod_name)
    except ImportError:
        errors.append(pkg_name)
if errors:
    print('FAIL:' + ','.join(errors))
    sys.exit(1)
print('OK')
" 2>&1) || true
else
    VERIFY_RESULT=$("$SCRIPT_DIR/venv/bin/python" -c "
import sys
errors = []
for mod_name, pkg_name in [('mcp','mcp'), ('pydantic','pydantic'), ('httpx','httpx'), ('yaml','pyyaml'), ('docx','python-docx')]:
    try:
        __import__(mod_name)
    except ImportError:
        errors.append(pkg_name)
if errors:
    print('FAIL:' + ','.join(errors))
    sys.exit(1)
print('OK')
" 2>&1) || true
fi

if echo "$VERIFY_RESULT" | grep -q "OK"; then
    echo "✅ 核心模組驗證通過"
else
    echo "⚠️  部分模組驗證失敗: $VERIFY_RESULT"
    echo "   Server 仍可運作，但部分功能可能受限"
fi

# 驗證 opencode.json 是否包含 sbir-data
if grep -q "sbir-data" "$OPENCODE_CONFIG_FILE" 2>/dev/null; then
    echo "✅ OpenCode 設定檔包含 sbir-data MCP"
else
    echo "⚠️  OpenCode 設定檔可能未正確更新"
fi
echo ""

# ============================================
# 完成
# ============================================
echo "=========================================="
echo "   🎉 安裝成功！"
echo "=========================================="
echo ""
echo "下一步："
echo "1. 重新啟動 OpenCode"
echo "   - 完全關閉 OpenCode"
echo "   - 重新開啟 OpenCode"
echo ""
echo "2. 驗證 MCP Server 是否掛載成功："
echo "   在 OpenCode 中嘗試使用 SBIR 相關工具"
echo ""
echo "3. 查看使用指南："
echo "   - FIRST_TIME_USE.md（第一次使用）"
echo "   - HOW_TO_USE.md（完整使用說明）"
echo ""
echo "注意事項："
echo "   - 已保留您原有的 OpenCode 設定（plugin、provider 等）"
echo "   - 備份檔案：opencode.json.bak"
if [ "$USE_UV" = true ]; then
echo "   - 使用 uv 管理依賴（推薦方式）"
else
echo "   - 使用虛擬環境隔離依賴套件"
fi
echo ""
echo "💡 如果從 Finder 雙擊本檔案會用文字編輯器開啟，"
echo "   請改用終端機執行："
echo "   bash \"$SCRIPT_DIR/install-opencode-mac.sh\""
echo ""
echo "=========================================="
