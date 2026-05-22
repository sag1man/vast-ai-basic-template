#!/usr/bin/env bash
set -euo pipefail

echo "=== Model Bootstrap ==="

echo "=== GPU ==="
nvidia-smi || true

mkdir -p /workspace/models /workspace/hf-cache /workspace/private

export HF_HOME="${HF_HOME:-/workspace/hf-cache}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-/workspace/hf-cache/hub}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-/workspace/hf-cache}"

MODEL_ID="${MODEL_ID:-}"
MODEL_PATH="${MODEL_PATH:-}"
MODEL_REVISION="${MODEL_REVISION:-}"

PRIVATE_REPO="${PRIVATE_REPO:-}"
PRIVATE_REF="${PRIVATE_REF:-main}"
PRIVATE_DIR="${PRIVATE_DIR:-/workspace/private/workload}"

START_CMD="${START_CMD:-}"
RESULTS_DIR="${RESULTS_DIR:-/workspace/results}"

mkdir -p "$RESULTS_DIR"

if [ -z "$MODEL_PATH" ] && [ -n "$MODEL_ID" ]; then
  MODEL_NAME="${MODEL_ID##*/}"
  MODEL_PATH="/workspace/models/$MODEL_NAME"
fi

export MODEL_PATH RESULTS_DIR

echo "MODEL_ID=$MODEL_ID"
echo "MODEL_PATH=$MODEL_PATH"
echo "MODEL_REVISION=$MODEL_REVISION"
echo "PRIVATE_REPO=$PRIVATE_REPO"
echo "PRIVATE_REF=$PRIVATE_REF"
echo "PRIVATE_DIR=$PRIVATE_DIR"
echo "RESULTS_DIR=$RESULTS_DIR"

if [ -n "${HF_TOKEN:-}" ]; then
  echo "=== HF login ==="
  hf auth login --token "$HF_TOKEN"
else
  echo "HF_TOKEN is not set; assuming public model or existing MODEL_PATH"
fi

if [ -n "$MODEL_ID" ]; then
  echo "=== Downloading model ==="
  mkdir -p "$MODEL_PATH"

  HF_DOWNLOAD_ARGS=("$MODEL_ID" "--local-dir" "$MODEL_PATH")

  if [ -n "$MODEL_REVISION" ]; then
    HF_DOWNLOAD_ARGS+=("--revision" "$MODEL_REVISION")
  fi

  hf download "${HF_DOWNLOAD_ARGS[@]}"
else
  echo "MODEL_ID is not set; skipping model download"
fi

if [ -n "$PRIVATE_REPO" ]; then
  PRIVATE_DIR="$(realpath -m "$PRIVATE_DIR")"

  case "$PRIVATE_DIR" in
    /workspace/private/*) ;;
    *)
      echo "ERROR: PRIVATE_DIR must be inside /workspace/private"
      exit 1
      ;;
  esac

  echo "=== Cloning workload repo ==="
  rm -rf "$PRIVATE_DIR"

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    BASIC_AUTH="$(printf "x-access-token:%s" "$GITHUB_TOKEN" | base64 -w0)"

    git \
      -c http.https://github.com/.extraheader="AUTHORIZATION: basic ${BASIC_AUTH}" \
      clone \
      --depth 1 \
      --branch "$PRIVATE_REF" \
      "https://github.com/${PRIVATE_REPO}.git" \
      "$PRIVATE_DIR"
  else
    git clone \
      --depth 1 \
      --branch "$PRIVATE_REF" \
      "https://github.com/${PRIVATE_REPO}.git" \
      "$PRIVATE_DIR"
  fi

  echo "=== Workload repo files ==="
  find "$PRIVATE_DIR" -maxdepth 3 -type f | sort

  cd "$PRIVATE_DIR"

  if [ -f "requirements.txt" ]; then
    echo "=== Installing workload requirements ==="
    pip install -r requirements.txt
  fi
else
  echo "PRIVATE_REPO is not set; skipping workload repo clone"
fi

if [ -z "$START_CMD" ]; then
  if [ -f "scripts/run.sh" ]; then
    START_CMD="bash scripts/run.sh"
  else
    echo "ERROR: START_CMD is not set and no default run script was found"
    exit 1
  fi
fi

echo "=== Running workload ==="
echo "START_CMD=$START_CMD"

exec bash -c "$START_CMD"
