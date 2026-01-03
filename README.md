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
