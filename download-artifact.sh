#!/bin/bash
set -euo pipefail

OWNER="kamjin3086"
REPO="llamacpp-rocm"
ARTIFACT_ID="${1:-}"
DEST_DIR="/opt/local"
SOURCE="${2:-github}"

mkdir -p "$DEST_DIR"

if [[ "$SOURCE" == "r2" ]]; then
    R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-}"
    R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-}"
    R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-}"
    R2_BUCKET="${R2_BUCKET:-}"

    echo "=== Download from Cloudflare R2 ==="
    echo ""

    if [[ -z "$R2_ACCOUNT_ID" ]] || [[ -z "$R2_ACCESS_KEY_ID" ]] || \
       [[ -z "$R2_SECRET_ACCESS_KEY" ]] || [[ -z "$R2_BUCKET" ]]; then
        echo "R2 credentials not found in environment."
        echo "Please set: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET"
        exit 1
    fi

    echo "Bucket: ${R2_BUCKET}"
    echo "Account: ${R2_ACCOUNT_ID}"
    echo ""

    ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

    if [[ -z "$ARTIFACT_ID" ]]; then
        echo "Available files in bucket:"
        aws s3 ls "s3://${R2_BUCKET}/" \
            --endpoint-url "$ENDPOINT" 2>/dev/null || true
        echo ""
        echo "Specify a filename to download, e.g.:"
        echo "  $0 llama-ubuntu-rocm-gfx1151-x64-7.13.0a20260318-abc12.tar.gz"
        exit 0
    fi

    echo "Downloading from R2: ${ARTIFACT_ID}"
    echo ""

    AWS_PAGER="" aws s3 cp "s3://${R2_BUCKET}/${ARTIFACT_ID}" "${DEST_DIR}/" \
        --endpoint-url "$ENDPOINT"

    tar -xzf "${DEST_DIR}/${ARTIFACT_ID}" -C "$DEST_DIR"
    rm -f "${DEST_DIR}/${ARTIFACT_ID}"
    echo "Done! Files saved to: ${DEST_DIR}"
    exit 0
fi

if [[ -z "$ARTIFACT_ID" ]]; then
    echo "Available artifacts:"
    gh api "repos/${OWNER}/${REPO}/actions/runs" \
        --jq '.workflow_runs[0:5] | .[] | "\(.id) - \(.name) (\(.status))"' \
        --paginate 2>/dev/null || true

    echo ""
    echo "Recent artifacts across all runs:"
    gh api "repos/${OWNER}/${REPO}/actions/artifacts" \
        --jq '.artifacts[] | "\(.id) - \(.name) (created: \(.created_at | split("T")[0]))"' \
        --paginate 2>/dev/null || true
    echo ""
    echo "Run this script with an artifact ID to download."
    exit 0
fi

ARTIFACT_JSON=$(gh api "repos/${OWNER}/${REPO}/actions/artifacts/${ARTIFACT_ID}" --jq '{
    name: .name,
    content_type: .content_type,
    size: .size_in_bytes,
    url: .archive_download_url
}')

ARTIFACT_NAME=$(echo "$ARTIFACT_JSON" | jq -r '.name')
ARTIFACT_URL=$(echo "$ARTIFACT_JSON" | jq -r '.url')
ARTIFACT_SIZE=$(echo "$ARTIFACT_JSON" | jq -r '.size')
SIZE_MB=$((ARTIFACT_SIZE / 1024 / 1024))

echo "Artifact: ${ARTIFACT_NAME}"
echo "Size: ${SIZE_MB} MB"
echo "Downloading to ${DEST_DIR}..."

curl -L -o "/tmp/${ARTIFACT_NAME}" \
    -H "Authorization: Bearer $(gh auth token)" \
    "$ARTIFACT_URL"

if [[ "$ARTIFACT_NAME" == *.zip ]]; then
    unzip -o "/tmp/${ARTIFACT_NAME}" -d "$DEST_DIR"
else
    tar -xzf "/tmp/${ARTIFACT_NAME}" -C "$DEST_DIR"
fi

rm -f "/tmp/${ARTIFACT_NAME}"
echo "Done! Extracted to: ${DEST_DIR}/${ARTIFACT_NAME}"
