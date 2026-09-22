#!/bin/bash
# ============================================
# Multi-Architecture Build Script
# Builds all mailserver container images
# ============================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REGISTRY="${REGISTRY:-ghcr.io/your-org}"
VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo 'latest')}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER_NAME="${BUILDER_NAME:-mailserver-builder}"
PUSH="${PUSH:-false}"
CACHE_FROM="${CACHE_FROM:-}"
CACHE_TO="${CACHE_TO:-}"
NO_CACHE=""

# Services to build
SERVICES=(
    "postfix"
    "dovecot"
    "rspamd"
    "opendkim"
    "clamav"
    "admin-api"
    "web-ui"
    "caldav-carddav"
)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH="true"
            shift
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --platform)
            PLATFORMS="$2"
            shift 2
            ;;
        --service)
            SERVICES=("$2")
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --push              Push images to registry"
            echo "  --registry REGISTRY Registry URL (default: ghcr.io/your-org)"
            echo "  --version VERSION   Image version tag (default: from VERSION file)"
            echo "  --platform PLATFORMS Target platforms (default: linux/amd64,linux/arm64)"
            echo "  --service SERVICE   Build specific service only"
            echo "  --no-cache         Build without cache"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=========================================="
echo "Mailserver Multi-Arch Build Script"
echo -e "==========================================${NC}"
echo -e "Registry: ${GREEN}${REGISTRY}${NC}"
echo -e "Version: ${GREEN}${VERSION}${NC}"
echo -e "Platforms: ${GREEN}${PLATFORMS}${NC}"
echo -e "Push: ${GREEN}${PUSH}${NC}"
echo -e "Services: ${GREEN}${SERVICES[*]}${NC}"
echo ""

# Check if builder exists
if ! docker buildx inspect "${BUILDER_NAME}" &> /dev/null; then
    echo -e "${YELLOW}⚠ Builder '${BUILDER_NAME}' not found${NC}"
    echo -e "${YELLOW}→ Running buildx setup...${NC}"
    if [ -f "./docker/buildx-setup.sh" ]; then
        bash ./docker/buildx-setup.sh
    else
        echo -e "${RED}✗ buildx-setup.sh not found${NC}"
        echo -e "${YELLOW}Please run: docker buildx create --name ${BUILDER_NAME} --use${NC}"
        exit 1
    fi
fi

# Use the builder
docker buildx use "${BUILDER_NAME}"
echo -e "${GREEN}✓ Using builder: ${BUILDER_NAME}${NC}"

# Build counter
TOTAL=${#SERVICES[@]}
CURRENT=0
FAILED=()
SUCCESS=()

# Function to build a single service
build_service() {
    local service=$1
    local service_dir="services/${service}"
    
    CURRENT=$((CURRENT + 1))
    
    echo ""
    echo -e "${BLUE}=========================================="
    echo -e "Building service ${CURRENT}/${TOTAL}: ${service}"
    echo -e "==========================================${NC}"
    
    # Check if service directory exists
    if [ ! -d "${service_dir}" ]; then
        echo -e "${RED}✗ Service directory not found: ${service_dir}${NC}"
        FAILED+=("${service}")
        return 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "${service_dir}/Dockerfile" ]; then
        echo -e "${YELLOW}⚠ Dockerfile not found for ${service}, skipping${NC}"
        return 0
    fi
    
    # Build command
    local build_cmd="docker buildx build"
    build_cmd+=" --builder ${BUILDER_NAME}"
    build_cmd+=" --platform ${PLATFORMS}"
    build_cmd+=" -t ${REGISTRY}/${service}:${VERSION}"
    build_cmd+=" -t ${REGISTRY}/${service}:latest"
    
    # Add cache options if specified
    if [ -n "${CACHE_FROM}" ]; then
        build_cmd+=" --cache-from ${CACHE_FROM}"
    fi
    if [ -n "${CACHE_TO}" ]; then
        build_cmd+=" --cache-to ${CACHE_TO}"
    fi
    
    # Add no-cache flag if specified
    if [ -n "${NO_CACHE}" ]; then
        build_cmd+=" ${NO_CACHE}"
    fi
    
    # Add push flag if enabled
    if [ "${PUSH}" = "true" ]; then
        build_cmd+=" --push"
    else
        # For multi-platform, we can't use --load, so we just build
        # If single platform, we can load
        if [[ "$PLATFORMS" != *","* ]]; then
            build_cmd+=" --load"
        fi
    fi
    
    # Build labels
    build_cmd+=" --label org.opencontainers.image.version=${VERSION}"
    build_cmd+=" --label org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    build_cmd+=" --label org.opencontainers.image.source=https://github.com/your-org/mailserver-k8s"
    build_cmd+=" --label org.opencontainers.image.title=${service}"
    build_cmd+=" --label org.opencontainers.image.description='Mailserver ${service} component'"
    
    # Build context
    build_cmd+=" ${service_dir}"
    
    echo -e "${YELLOW}→ Building ${service}...${NC}"
    if [ "${LOG_LEVEL}" = "DEBUG" ]; then
        echo -e "${YELLOW}Command: ${build_cmd}${NC}"
    fi
    
    # Execute build
    local start_time=$(date +%s)
    if eval "${build_cmd}"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ ${service} built successfully (${duration}s)${NC}"
        SUCCESS+=("${service}")
        return 0
    else
        echo -e "${RED}✗ ${service} build failed${NC}"
        FAILED+=("${service}")
        return 1
    fi
}

