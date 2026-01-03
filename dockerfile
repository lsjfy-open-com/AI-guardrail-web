# Dockerfile based on OpenEuler 24.03
FROM openeuler/openeuler:24.03

# 1. Install System Dependencies
# OpenEuler 24.03 likely uses dnf/yum
RUN yum update -y && \
    yum install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    openssl-devel \
    zlib-devel \
    bzip2-devel \
    libffi-devel \
    python3 \
    python3-pip \
    python3-devel \
    tar \
    wget \
    vim \
    git \
    && yum clean all

# 2. Python Setup
# Ensure pip is up to date
RUN pip3 install --upgrade pip

# 3. Install PyTorch and torch_npu
# Note: The versions below are examples. You must match them with your CANN version.
# Compatibility:
# CANN 8.0.RC1 -> PyTorch 2.1.0
# CANN 8.0.RC2 -> PyTorch 2.1.0, 2.2.0, 2.3.1
# CANN 8.0.0   -> PyTorch 2.4.0
#
# Example for x86_64 (CPU version of torch, then torch_npu)
# For aarch64, use: pip3 install torch==2.1.0
RUN if [ "$(uname -m)" = "x86_64" ]; then \
        pip3 install torch==2.1.0+cpu --index-url https://download.pytorch.org/whl/cpu; \
    else \
        pip3 install torch==2.1.0; \
    fi

# Install torch_npu
RUN pip3 install torch-npu==2.1.0.post13
RUN pip3 install pyyaml setuptools

# 4. Install MindSpore Lite
# Version 2.7.1
WORKDIR /opt

# Download MindSpore Lite (Adjust URL for aarch64 if needed)
# x86_64 URL: https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.1/MindSpore/lite/release/linux/x86_64/mindspore-lite-2.7.1-linux-x64.tar.gz
# aarch64 URL: https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.1/MindSpore/lite/release/linux/aarch64/mindspore-lite-2.7.1-linux-aarch64.tar.gz

RUN if [ "$(uname -m)" = "x86_64" ]; then \
        wget https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.1/MindSpore/lite/release/linux/x86_64/mindspore-lite-2.7.1-linux-x64.tar.gz -O ms_lite.tar.gz; \
    else \
        wget https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.1/MindSpore/lite/release/linux/aarch64/mindspore-lite-2.7.1-linux-aarch64.tar.gz -O ms_lite.tar.gz; \
    fi && \
    tar -zxvf ms_lite.tar.gz && \
    rm ms_lite.tar.gz

# Set Environment Variables for MindSpore Lite
# Note: The directory name might differ slightly based on arch, using wildcard to handle it
ENV LITE_HOME=/opt/mindspore-lite-2.7.1-linux-*
ENV LD_LIBRARY_PATH=${LITE_HOME}/runtime/lib:${LITE_HOME}/tools/converter/lib:${LD_LIBRARY_PATH}
ENV PATH=${LITE_HOME}/tools/benchmark:${LITE_HOME}/tools/converter/converter:${PATH}

# Install MindSpore Lite Python API
# Assuming Python 3.11 (Check your python version with `python3 --version`)
# Adjust cp311 to cp39 or cp310 if needed.
RUN if [ "$(uname -m)" = "x86_64" ]; then \
        wget https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.1/MindSpore/lite/release/linux/x86_64/mindspore_lite-2.7.1-cp311-cp311-linux_x86_64.whl -O ms_lite.whl; \
    else \
        wget https://ms-release.obs.cn-north-4.myhuaweicloud.com/2.7.1/MindSpore/lite/release/linux/aarch64/mindspore_lite-2.7.1-cp311-cp311-linux_aarch64.whl -O ms_lite.whl; \
    fi && \
    pip3 install ms_lite.whl && \
    rm ms_lite.whl

WORKDIR /root
CMD ["/bin/bash"]
