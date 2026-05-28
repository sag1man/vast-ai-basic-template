#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${LOG_DIR:-/workspace/logs}"
mkdir -p "${LOG_DIR}"

BOOT_LOG="${LOG_DIR}/bootstrap-$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee -a "${BOOT_LOG}") 2>&1

echo "== Vast AI bootstrap =="
date
echo "LOG_DIR=${LOG_DIR}"
echo "BOOT_LOG=${BOOT_LOG}"

mkdir -p "${HF_HOME:-/workspace/hf-cache}" \
    "${HF_HUB_CACHE:-/workspace/hf-cache/hub}" \
    "${TRANSFORMERS_CACHE:-/workspace/hf-cache}" \
    "${XDG_CACHE_HOME:-/workspace/.cache}" \
    /workspace/models

echo
echo "== GPU =="
nvidia-smi || true

echo
echo "== Python / Torch / CUDA =="
python3 - <<'PY'
import sys
import torch

print("python:", sys.executable)
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
print("cuda_available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
    print("vram_gb:", round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 2))
PY

echo
echo "== vLLM =="
python3 - <<'PY'
try:
    import vllm
    print("vllm:", vllm.__version__)
except Exception as e:
    print("vllm import failed:", repr(e))
PY

echo
echo "== Ports =="
ss -lntp || true

echo
echo "== Optional Hugging Face model =="

if [ -n "${HF_MODEL:-}" ]; then
    HF_MODEL_NAME="${HF_MODEL##*/}"
    HF_MODEL_NAME="${HF_MODEL_NAME%.git}"
    HF_MODEL_DIR="${HF_MODEL_DIR:-/workspace/models/${HF_MODEL_NAME}}"
    export HF_MODEL_DIR

    echo "HF_MODEL=${HF_MODEL}"
    echo "HF_MODEL_DIR=${HF_MODEL_DIR}"

    mkdir -p "${HF_MODEL_DIR}"
    hf download "${HF_MODEL}" --local-dir "${HF_MODEL_DIR}"
else
    echo "No HF_MODEL provided."
fi

echo
echo "== Optional GitHub repo =="

if [ -n "${GH_REPO:-}" ]; then
    echo "GH_REPO=${GH_REPO}"
    echo "GH_REF=${GH_REF:-main}"
    echo "GH_DIR=${GH_DIR:-/workspace/github-repo}"
    echo "GH_EXEC=${GH_EXEC:-}"
    echo "GH_EXEC_ARGS=${GH_EXEC_ARGS:-}"
    GH_LOG="${LOG_DIR}/github-repo-$(date -u +%Y%m%dT%H%M%SZ).log"
    echo "GH_LOG=${GH_LOG}"

    rm -rf "${GH_DIR:-/workspace/github-repo}"
    case "${GH_REPO}" in
        http://*|https://*|git@*)
            GH_CLONE_URL="${GH_REPO}"
            ;;
        *)
            GH_CLONE_URL="https://github.com/${GH_REPO}.git"
            ;;
    esac

    if [ -n "${GH_TOKEN:-}" ]; then
        GH_AUTH_HEADER="$(printf "x-access-token:%s" "${GH_TOKEN}" | base64 -w0)"
        git \
            -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${GH_AUTH_HEADER}" \
            clone \
            --depth 1 \
            --branch "${GH_REF:-main}" \
            "${GH_CLONE_URL}" \
            "${GH_DIR:-/workspace/github-repo}" \
            > >(tee -a "${GH_LOG}") \
            2> >(tee -a "${GH_LOG}" >&2)
    else
        git clone \
            --depth 1 \
            --branch "${GH_REF:-main}" \
            "${GH_CLONE_URL}" \
            "${GH_DIR:-/workspace/github-repo}" \
            > >(tee -a "${GH_LOG}") \
            2> >(tee -a "${GH_LOG}" >&2)
    fi

    if [ -n "${GH_EXEC:-}" ]; then
        GH_EXEC_LOG="${LOG_DIR}/github-exec-$(date -u +%Y%m%dT%H%M%SZ).log"
        GH_EXEC_ARGS_ARRAY=()

        case "${GH_EXEC}" in
            /*)
                GH_EXEC_PATH="${GH_EXEC}"
                ;;
            *)
                GH_EXEC_PATH="${GH_DIR:-/workspace/github-repo}/${GH_EXEC}"
                ;;
        esac

        echo "GH_EXEC_PATH=${GH_EXEC_PATH}"
        echo "GH_EXEC_LOG=${GH_EXEC_LOG}"

        if [ -n "${GH_EXEC_ARGS:-}" ]; then
            read -r -a GH_EXEC_ARGS_ARRAY <<< "${GH_EXEC_ARGS}"
            echo "GH_EXEC_ARGS_PARSED=${GH_EXEC_ARGS_ARRAY[*]}"
        fi

        if [ ! -f "${GH_EXEC_PATH}" ]; then
            echo "ERROR: GH_EXEC script not found: ${GH_EXEC_PATH}"
            exit 1
        fi

        chmod +x "${GH_EXEC_PATH}" || true
        (
            cd "${GH_DIR:-/workspace/github-repo}"
            "${GH_EXEC_PATH}" "${GH_EXEC_ARGS_ARRAY[@]}"
        ) > >(tee -a "${GH_EXEC_LOG}") 2> >(tee -a "${GH_EXEC_LOG}" >&2)
    else
        echo "No GH_EXEC provided."
    fi
else
    echo "No GH_REPO provided."
fi

echo
echo "== Keep container alive =="
tail -f /dev/null
