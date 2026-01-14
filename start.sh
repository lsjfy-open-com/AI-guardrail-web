#!/bin/bash
set -e

# 初始化脚本日志
echo "[INFO] Starting AI-Guardrail Container Entrypoint..."

# ================= 配置部分 =================
# 1. 设置服务端口
# 优先读取环境变量 SERVICE_PORT，如果在 docker run 中未指定，则默认为 5000
export SERVICE_PORT=${SERVICE_PORT:-5000}

# 2. 设置 Python 启动文件路径
# 优先读取环境变量 APP_ENTRYPOINT，默认路径为 /workspace/app.py
# 你可以根据实际情况修改下面的默认值，或者在启动容器时指定 -e APP_ENTRYPOINT=/path/to/your_script.py
APP_PATH=${APP_ENTRYPOINT:-"/workspace/app.py"}
# ===========================================

echo "[INFO] Service Configuration:"
echo "       - Port: $SERVICE_PORT"
echo "       - App File: $APP_PATH"

# 3. 检查文件并启动
if [ -f "$APP_PATH" ]; then
    echo "[INFO] Application file found. Starting Python Flask service..."
    
    # 启动服务
    # 注意：你的 Python 代码 (app.py) 应当能读取环境变量 SERVICE_PORT
    # 或者你可以修改下行命令显式传参，例如: exec python3 "$APP_PATH" --port "$SERVICE_PORT"
    exec python3 "$APP_PATH"
else
    echo "[WARNING] Application file '$APP_PATH' not found."
    echo "[INFO] Falling back to command passed to docker run..."
    
    # 如果找不到 Python 文件，执行 Docker 传入的命令 (如 bash)
    exec "$@"
fi
