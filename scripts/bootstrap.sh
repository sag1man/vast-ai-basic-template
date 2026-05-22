#!/usr/bin/env bash
set -euo pipefail

echo "=== Translate Bench Bootstrap ==="

echo "=== GPU ==="
nvidia-smi || true

mkdir -p /workspace/models /workspace/hf-cache /workspace/results /workspace/private

export HF_HOME="${HF_HOME:-/workspace/hf-cache}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-/workspace/hf-cache/hub}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-/workspace/hf-cache}"

MODEL_ID="${MODEL_ID:-google/translategemma-12b-it}"
MODEL_PATH="${MODEL_PATH:-/workspace/models/translategemma-12b-it}"

PRIVATE_REPO="${PRIVATE_REPO:-}"
PRIVATE_REF="${PRIVATE_REF:-main}"
PRIVATE_DIR="${PRIVATE_DIR:-/workspace/private/bench}"

echo "MODEL_ID=$MODEL_ID"
echo "MODEL_PATH=$MODEL_PATH"
echo "PRIVATE_REPO=$PRIVATE_REPO"
echo "PRIVATE_REF=$PRIVATE_REF"
echo "PRIVATE_DIR=$PRIVATE_DIR"

if [ -z "${HF_TOKEN:-}" ]; then
  echo "ERROR: HF_TOKEN is not set"
  exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: GITHUB_TOKEN is not set"
  exit 1
fi

if [ -z "$PRIVATE_REPO" ]; then
  echo "ERROR: PRIVATE_REPO is not set"
  exit 1
fi

echo "=== HF login ==="
hf auth login --token "$HF_TOKEN"

if [ ! -f "$MODEL_PATH/config.json" ]; then
  echo "=== Downloading model ==="
  hf download "$MODEL_ID" --local-dir "$MODEL_PATH"
else
  echo "=== Model already exists, skipping download ==="
fi

echo "=== Cloning private benchmark repo ==="
rm -rf "$PRIVATE_DIR"

BASIC_AUTH="$(printf "x-access-token:%s" "$GITHUB_TOKEN" | base64 -w0)"

git \
  -c http.https://github.com/.extraheader="AUTHORIZATION: basic ${BASIC_AUTH}" \
  clone \
  --depth 1 \
  --branch "$PRIVATE_REF" \
  "https://github.com/${PRIVATE_REPO}.git" \
  "$PRIVATE_DIR"

echo "=== Private repo files ==="
find "$PRIVATE_DIR" -maxdepth 3 -type f | sort

echo "=== Running private benchmark ==="
cd "$PRIVATE_DIR"

if [ -f "requirements.txt" ]; then
  echo "=== Installing private requirements ==="
  pip install -r requirements.txt
fi

bash scripts/run_benchmark.sh
