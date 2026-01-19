# ============================================================================
# 基于 AscendHub 官方远程镜像构建 MindSpore Lite 2.6.0 环境
# 基础镜像：swr.cn-south-1.myhuaweicloud.com/ascendhub/mindie:2.0.RC1-800I-A2-py311-openeuler24.03-lts
# 说明：该基础镜像已包含 CANN (Toolkit/NNRT) 及 Python 3.11
# ============================================================================

# 使用远程镜像 (构建时若本地不存在会自动 pull)
FROM swr.cn-south-1.myhuaweicloud.com/ascendhub/mindie:2.0.RC1-800I-A2-py311-openeuler24.03-lts

ARG TARGETARCH=amd64

# ========== 1. 配置华为云源并安装系统依赖 ==========
# 基础镜像可能已经配置了源，但为了确保依赖齐全，再次检查安装
RUN sed -i 's|/mirrorlist|#mirrorlist|g' /etc/yum.repos.d/openEuler*.repo && \
    sed -i 's|#baseurl=http://repo.openeuler.org|baseurl=https://repo.huaweicloud.com/openeuler|g' /etc/yum.repos.d/openEuler*.repo && \
    dnf install -y dnf-plugins-core && \
    dnf install -y \
        gcc gcc-c++ make cmake git wget tar \
        libstdc++ libgcc libgomp zlib-devel \
        openssl-devel libffi-devel pciutils \
        libusb-devel libudev-devel numactl \
        mysql-server openssh-server \
    && dnf clean all

# ========== 2. 配置 pip 源 ==========
RUN python3 -m pip config set global.index-url https://repo.huaweicloud.com/repository/pypi/simple && \
    python3 -m pip config set global.trusted-host repo.huaweicloud.com && \
    python3 -m pip install --upgrade pip

# ========== 3. 安装 MindSpore Lite 2.6.0rc1 (Tar包 - 包含工具) ==========
# 用于提供 converter 和 benchmark 工具
ARG MS_LITE_VERSION=2.6.0rc1
ARG MS_LITE_URL=https://ms-release.obs.cn-north-4.myhuaweicloud.com/${MS_LITE_VERSION}/MindSpore/lite/release/linux

RUN set -e; \
    # 自动判断架构
    if [ "$TARGETARCH" = "amd64" ]; then \
        export PKG_ARCH="x86_64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        export PKG_ARCH="aarch64"; \
    else \
        echo "❌ Unsupported TARGETARCH=${TARGETARCH}"; exit 1; \
    fi; \
    \
    echo "⬇️  Downloading MindSpore Lite ${MS_LITE_VERSION} for ${PKG_ARCH}..."; \
    # 路径包含 cloud_fusion/python38
    wget -nv "${MS_LITE_URL}/${PKG_ARCH}/cloud_fusion/python38/mindspore-lite-${MS_LITE_VERSION}-linux-${PKG_ARCH}.tar.gz" -O /tmp/ms_lite.tar.gz; \
    tar -xf /tmp/ms_lite.tar.gz -C /usr/local; \
    rm -f /tmp/ms_lite.tar.gz; \
    ln -s /usr/local/mindspore-lite-${MS_LITE_VERSION}-linux-${PKG_ARCH} /usr/local/mindspore-lite; \
    echo "✅ MindSpore Lite tools installed"

# ========== 4. 安装 MindSpore Lite Python 包 (可选) ==========
# 如果需要在 Python 中使用 import mindspore_lite，请取消注释以下部分
# 注意：需根据 Python 版本 (py311) 选择对应的 whl 包
RUN set -e; \
    if [ "$TARGETARCH" = "amd64" ]; then \
        pip install "${MS_LITE_URL}/x86_64/cloud_fusion/python311/mindspore_lite-${MS_LITE_VERSION}-cp311-cp311-linux_x86_64.whl"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        pip install "${MS_LITE_URL}/aarch64/cloud_fusion/python311/mindspore_lite-${MS_LITE_VERSION}-cp311-cp311-linux_aarch64.whl"; \
    fi

# ========== 5. 安装第三方 Python 库 ==========
# 安装用户指定的特定版本库
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

# ========== 6. 配置 SSH 服务 (基础配置) ==========
RUN mkdir -p /var/run/sshd && \
    ssh-keygen -A

# ========== 7. 环境变量配置 ==========
# 基础镜像中通常已包含 ASCEND_HOME 等变量，这里追加 Lite 的变量
ENV LITE_HOME=/usr/local/mindspore-lite \
    PATH=/usr/local/mindspore-lite/tools/converter/converter:/usr/local/mindspore-lite/tools/benchmark:$PATH \
    LD_LIBRARY_PATH=/usr/local/mindspore-lite/runtime/lib:/usr/local/mindspore-lite/tools/converter/lib:$LD_LIBRARY_PATH

# 将环境变量写入配置文件，确保进入容器后生效
RUN echo 'export LITE_HOME=/usr/local/mindspore-lite' >> /etc/profile && \
    echo 'export PATH=/usr/local/mindspore-lite/tools/converter/converter:/usr/local/mindspore-lite/tools/benchmark:$PATH' >> /etc/profile && \
    echo 'export LD_LIBRARY_PATH=/usr/local/mindspore-lite/runtime/lib:/usr/local/mindspore-lite/tools/converter/lib:$LD_LIBRARY_PATH' >> /etc/profile

# ========== 8. 容器标识 ==========
LABEL app.name="Ai-guardrail"
# 设置终端提示符显示 Ai-guardrail
ENV PS1="[\u@Ai-guardrail \W]# "

# ========== 9. 用户与权限配置 (Ascend最佳实践) ==========
# 创建 modellite 用户 (UID 200)，将其加入 modelengine (GID 2000) 和 HwHiAiUser (GID 10003) 组
# 确保在 Host 上的 10003 组权限能被继承，用于访问 Driver/Firmware/NPU

# 注意：使用 || true 避免如果基础镜像中已存在该用户/组时构建失败
RUN (groupadd -g 2000 modelengine || true) && \
    (groupadd -g 10003 HwHiAiUser || true) && \
    (id -u modellite &>/dev/null || useradd -u 200 -g modelengine -G HwHiAiUser -m -s /bin/bash modellite)

# 修改关键目录权限，确保 modellite 用户可以访问和执行 installed 的软件
# 1. /usr/local/Ascend (CANN/MindIE)
# 2. /usr/local/mindspore-lite (Lite)
# 3. /workspace (工作目录)
RUN chown -R modellite:modelengine /workspace && \
    chown -R modellite:modelengine /usr/local/mindspore-lite && \
    # CANN/MindIE 目录通常通过组权限访问，或者直接赋予所有者权限
    # 为了保险起见，确保 HwHiAiUser 组或者 modelengine 组有权访问
    chmod -R go+rx /usr/local/Ascend

# 切换到非 root 用户
USER modellite
WORKDIR /workspace

# 更新环境变量 PS1 以显示新用户
ENV PS1="[\u@Ai-guardrail \W]$ "

CMD ["bash"]
