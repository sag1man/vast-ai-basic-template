FROM pytorch/pytorch:2.11.0-cuda12.8-cudnn9-devel

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    TOKENIZERS_PARALLELISM=false \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    HF_HOME=/workspace/hf-cache \
    HF_HUB_CACHE=/workspace/hf-cache/hub \
    TRANSFORMERS_CACHE=/workspace/hf-cache \
    XDG_CACHE_HOME=/workspace/.cache \
    PYTORCH_ALLOC_CONF=expandable_segments:True \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
    LIGHTLLM_DIR=/opt/lightllm \
    HOST=0.0.0.0 \
    PORT=8000 \
    API_PORT=8000 \
    LOG_DIR=/workspace/logs \
    HF_MODEL="" \
    GH_REPO="" \
    GH_REF=main \
    GH_DIR=/workspace/github-repo \
    GH_EXEC=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    curl \
    wget \
    ca-certificates \
    build-essential \
    ninja-build \
    cmake \
    pkg-config \
    iproute2 \
    procps \
    lsof \
    htop \
    tmux \
    && rm -rf /var/lib/apt/lists/*

ENV CC=gcc
ENV CXX=g++

COPY requirements.txt /app/requirements.txt

RUN python -m pip install -U pip setuptools wheel packaging ninja cmake && \
    python -m pip install -r /app/requirements.txt \
      --extra-index-url https://download.pytorch.org/whl/cu128

RUN git clone https://github.com/ModelTC/lightllm.git ${LIGHTLLM_DIR} && \
    cd ${LIGHTLLM_DIR} && \
    git submodule update --init --recursive || true && \
    python -m pip install -e . --no-build-isolation

COPY scripts/bootstrap.sh /app/scripts/bootstrap.sh
RUN chmod +x /app/scripts/bootstrap.sh

CMD ["/app/scripts/bootstrap.sh"]
