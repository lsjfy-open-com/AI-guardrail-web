<div align="center">

# AI Guardrail Docker Environment / 环境

[English](#english) | [中文](#chinese)

</div>

---

<a id="english"></a>

# AI Guardrail Docker Environment

This repository contains Docker build scripts for setting up the **AI Guardrail** environment on Huawei Ascend NPUs. It is built upon the Ascend MindIE base image and includes MindSpore Lite 2.6.0rc1 along with necessary Python dependencies.

## 📂 Dockerfiles

| File | Description |
|------|-------------|
| **`Ascend-MsLite2.6-Remote.dockerfile`** | **(Recommended)** Builds directly from the official remote AscendHub MindIE image (`swr.cn-south-1.myhuaweicloud.com/ascendhub/mindie:2.0.RC1...`). |
| `Ascend-MsLite2.6-NewBase.dockerfile` | Builds from a locally available base image. Use this if you have already pulled the base image. |
| `Ascend-Ms2.6.dockerfile` | Legacy version. Builds CANN environment from scratch on openEuler. |

## 🛠️ Build Instructions

To build the Docker image (using the recommended remote base):

```bash
# For ARM64 (Ascend 310P/910B etc.)
docker build --build-arg TARGETARCH=arm64 -t ai-guardrail:v1 -f Ascend-MsLite2.6-Remote.dockerfile .

# For AMD64 (x86_64)
docker build --build-arg TARGETARCH=amd64 -t ai-guardrail:v1 -f Ascend-MsLite2.6-Remote.dockerfile .
```

## 🚀 Run Instructions

To start the container with NPU access:

```bash
docker run -it \
  --name Ai-guardrail \
  --net=host \
  --device=/dev/davinci0 \
  --device=/dev/davinci_manager \
  --device=/dev/devmm_svm \
  --device=/dev/hisi_hdc \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  ai-guardrail:v1 bash
```

## 📦 Included Components

- **OS**: openEuler 24.03 LTS
- **Python**: 3.11
- **CANN**: Included in base image (Toolkit/NNRT)
- **MindSpore Lite**: 2.6.0rc1 (Tools + Python bindings)
- **System Packages**: `mysql-server`, `openssh-server`, `gcc`, `cmake`, etc.
- **Python Packages**:
  - `gunicorn==23.0`
  - `onnx==1.17`
  - `gevent==24.2.1`
  - `flask[async]==3.1.2`
  - `multiprocess==0.70.16`
  - `pymysql==1.1.2`
  - `transformers==4.51`
  - `onnxruntime==1.22.1`
  - `scikit-learn==1.7.1`

## 📝 Environment Variables

The image automatically configures:
- `LITE_HOME`: `/usr/local/mindspore-lite`
- `PATH`: Includes MindSpore Lite converters and benchmark tools.
- `LD_LIBRARY_PATH`: Includes MindSpore Lite runtime libraries.
- `PS1`: Terminal prompt set to `[user@Ai-guardrail dir]#`.

## 🐍 Entrypoint & Python Adaptation

If you are using the image with the `start.sh` entrypoint (e.g., built with `Ascend-MsLite2.6-Entrypoint.dockerfile`), you can control the startup behavior using environment variables.

**Docker Run Example:**

```bash
docker run -it \
  -e SERVICE_PORT=8080 \
  -e APP_ENTRYPOINT=/workspace/src/app.py \
  ai-guardrail:entrypoint
```

**Python Code Hint:**

Ensure your Python Flask application reads the `SERVICE_PORT` environment variable:

```python
import os
from flask import Flask

app = Flask(__name__)

# ... your code ...

if __name__ == '__main__':
    # Read port from environment variable, default to 5000
    port = int(os.environ.get('SERVICE_PORT', 5000))
    app.run(host='0.0.0.0', port=port)
```

---

<a id="chinese"></a>

# AI Guardrail Docker 环境

此仓库包含用于在华为 Ascend NPU 上设置 **AI Guardrail** 环境的 Docker 构建脚本。它基于 Ascend MindIE 基础镜像构建，并包含 MindSpore Lite 2.6.0rc1 以及必要的 Python 依赖项。

## 📂 Dockerfiles

| 文件 | 描述 |
|------|-------------|
| **`Ascend-MsLite2.6-Remote.dockerfile`** | **(推荐)** 直接从官方远程 AscendHub MindIE 镜像构建 (`swr.cn-south-1.myhuaweicloud.com/ascendhub/mindie:2.0.RC1...`)。 |
| `Ascend-MsLite2.6-NewBase.dockerfile` | 基于本地可用的基础镜像构建。如果你已经 pull 了基础镜像，请使用此文件。 |
| `Ascend-Ms2.6.dockerfile` | 旧版本。在 openEuler 上从零构建 CANN 环境。 |

## 🛠️ 构建指南

构建 Docker 镜像（使用推荐的远程基础镜像）：

```bash
# 适用于 ARM64 (Ascend 310P/910B 等)
docker build --build-arg TARGETARCH=arm64 -t ai-guardrail:v1 -f Ascend-MsLite2.6-Remote.dockerfile .

# 适用于 AMD64 (x86_64)
docker build --build-arg TARGETARCH=amd64 -t ai-guardrail:v1 -f Ascend-MsLite2.6-Remote.dockerfile .
```

## 🚀 运行指南

启动容器并启用 NPU 访问：

```bash
docker run -it \
  --name Ai-guardrail \
  --net=host \
  --device=/dev/davinci0 \
  --device=/dev/davinci_manager \
  --device=/dev/devmm_svm \
  --device=/dev/hisi_hdc \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/bin/npu-smi:/usr/local/bin/npu-smi \
  ai-guardrail:v1 bash
```

## 📦 包含组件

- **操作系统**: openEuler 24.03 LTS
- **Python**: 3.11
- **CANN**: 包含在基础镜像中 (Toolkit/NNRT)
- **MindSpore Lite**: 2.6.0rc1 (工具 + Python 绑定)
- **系统包**: `mysql-server`, `openssh-server`, `gcc`, `cmake` 等
- **Python 包**:
  - `gunicorn==23.0`
  - `onnx==1.17`
  - `gevent==24.2.1`
  - `flask[async]==3.1.2`
  - `multiprocess==0.70.16`
  - `pymysql==1.1.2`
  - `transformers==4.51`
  - `onnxruntime==1.22.1`
  - `scikit-learn==1.7.1`

## 📝 环境变量

镜像自动配置：
- `LITE_HOME`: `/usr/local/mindspore-lite`
- `PATH`: 包含 MindSpore Lite 转换器和基准测试工具。
- `LD_LIBRARY_PATH`: 包含 MindSpore Lite 运行时库。
- `PS1`: 终端提示符设置为 `[user@Ai-guardrail dir]#`。
## 🐍 入口点与 Python 适配

如果您使用的是包含 `start.sh` 入口点的镜像（例如使用 `Ascend-MsLite2.6-Entrypoint.dockerfile` 构建），可以通过环境变量控制启动行为。

**Docker 运行示例：**

```bash
docker run -it \
  -e SERVICE_PORT=8080 \
  -e APP_ENTRYPOINT=/workspace/src/app.py \
  ai-guardrail:entrypoint
```

**Python 代码适配提示：**

请确保您的 Python Flask 应用能够读取 `SERVICE_PORT` 环境变量：

```python
import os
from flask import Flask

app = Flask(__name__)

# ... 您的代码 ...

if __name__ == '__main__':
    # 从环境变量读取端口，默认为 5000
    port = int(os.environ.get('SERVICE_PORT', 5000))
    app.run(host='0.0.0.0', port=port)
```
## 已经上传制作好的镜像至SWR
- 地址：sudo docker pull swr.cn-north-4.myhuaweicloud.com/ai-guardrail/ai-guardrail:{版本名称}
- 已公开，若需登录，参照链接：https://support.huaweicloud.com/usermanual-swr/swr_01_0014.html
