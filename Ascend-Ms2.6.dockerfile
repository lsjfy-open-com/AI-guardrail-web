# ============================================================================
# 【v7.3｜最小可用集】CANN 8.1.RC1 构建（toolkit + kernels + nnrt）
# 基础镜像：quay.io/openeuler/openeuler:24.03-lts-sp2（公开，免登录）
# 架构：支持 TARGETARCH=arm64 / amd64
# 构建命令：
#   docker build --build-arg TARGETARCH=arm64 -t npu-dev:arm64 .
#   docker build --build-arg TARGETARCH=amd64 -t npu-dev:amd64 .
# ============================================================================
ARG TARGETARCH=arm64

# ✅ 使用 quay.io 公开镜像（无需 docker login）
FROM quay.io/openeuler/openeuler:24.03-lts-sp2

# ========== 架构映射（安全提取，防空格）==========
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

RUN set -e; \
    case "${TARGETARCH}" in \
        amd64)  export PKG_ARCH="x86_64"; export CANN_PKG_ARCH="x86_64"; ;; \
        arm64)  export PKG_ARCH="aarch64"; export CANN_PKG_ARCH="aarch64"; ;; \
        *) echo "❌ Unsupported TARGETARCH=${TARGETARCH}"; exit 1 ;; \
    esac; \
    echo "PKG_ARCH=${PKG_ARCH}" >> /etc/environment; \
    echo "CANN_PKG_ARCH=${CANN_PKG_ARCH}" >> /etc/environment

# ========== 切换华为云源（加速 dnf）==========
RUN sed -i 's|/mirrorlist|#mirrorlist|g' /etc/yum.repos.d/openEuler*.repo && \
    sed -i 's|#baseurl=http://repo.openeuler.org|baseurl=https://repo.huaweicloud.com/openeuler|g' /etc/yum.repos.d/openEuler*.repo && \
    dnf install -y dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf clean all && dnf makecache

# ========== 安装依赖 ==========
RUN dnf install -y \
        python3 python3-pip python3-devel \
        gcc gcc-c++ make cmake git wget tar \
        libstdc++ libgcc libgomp zlib-devel \
        openssl-devel libffi-devel pciutils \
        libusb-devel libudev-devel numactl \
    && dnf clean all

# ========== pip 源设为华为云 ==========
RUN python3 -m pip config set global.index-url https://repo.huaweicloud.com/repository/pypi/simple && \
    python3 -m pip config set global.trusted-host repo.huaweicloud.com && \
    python3 -m pip install --upgrade pip

# ========== 安装 CANN 8.1.RC1（toolkit + kernels + nnrt）==========
ARG CANN_VERSION=8.1.RC1
# 华为云 OBS 内网地址（ECS 内网加速，公网也可用）
ARG OBS_URL=https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/MindSpore/cann/8.1.RC1

RUN set -e; \
    # 安全读取架构（防空格/换行）
    PKG_ARCH=$(bash -c 'source /etc/environment && echo -n $PKG_ARCH'); \
    CANN_PKG_ARCH=$(bash -c 'source /etc/environment && echo -n $CANN_PKG_ARCH'); \
    echo "📦 Building for PKG_ARCH=${PKG_ARCH}, CANN_PKG_ARCH=${CANN_PKG_ARCH}"; \
    \
    cd /tmp; \
    \
    # 1. Install Toolkit
    echo "⬇️  Downloading toolkit..."; \
    wget -nv "${OBS_URL}/Ascend-cann-toolkit_${CANN_VERSION}_linux-${CANN_PKG_ARCH}.run" -O toolkit.run || { echo "❌ toolkit download failed"; exit 1; }; \
    chmod +x toolkit.run; \
    ./toolkit.run --quiet; \
    rm -f toolkit.run; \
    echo "✅ toolkit installed"; \
    \
    # 2. Install Kernels（关键！）
    echo "⬇️  Downloading kernels..."; \
    wget -nv "${OBS_URL}/Ascend-cann-kernels_${CANN_VERSION}_linux-${CANN_PKG_ARCH}.run" -O kernels.run || { echo "❌ kernels download failed"; exit 1; }; \
    chmod +x kernels.run; \
    ./kernels.run --quiet --install=/usr/local/Ascend; \
    rm -f kernels.run; \
    echo "✅ kernels installed"; \
    \
    # 3. Install NNRT
    echo "⬇️  Downloading nnrt..."; \
    wget -nv "${OBS_URL}/Ascend-cann-nnrt_${CANN_VERSION}_linux-${CANN_PKG_ARCH}.run" -O nnrt.run || { echo "❌ nnrt download failed"; exit 1; }; \
    chmod +x nnrt.run; \
    ./nnrt.run --quiet --install=/usr/local/Ascend; \
    rm -f nnrt.run; \
    echo "✅ nnrt installed"; \
    \
    # 4. 验证 kernels 注入 OPP
    OPP_PATH="/usr/local/Ascend/ascend-toolkit/latest/opp/op_impl/built-in"; \
    if [ -d "${OPP_PATH}/ai_core" ] && [ -d "${OPP_PATH}/tbe" ]; then \
        echo "✅ Kernels verified: ai_core & tbe present"; \
        ls "${OPP_PATH}/ai_core" | head -n 3; \
    else \
        echo "❌ Kernels NOT injected into OPP!"; \
        ls -l "${OPP_PATH}"; \
        exit 1; \
    fi

