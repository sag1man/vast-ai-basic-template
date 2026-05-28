FROM vllm/vllm-openai:v0.21.0

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    TOKENIZERS_PARALLELISM=false \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    HF_XET_HIGH_PERFORMANCE=1 \
    HF_HOME=/workspace/hf-cache \
    HF_HUB_CACHE=/workspace/hf-cache/hub \
    TRANSFORMERS_CACHE=/workspace/hf-cache \
    XDG_CACHE_HOME=/workspace/.cache \
    PYTORCH_ALLOC_CONF=expandable_segments:True \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
    LOG_DIR=/workspace/logs \
    HF_MODEL="" \
    HF_MODEL_DIR="" \
    GH_REPO="" \
    GH_REF=main \
    GH_DIR=/workspace/github-repo \
    GH_EXEC="" \
    GH_EXEC_ARGS=""

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

RUN python3 -m pip install -r /app/requirements.txt

COPY scripts/bootstrap.sh /app/scripts/bootstrap.sh
RUN chmod +x /app/scripts/bootstrap.sh

ENTRYPOINT []
CMD ["bash"]
