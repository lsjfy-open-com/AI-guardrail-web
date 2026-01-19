# ============================================================================
# 基于已构建好的 ai-guardrail:v1 镜像，添加启动脚本入口
# 并进行用户/权限加固，适配 K8s 非特权容器运行
# ============================================================================
FROM ai-guardrail:v1

# 切换回 root 进行配置
USER root

# ========== 1. 用户与权限配置 ==========
# 创建 modellite 用户 (UID 200)，加入 modelengine (GID 2000) 和 HwHiAiUser (GID 10003)
# HwHiAiUser 组对应宿主机 NPU 驱动权限
RUN (groupadd -g 2000 modelengine || true) && \
    (groupadd -g 10003 HwHiAiUser || true) && \
    (id -u modellite &>/dev/null || useradd -u 200 -g modelengine -G HwHiAiUser -m -s /bin/bash modellite)

# ========== 2. 环境变量 (显式声明) ==========
# 确保非交互式 Shell 也能正确读取变量
# 增加 HOME 变量，确保工具能找到用户目录缓存
ENV ASCEND_HOME=/usr/local/Ascend \
    LITE_HOME=/usr/local/mindspore-lite \
    HOME=/home/modellite \
    PATH=/usr/local/mindspore-lite/tools/converter/converter:/usr/local/mindspore-lite/tools/benchmark:/usr/local/Ascend/ascend-toolkit/latest/bin:/usr/local/Ascend/nnrt/latest/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/mindspore-lite/runtime/lib:/usr/local/mindspore-lite/tools/converter/lib:/usr/local/Ascend/ascend-toolkit/latest/lib64:/usr/local/Ascend/ascend-toolkit/latest/runtime/lib64:/usr/local/Ascend/nnrt/latest/lib64:$LD_LIBRARY_PATH \
    PS1="[\u@Ai-guardrail \W]$ "

# ========== 3. 部署脚本与权限修复 ==========
COPY start.sh /usr/local/bin/start.sh

RUN chmod +x /usr/local/bin/start.sh && \
    chown modellite:modelengine /usr/local/bin/start.sh && \
    # 修复工作目录权限
    mkdir -p /workspace && chown -R modellite:modelengine /workspace && \
    # 修复用户主目录权限 (确保 Python 缓存/HF 缓存/配置 可写)
    mkdir -p /home/modellite && chown -R modellite:modelengine /home/modellite && \
    # 修复 Ascend 和 Lite 目录权限，允许 modellite 访问
    # /usr/local/Ascend 需要 go+rx (Read+Execute) 以便加载 .so 库
    chmod -R go+rx /usr/local/Ascend && \
    # 如果 MindSpore Lite 存在，移交所有权
    ([ -d "/usr/local/mindspore-lite" ] && chown -R modellite:modelengine /usr/local/mindspore-lite || true) && \
    # 预创建 CANN 日志目录，防止因无权限创建导致报错
    mkdir -p /home/modellite/ascend/log && chown -R modellite:modelengine /home/modellite/ascend

# 设置工作目录
WORKDIR /workspace

# 切换到非 root 用户启动
USER modellite

# 设置 ENTRYPOINT
ENTRYPOINT ["/usr/local/bin/start.sh"]



# 默认命令 (如果 docker run 没有指定命令，则执行 bash)
CMD ["bash"]
