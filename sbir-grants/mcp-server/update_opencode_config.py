"""
SBIR Skill - OpenCode 設定檔更新工具
用於安全地合併 MCP Server 設定到 OpenCode 的 opencode.json，不會覆蓋現有設定
"""

import json
import os
import sys


def update_opencode_config(config_file: str, server_dir: str) -> bool:
    """
    更新 OpenCode 設定檔，添加 sbir-data MCP Server

    OpenCode MCP 格式:
    {
      "mcp": {
        "sbir-data": {
          "type": "local",
          "command": ["uv", "--directory", "<server_dir>", "run", "server.py"]
        }
      }
    }

    Args:
        config_file: opencode.json 設定檔路徑
        server_dir: mcp-server 目錄的絕對路徑

    Returns:
        True if successful, False otherwise
    """
    try:
        # 讀取現有設定
        config = {}
        if os.path.exists(config_file):
            try:
                with open(config_file, "r", encoding="utf-8") as f:
                    content = f.read().strip()
                    if content:
                        config = json.loads(content)
            except (json.JSONDecodeError, IOError) as e:
                print(f"Warning: Could not read existing config: {e}")
                config = {}

        # 確保 mcp 區塊存在（OpenCode 用 "mcp" 而非 "mcpServers"）
        if "mcp" not in config or config["mcp"] is None:
            config["mcp"] = {}

        # 添加或更新 sbir-data（不影響其他 MCP Server）
        config["mcp"]["sbir-data"] = {
            "type": "local",
            "command": ["uv", "--directory", server_dir, "run", "server.py"],
        }

        # 寫入設定檔
        with open(config_file, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        return True

    except Exception as e:
        print(f"Error: {e}")
        return False


def update_opencode_config_venv(
    config_file: str, python_exe: str, server_script: str
) -> bool:
    """
    更新 OpenCode 設定檔（使用 venv Python 方式）

    適用於沒有安裝 uv 的環境，改用 venv 內的 python 直接執行 server.py

    OpenCode MCP 格式:
    {
      "mcp": {
        "sbir-data": {
          "type": "local",
          "command": ["<python_exe>", "<server_script>"]
        }
      }
    }

    Args:
        config_file: opencode.json 設定檔路徑
        python_exe: venv 內的 Python 執行檔路徑
        server_script: server.py 的絕對路徑

    Returns:
        True if successful, False otherwise
    """
    try:
        # 讀取現有設定
        config = {}
        if os.path.exists(config_file):
            try:
                with open(config_file, "r", encoding="utf-8") as f:
                    content = f.read().strip()
                    if content:
                        config = json.loads(content)
            except (json.JSONDecodeError, IOError) as e:
                print(f"Warning: Could not read existing config: {e}")
                config = {}

        # 確保 mcp 區塊存在
        if "mcp" not in config or config["mcp"] is None:
            config["mcp"] = {}

        # 添加或更新 sbir-data（不影響其他 MCP Server）
        config["mcp"]["sbir-data"] = {
            "type": "local",
            "command": [python_exe, server_script],
        }

        # 寫入設定檔
        with open(config_file, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        return True

    except Exception as e:
        print(f"Error: {e}")
        return False


if __name__ == "__main__":
    if len(sys.argv) == 3:
        # uv 模式: update_opencode_config.py <config_file> <server_dir>
        config_file = sys.argv[1]
        server_dir = sys.argv[2]
        if update_opencode_config(config_file, server_dir):
            print("OpenCode config updated successfully (uv mode)")
            sys.exit(0)
        else:
            sys.exit(1)
    elif len(sys.argv) == 4:
        # venv 模式: update_opencode_config.py <config_file> <python_exe> <server_script>
        config_file = sys.argv[1]
        python_exe = sys.argv[2]
        server_script = sys.argv[3]
        if update_opencode_config_venv(config_file, python_exe, server_script):
            print("OpenCode config updated successfully (venv mode)")
            sys.exit(0)
        else:
            sys.exit(1)
    else:
        print("Usage:")
        print(
            "  uv mode:   python update_opencode_config.py <config_file> <server_dir>"
        )
        print(
            "  venv mode: python update_opencode_config.py <config_file> <python_exe> <server_script>"
        )
        sys.exit(1)
