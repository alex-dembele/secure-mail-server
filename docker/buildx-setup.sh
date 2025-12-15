#!/bin/bash
# ============================================
# Docker Buildx Setup Script
# Creates and configures buildx builder for multi-arch builds
# ============================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BUILDER_NAME="${BUILDER_NAME:-mailserver-builder}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

echo -e "${GREEN}==========================================="
echo -e "Docker Buildx Setup for Mailserver"
echo -e "===========================================${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker found: $(docker --version)${NC}"

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo -e "${RED}✗ Docker buildx is not available${NC}"
    echo -e "${YELLOW}Please upgrade Docker to a version that includes buildx${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker buildx found: $(docker buildx version)${NC}"

# Check if builder already exists
if docker buildx inspect "${BUILDER_NAME}" &> /dev/null; then
    echo -e "${YELLOW}⚠ Builder '${BUILDER_NAME}' already exists${NC}"
    read -p "Do you want to remove and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}→ Removing existing builder...${NC}"
        docker buildx rm "${BUILDER_NAME}"
        echo -e "${GREEN}✓ Builder removed${NC}"
    else
        echo -e "${YELLOW}→ Using existing builder${NC}"
        docker buildx use "${BUILDER_NAME}"
        echo -e "${GREEN}✓ Builder activated${NC}"
        exit 0
    fi
fi

# Create new builder instance
echo -e "${YELLOW}→ Creating new buildx builder: ${BUILDER_NAME}${NC}"
docker buildx create \
    --name "${BUILDER_NAME}" \
    --driver docker-container \
    --platform "${PLATFORMS}" \
    --bootstrap \
    --use

echo -e "${GREEN}✓ Builder created and activated${NC}"

# Inspect builder
echo -e "\n${YELLOW}→ Builder information:${NC}"
docker buildx inspect "${BUILDER_NAME}"

# List available platforms
echo -e "\n${GREEN}✓ Available platforms:${NC}"
docker buildx inspect "${BUILDER_NAME}" | grep "Platforms:"

# Test build capability
echo -e "\n${YELLOW}→ Testing multi-arch build capability...${NC}"
cat > /tmp/test-dockerfile << 'EOF'
FROM alpine:3.19
RUN echo "Multi-arch test successful"
EOF

if docker buildx build \
    --platform "${PLATFORMS}" \
    --builder "${BUILDER_NAME}" \
    -f /tmp/test-dockerfile \
    -t test-multiarch:latest \
    /tmp > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Multi-arch build test passed${NC}"
    rm /tmp/test-dockerfile
else
    echo -e "${RED}✗ Multi-arch build test failed${NC}"
    rm /tmp/test-dockerfile
    exit 1
fi

# Show buildx configuration
echo -e "\n${YELLOW}→ Buildx configuration:${NC}"
echo "Builder name: ${BUILDER_NAME}"
echo "Platforms: ${PLATFORMS}"
echo "Driver: docker-container"

echo -e "\n${GREEN}==========================================="
echo -e "Setup Complete!"
echo -e "===========================================${NC}"
echo -e "\n${YELLOW}Usage examples:${NC}"
echo -e "  # Build single service"
echo -e "  docker buildx build --platform ${PLATFORMS} \\"
echo -e "    --builder ${BUILDER_NAME} \\"
echo -e "    -t your-registry/postfix:latest \\"
echo -e "    ./services/postfix"
echo -e ""
echo -e "  # Build and push"
echo -e "  docker buildx build --platform ${PLATFORMS} \\"
echo -e "    --builder ${BUILDER_NAME} \\"
echo -e "    -t your-registry/postfix:latest \\"
echo -e "    --push \\"
echo -e "    ./services/postfix"
echo -e ""
echo -e "  # Use Makefile"
echo -e "  make build"
echo -e ""

# Save builder info
mkdir -p .docker
cat > .docker/builder.env << EOF
BUILDER_NAME=${BUILDER_NAME}
PLATFORMS=${PLATFORMS}
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
EOF

echo -e "${GREEN}✓ Builder configuration saved to .docker/builder.env${NC}"