# Build base image first
echo -e "${BLUE}=========================================="
echo "Building base image"
echo -e "==========================================${NC}"

BASE_BUILD_CMD="docker buildx build"
BASE_BUILD_CMD+=" --builder ${BUILDER_NAME}"
BASE_BUILD_CMD+=" --platform ${PLATFORMS}"
BASE_BUILD_CMD+=" -t ${REGISTRY}/base:${VERSION}"
BASE_BUILD_CMD+=" -t ${REGISTRY}/base:latest"

if [ -n "${NO_CACHE}" ]; then
    BASE_BUILD_CMD+=" ${NO_CACHE}"
fi

if [ "${PUSH}" = "true" ]; then
    BASE_BUILD_CMD+=" --push"
else
    if [[ "$PLATFORMS" != *","* ]]; then
        BASE_BUILD_CMD+=" --load"
    fi
fi

BASE_BUILD_CMD+=" --label org.opencontainers.image.version=${VERSION}"
BASE_BUILD_CMD+=" --label org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
BASE_BUILD_CMD+=" -f docker/base/Dockerfile.base ."

echo -e "${YELLOW}→ Building base image...${NC}"
if [ "${LOG_LEVEL}" = "DEBUG" ]; then
    echo -e "${YELLOW}Command: ${BASE_BUILD_CMD}${NC}"
fi

base_start=$(date +%s)
if eval "${BASE_BUILD_CMD}"; then
    base_end=$(date +%s)
    base_duration=$((base_end - base_start))
    echo -e "${GREEN}✓ Base image built successfully (${base_duration}s)${NC}"
else
    echo -e "${RED}✗ Base image build failed${NC}"
    exit 1
fi

# Build all services
for service in "${SERVICES[@]}"; do
    build_service "${service}" || true
done

# Summary
echo ""
echo -e "${BLUE}=========================================="
echo "Build Summary"
echo -e "==========================================${NC}"
echo -e "Total services: ${TOTAL}"
echo -e "Successful: ${GREEN}${#SUCCESS[@]}${NC}"
echo -e "Failed: ${RED}${#FAILED[@]}${NC}"

if [ ${#SUCCESS[@]} -gt 0 ]; then
    echo -e "\n${GREEN}✓ Successful builds:${NC}"
    for service in "${SUCCESS[@]}"; do
        echo -e "  ${GREEN}✓${NC} ${service}"
    done
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "\n${RED}✗ Failed builds:${NC}"
    for failed in "${FAILED[@]}"; do
        echo -e "  ${RED}✗${NC} ${failed}"
    done
    exit 1
else
    echo -e "\n${GREEN}=========================================="
    echo "✓ All services built successfully!"
    echo -e "==========================================${NC}"
    
    if [ "${PUSH}" = "true" ]; then
        echo -e "\n${GREEN}✓ All images pushed to ${REGISTRY}${NC}"
    else
        if [[ "$PLATFORMS" == *","* ]]; then
            echo -e "\n${YELLOW}⚠ Multi-platform images built but not loaded locally${NC}"
            echo -e "${YELLOW}  Use --push to push to registry, or build single platform with --platform${NC}"
        else
            echo -e "\n${GREEN}✓ Images loaded locally${NC}"
        fi
    fi
fi

# List built images
echo ""
echo -e "${BLUE}Built images:${NC}"
echo -e "  ${GREEN}✓${NC} ${REGISTRY}/base:${VERSION}"
for service in "${SUCCESS[@]}"; do
    echo -e "  ${GREEN}✓${NC} ${REGISTRY}/${service}:${VERSION}"
done

# Show next steps
echo ""
echo -e "${BLUE}Next steps:${NC}"
if [ "${PUSH}" != "true" ]; then
    echo -e "  1. Test images locally"
    echo -e "  2. Push to registry: $0 --push"
else
    echo -e "  1. Deploy to Kubernetes: helm install mailserver ./infra/helm/mailserver"
    echo -e "  2. Check deployment: kubectl get pods -n mail"
fi