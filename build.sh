#!/bin/bash
# UHF Server Docker - Build and Push Script
# This script builds the Docker image and pushes it to GitHub Container Registry (ghcr.io)
#
# Usage:
#   ./build.sh                    # Build with defaults
#   ./build.sh --no-cache         # Force rebuild without cache
#   ./build.sh --push             # Build and push to registry
#   ./build.sh --no-cache --push  # Rebuild and push

set -e

# Configuration
IMAGE_REGISTRY="ghcr.io/rydizz214/uhf-server-docker"
IMAGE_TAG="1.5.1"
FULL_IMAGE="${IMAGE_REGISTRY}:${IMAGE_TAG}"

# Options
BUILD_ARGS=""
SHOULD_PUSH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            BUILD_ARGS="${BUILD_ARGS} --no-cache"
            shift
            ;;
        --push)
            SHOULD_PUSH=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--no-cache] [--push]"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "UHF Server Docker - Build Script"
echo "=========================================="
echo "Image: ${FULL_IMAGE}"
echo "Build Args: ${BUILD_ARGS}"
echo "Push to Registry: ${SHOULD_PUSH}"
echo "=========================================="
echo ""

# Build the image
echo "Building Docker image: ${FULL_IMAGE}"
docker build ${BUILD_ARGS} \
    --tag "${FULL_IMAGE}" \
    --tag "${IMAGE_REGISTRY}:latest" \
    -f Dockerfile .

echo ""
echo "✓ Docker image built successfully: ${FULL_IMAGE}"
echo ""

# Show image info
echo "Image Information:"
docker inspect "${FULL_IMAGE}" --format='
  Repository: {{index .RepoTags 0}}
  Size: {{.Size}} bytes
  Created: {{.Created}}
'

# Push to registry if requested
if [ "${SHOULD_PUSH}" = true ]; then
    echo ""
    echo "Pushing image to registry..."
    docker push "${FULL_IMAGE}"
    docker push "${IMAGE_REGISTRY}:latest"
    echo "✓ Image pushed successfully to ${IMAGE_REGISTRY}"
else
    echo ""
    echo "To push this image to the registry, run:"
    echo "  docker push ${FULL_IMAGE}"
    echo "  docker push ${IMAGE_REGISTRY}:latest"
    echo ""
    echo "Or run this script with --push flag:"
    echo "  ./build.sh --push"
fi

echo ""
echo "=========================================="
echo "Build Complete"
echo "=========================================="
