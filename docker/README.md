# 🐋 Docker Configuration

This directory contains Docker configuration for building multi-architecture container images for the mailserver project.

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Multi-Architecture Support](#multi-architecture-support)
- [Directory Structure](#directory-structure)
- [Building Images](#building-images)
- [Base Image](#base-image)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The mailserver uses Docker Buildx to create multi-architecture container images supporting both **amd64** (x86_64) and **arm64** (ARM64/aarch64) platforms.

### Supported Platforms

- `linux/amd64` - Intel/AMD 64-bit processors
- `linux/arm64` - ARM 64-bit processors (Apple Silicon, AWS Graviton, Raspberry Pi 4+)

## Quick Start

### 1. Setup Buildx Builder

```bash
# Run the setup script
./docker/buildx-setup.sh

# Or manually:
docker buildx create --name mailserver-builder --driver docker-container --use
docker buildx inspect --bootstrap
```

### 2. Build All Services

```bash
# Build all services for both architectures
./docker/build.sh

# Build and push to registry
./docker/build.sh --push --registry ghcr.io/your-org

# Build specific service only
./docker/build.sh --service postfix

# Build for single architecture (faster for testing)
./docker/build.sh --platform linux/amd64
```

### 3. Using Makefile

```bash
# Build all images (multi-arch)
make build

# Build for local architecture only (faster)
make build-local

# Build and push
REGISTRY=ghcr.io/your-org make build
```

## Multi-Architecture Support

### How It Works

Docker Buildx uses QEMU emulation to build images for different CPU architectures on a single machine. The build process:

1. **Builder Instance**: Creates a dedicated builder with multi-platform support
2. **Manifest List**: Generates a single image tag that points to architecture-specific images
3. **Automatic Selection**: Docker automatically pulls the correct image for the host architecture

### Build Arguments

Each Dockerfile receives these build arguments automatically:

```dockerfile
ARG TARGETPLATFORM    # e.g., linux/amd64, linux/arm64
ARG BUILDPLATFORM     # Platform performing the build
ARG TARGETOS          # e.g., linux
ARG TARGETARCH        # e.g., amd64, arm64
```

Example usage in Dockerfile:

```dockerfile
RUN echo "Building for ${TARGETARCH} on ${BUILDPLATFORM}"
```

### Performance Considerations

- **Native builds**: Very fast (5-10 minutes)
- **Emulated builds**: Slower (20-45 minutes for arm64 on amd64)
- **Parallel builds**: Use CI/CD with native runners for each architecture

## Directory Structure

```
docker/
├── base/
│   └── Dockerfile.base          # Base image for all services
├── scripts/
│   ├── entrypoint.sh           # Common entrypoint
│   └── healthcheck.sh          # Common healthcheck
├── buildx-setup.sh             # Setup buildx builder
├── build.sh                    # Build all services
├── docker-compose.base.yml     # Base compose config
└── README.md                   # This file
```

## Building Images

### Build Script Options

```bash
./docker/build.sh [OPTIONS]

Options:
  --push              Push images to registry
  --registry REGISTRY Registry URL (default: ghcr.io/your-org)
  --version VERSION   Image version tag (default: from VERSION file)
  --platform PLATFORMS Target platforms (comma-separated)
  --service SERVICE   Build specific service only
  --no-cache         Build without cache
  --help             Show help message
```

### Examples

#### Build all services locally

```bash
./docker/build.sh
```

#### Build and push to registry

```bash
./docker/build.sh \
  --push \
  --registry ghcr.io/myorg \
  --version 1.0.0
```

#### Build single service

```bash
./docker/build.sh --service postfix
```

#### Build for single architecture (testing)

```bash
./docker/build.sh --platform linux/amd64 --service dovecot
```

#### Build without cache

```bash
./docker/build.sh --no-cache --service rspamd
```

### Manual Build

```bash
# Set up builder (one time)
docker buildx use mailserver-builder

# Build a service
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/your-org/postfix:1.0.0 \
  --push \
  ./services/postfix
```

## Base Image

All service images extend from a common base image (`Dockerfile.base`) which provides:

### Included Components

- **Base OS**: Alpine Linux 3.19 (minimal, secure)
- **Init System**: Tini (proper signal handling)
- **Common Tools**: bash, curl, netcat, bind-tools
- **Security**: Non-root user (uid 5000), CA certificates
- **Logging**: rsyslog
- **Monitoring**: procps for health checks

### Base Image Features

```dockerfile
FROM ghcr.io/your-org/base:1.0.0

# All services inherit:
# - Common environment variables
# - Non-root user 'mailserver' (5000:5000)
# - Standard directory structure
# - Entrypoint and healthcheck scripts
# - Logging configuration
```

### Environment Variables

Standard environment variables available in all containers:

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Timezone |
| `LOG_LEVEL` | `INFO` | Logging level |
| `MAILSERVER_VERSION` | `1.0.0` | Version |
| `WAIT_FOR_HOST` | - | Wait for host before starting |
| `WAIT_FOR_PORT` | `3306` | Port to wait for |
| `WAIT_TIMEOUT` | `60` | Wait timeout in seconds |

## Best Practices

### 1. Multi-Stage Builds

Use multi-stage builds to minimize final image size:

```dockerfile
# Build stage
FROM alpine:3.19 AS builder
RUN apk add --no-cache build-base
COPY . /src
RUN cd /src && make build

# Runtime stage
FROM ghcr.io/your-org/base:1.0.0
COPY --from=builder /src/output /app
CMD ["/app/server"]
```

### 2. Layer Caching

Order Dockerfile commands from least to most frequently changing:

```dockerfile
# 1. Base image
FROM base

# 2. System packages (rarely change)
RUN apk add --no-cache package1 package2

# 3. Application dependencies (change occasionally)
COPY requirements.txt .
RUN pip install -r requirements.txt

# 4. Application code (changes frequently)
COPY . .
```

### 3. Security

- Always run as non-root user
- Scan images with Trivy: `trivy image your-image:tag`
- Keep base image updated
- Use specific version tags, not `latest`
- Don't include secrets in images

### 4. Size Optimization

```dockerfile
# Combine RUN commands
RUN apk add --no-cache package1 package2 && \
    rm -rf /var/cache/apk/* /tmp/*

# Use .dockerignore
# Clean up in same layer
RUN wget file.tar.gz && \
    tar xzf file.tar.gz && \
    rm file.tar.gz
```

### 5. Health Checks

Always define health checks:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh
```

## Troubleshooting

### Builder Not Found

```bash
# List builders
docker buildx ls

# Create builder
./docker/buildx-setup.sh

# Or manually
docker buildx create --name mailserver-builder --use
```

### QEMU Not Available

```bash
# Install QEMU binfmt support
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Verify
docker buildx inspect --bootstrap
```

### Build Fails on ARM

If ARM builds fail with "exec format error":

```bash
# Reinstall QEMU
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Rebuild
docker buildx build --platform linux/arm64 ...
```

### Slow Builds

Emulated builds (e.g., arm64 on amd64 host) are inherently slower:

**Solutions**:
- Use native builders in CI/CD
- Build only needed architecture locally: `--platform linux/amd64`
- Enable BuildKit cache: `--cache-from` and `--cache-to`
- Use remote cache (registry cache)

### Out of Disk Space

```bash
# Clean up
docker system prune -a --volumes

# Remove build cache
docker buildx prune -a

# Check disk usage
docker system df
```

### Cannot Push to Registry

```bash
# Login to registry
docker login ghcr.io

# Or use token
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin

# Verify credentials
cat ~/.docker/config.json
```

### Image Not Found After Build

If `--load` is used with multiple platforms, Docker can only load one platform:

```bash
# Solution 1: Push to registry
./docker/build.sh --push

# Solution 2: Build for single platform
./docker/build.sh --platform linux/amd64

# Solution 3: Use docker save/load
docker buildx build --platform linux/amd64 -o type=docker -t image:tag .
```

## Advanced Usage

### Remote Cache

```bash
# Build with remote cache
./docker/build.sh \
  --cache-from type=registry,ref=ghcr.io/your-org/cache:buildcache \
  --cache-to type=registry,ref=ghcr.io/your-org/cache:buildcache,mode=max
```

### Custom Builder

```bash
# Create builder with specific config
docker buildx create \
  --name custom-builder \
  --driver docker-container \
  --driver-opt network=host \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure' \
  --use
```

### Build Matrix (CI/CD)

```yaml
strategy:
  matrix:
    platform:
      - linux/amd64
      - linux/arm64

steps:
  - name: Build
    run: |
      docker buildx build \
        --platform ${{ matrix.platform }} \
        --output type=image,push=true \
        --tag myimage:latest .
```

## References

- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [Multi-platform Images](https://docs.docker.com/build/building/multi-platform/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [BuildKit](https://github.com/moby/buildkit)