 
 #!/bin/bash
set -e

# 初始化脚本日志
echo "[INFO] Starting AI-Guardrail Container Entrypoint..."
echo "[INFO] Running as user: $(whoami) (UID: $(id -u), GIDs: $(id -G))"

# ================= 1. 加载 Ascend NPU 环境变量 =================
# 确保所有 CANN/Lite 环境变量已加载 (兼容 Dockerfile 中 ENV 和 /etc/profile)
if [ -f /etc/profile.d/ascend_env.sh ]; then
    source /etc/profile.d/ascend_env.sh
    echo "[INFO] Ascend environment variables loaded from /etc/profile.d/ascend_env.sh"
fi

# 验证关键环境变量
echo "[INFO] Verifying NPU environment:"
echo "       - ASCEND_HOME: ${ASCEND_HOME:-not set}"
echo "       - LITE_HOME: ${LITE_HOME:-not set}"
echo "       - LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:0:100}..."

# ================= 2. 配置部分 =================
# 1. 设置服务端口
# 优先读取环境变量 SERVICE_PORT，如果在 docker run 中未指定，则默认为 5000
export SERVICE_PORT=${SERVICE_PORT:-5000}

# 2. 设置 Python 启动文件路径
# 优先读取环境变量 APP_ENTRYPOINT，默认路径为 /workspace/app.py
APP_PATH=${APP_ENTRYPOINT:-"/workspace/app.py"}
# ===========================================

echo "[INFO] Service Configuration:"
echo "       - Port: $SERVICE_PORT"
echo "       - App File: $APP_PATH"

# ================= 3. 检查文件并启动 =================
if [ -f "$APP_PATH" ]; then
    echo "[INFO] Application file found. Starting Python Flask service..."

    # 启动服务
    # 注意：你的 Python 代码 (app.py) 应当能读取环境变量 SERVICE_PORT
    exec python3 "$APP_PATH"
else
    echo "[WARNING] Application file '$APP_PATH' not found."
    echo "[INFO] Falling back to command passed to docker run..."

    # 如果找不到 Python 文件，执行 Docker 传入的命令 (如 bash)
    exec "$@"
fi
D:\docker_image_construct\Ascend-MsLite2.6-Entrypoint.dockerfile