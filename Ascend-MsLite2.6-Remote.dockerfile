# ============================================================================
# 基于 AscendHub 官方远程镜像构建 MindSpore Lite 2.6.0 环境
# 基础镜像：swr.cn-south-1.myhuaweicloud.com/ascendhub/mindie:2.0.RC1-800I-A2-py311-openeuler24.03-lts
# 说明：该基础镜像已包含 CANN (Toolkit/NNRT) 及 Python 3.11
# ============================================================================

# 使用远程镜像 (构建时若本地不存在会自动 pull)
FROM swr.cn-south-1.myhuaweicloud.com/ascendhub/mindie:2.0.RC1-800I-A2-py311-openeuler24.03-lts

ARG TARGETARCH=amd64

# ========== 1. 配置华为云源并安装系统依赖 ==========
RUN sed -i 's|/mirrorlist|#mirrorlist|g' /etc/yum.repos.d/openEuler*.repo && \
    sed -i 's|#baseurl=http://repo.openeuler.org|baseurl=https://repo.huaweicloud.com/openeuler|g' /etc/yum.repos.d/openEuler*.repo && \
    dnf install -y dnf-plugins-core && \
    dnf install -y \
        gcc gcc-c++ make cmake git wget tar \
        libstdc++ libgcc libgomp zlib-devel \
        openssl-devel libffi-devel pciutils \
        libusb-devel libudev-devel numactl \
    && dnf clean all

# ========== 2. 配置 pip 源 ==========
RUN python3 -m pip config set global.index-url https://repo.huaweicloud.com/repository/pypi/simple && \
    python3 -m pip config set global.trusted-host repo.huaweicloud.com && \
    python3 -m pip install --upgrade pip

# ========== 3. 创建用户组和用户 (提前创建，后续操作在用户级进行) ==========
# 创建 modellite 用户 (UID 200)，加入 modelengine (GID 2000) 和 HwHiAiUser (GID 10003)
# HwHiAiUser 组对应宿主机 NPU 驱动权限，确保能访问 /dev/davinci*
RUN (groupadd -g 2000 modelengine || true) && \
    (groupadd -g 10003 HwHiAiUser || true) && \
    (id -u modellite &>/dev/null || useradd -u 200 -g modelengine -G HwHiAiUser -m -s /bin/bash modellite)

# ========== 4. 切换到 modellite 用户进行 Python 环境安装 ==========
USER modellite
WORKDIR /home/modellite

# ========== 5. 配置 pip 使用用户级安装 ==========
# 设置环境变量，确保 pip 安装到用户目录
ENV PIP_USER=true \
    PYTHONUSERBASE=/home/modellite/.local

# ========== 6. 安装 MindSpore Lite Python 包 ==========
# 只需安装 Python whl，无需 Tar 包工具
ARG MS_LITE_VERSION=2.6.0rc1
ARG MS_LITE_URL=https://ms-release.obs.cn-north-4.myhuaweicloud.com/${MS_LITE_VERSION}/MindSpore/lite/release/linux

RUN set -e; \
    if [ "$TARGETARCH" = "amd64" ]; then \
        pip install "${MS_LITE_URL}/x86_64/cloud_fusion/python311/mindspore_lite-${MS_LITE_VERSION}-cp311-cp311-linux_x86_64.whl"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        pip install "${MS_LITE_URL}/aarch64/cloud_fusion/python311/mindspore_lite-${MS_LITE_VERSION}-cp311-cp311-linux_aarch64.whl"; \
    fi

# ========== 7. 安装第三方 Python 库 (用户级安装) ==========
RUN pip install --no-cache-dir \
    gunicorn==23.0 \
    onnx==1.17 \
    gevent==24.2.1 \
    "flask[async]==3.1.2" \
    multiprocess==0.70.16 \
    pymysql==1.1.2 \
    transformers==4.51 \
    onnxruntime==1.22.1 \
    scikit-learn==1.7.1

# ========== 8. 环境变量配置 ==========
# MindSpore Lite Python 包安装到用户目录，需要正确配置 PYTHONPATH
# CANN 环境变量由基础镜像提供，这里只需确保 LD_LIBRARY_PATH 包含用户库路径
ENV HOME=/home/modellite \
    PYTHONPATH=/home/modellite/.local/lib/python3.11/site-packages:$PYTHONPATH \
    LD_LIBRARY_PATH=/home/modellite/.local/lib:$LD_LIBRARY_PATH

# ========== 9. 容器标识 ==========
LABEL app.name="Ai-guardrail"
ENV PS1="[\u@Ai-guardrail \W]$ "

# ========== 10. 工作目录和日志目录 ==========
RUN mkdir -p /workspace && \
    mkdir -p /home/modellite/ascend/log

# ========== 11. 入口脚本 ==========
COPY --chown=modellite:modelengine start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

WORKDIR /workspace

# ========== 12. 入口点和默认命令 ==========
ENTRYPOINT ["/usr/local/bin/start.sh"]
CMD ["bash"]