# ========== 安装 MindSpore Lite 2.6.0 ==========
ARG MS_LITE_VERSION=2.6.0
ARG MS_LITE_URL=https://ms-release.obs.cn-north-4.myhuaweicloud.com/${MS_LITE_VERSION}/MindSpore/lite/release/linux

RUN set -e; \
    PKG_ARCH=$(bash -c 'source /etc/environment && echo -n $PKG_ARCH'); \
    echo "⬇️  Downloading MindSpore Lite ${MS_LITE_VERSION} for ${PKG_ARCH}..."; \
    wget -nv "${MS_LITE_URL}/${PKG_ARCH}/mindspore-lite-${MS_LITE_VERSION}-linux-${PKG_ARCH}.tar.gz" -O ms_lite.tar.gz; \
    tar -xf ms_lite.tar.gz -C /usr/local; \
    rm -f ms_lite.tar.gz; \
    ln -s /usr/local/mindspore-lite-${MS_LITE_VERSION}-linux-${PKG_ARCH} /usr/local/mindspore-lite; \
    echo "✅ MindSpore Lite installed"

# ========== 环境变量 ==========
ENV ASCEND_HOME=/usr/local/Ascend \
    ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest \
    LITE_HOME=/usr/local/mindspore-lite \
    PATH=/usr/local/mindspore-lite/tools/converter/converter:/usr/local/mindspore-lite/tools/benchmark:/usr/local/Ascend/ascend-toolkit/latest/bin:/usr/local/Ascend/nnrt/latest/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/mindspore-lite/runtime/lib:/usr/local/mindspore-lite/tools/converter/lib:/usr/local/Ascend/ascend-toolkit/latest/lib64:/usr/local/Ascend/ascend-toolkit/latest/runtime/lib64:/usr/local/Ascend/nnrt/latest/lib64:$LD_LIBRARY_PATH

RUN echo 'export ASCEND_HOME=/usr/local/Ascend' >> /etc/profile && \
    echo 'export ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest' >> /etc/profile && \
    echo 'export LITE_HOME=/usr/local/mindspore-lite' >> /etc/profile && \
    echo 'export PATH=/usr/local/mindspore-lite/tools/converter/converter:/usr/local/mindspore-lite/tools/benchmark:/usr/local/Ascend/ascend-toolkit/latest/bin:/usr/local/Ascend/nnrt/latest/bin:$PATH' >> /etc/profile && \
    echo 'export LD_LIBRARY_PATH=/usr/local/mindspore-lite/runtime/lib:/usr/local/mindspore-lite/tools/converter/lib:/usr/local/Ascend/ascend-toolkit/latest/lib64:/usr/local/Ascend/ascend-toolkit/latest/runtime/lib64:/usr/local/Ascend/nnrt/latest/lib64:$LD_LIBRARY_PATH' >> /etc/profile

# ========== 清理 ==========
RUN dnf clean all && rm -rf /var/cache/dnf /tmp/*

WORKDIR /workspace
CMD ["bash"]