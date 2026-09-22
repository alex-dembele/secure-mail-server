#!/bin/bash
# ============================================
# Common Entrypoint Script
# Used by all mailserver containers
# ============================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo "Mailserver Container Starting"
echo -e "==========================================${NC}"

# Environment variables with defaults
export TZ="${TZ:-UTC}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export COMPONENT_NAME="${COMPONENT_NAME:-mailserver}"

# Set timezone
if [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    echo -e "${GREEN}✓ Timezone set to: ${TZ}${NC}"
else
    echo -e "${YELLOW}⚠ Timezone ${TZ} not found, using UTC${NC}"
    ln -snf /usr/share/zoneinfo/UTC /etc/localtime
fi

# Display startup information
echo "Component: ${COMPONENT_NAME}"
echo "Version: ${MAILSERVER_VERSION:-unknown}"
echo "Architecture: $(uname -m)"
echo "OS: $(uname -s)"
echo "Kernel: $(uname -r)"
echo "User: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "Working directory: $(pwd)"
echo "Log Level: ${LOG_LEVEL}"
echo "=========================================="

# Wait for dependencies (if specified)
if [ -n "${WAIT_FOR_HOST}" ]; then
    echo -e "${YELLOW}→ Waiting for ${WAIT_FOR_HOST}:${WAIT_FOR_PORT:-3306}...${NC}"
    
    timeout="${WAIT_TIMEOUT:-60}"
    elapsed=0
    wait_port="${WAIT_FOR_PORT:-3306}"
    
    while ! nc -z "${WAIT_FOR_HOST}" "${wait_port}" 2>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            echo -e "${RED}✗ Timeout waiting for ${WAIT_FOR_HOST}:${wait_port} after ${timeout}s${NC}"
            exit 1
        fi
        
        if [ $((elapsed % 10)) -eq 0 ]; then
            echo "Still waiting... (${elapsed}/${timeout}s)"
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo -e "${GREEN}✓ ${WAIT_FOR_HOST}:${wait_port} is ready (after ${elapsed}s)${NC}"
    
    # Additional wait to ensure service is fully ready
    echo "Waiting additional 5 seconds for service initialization..."
    sleep 5
fi

# Wait for multiple dependencies (comma-separated)
if [ -n "${WAIT_FOR_HOSTS}" ]; then
    IFS=',' read -ra HOSTS <<< "$WAIT_FOR_HOSTS"
    for host_port in "${HOSTS[@]}"; do
        host=$(echo "$host_port" | cut -d: -f1)
        port=$(echo "$host_port" | cut -d: -f2)
        
        echo -e "${YELLOW}→ Waiting for ${host}:${port}...${NC}"
        
        timeout="${WAIT_TIMEOUT:-60}"
        elapsed=0
        
        while ! nc -z "${host}" "${port}" 2>/dev/null; do
            if [ $elapsed -ge $timeout ]; then
                echo -e "${RED}✗ Timeout waiting for ${host}:${port}${NC}"
                exit 1
            fi
            sleep 2
            elapsed=$((elapsed + 2))
        done
        
        echo -e "${GREEN}✓ ${host}:${port} is ready${NC}"
    done
fi

# Create required directories if they don't exist
create_dirs() {
    local dirs=(
        "/var/log/mailserver"
        "/var/run/mailserver"
        "/etc/mailserver"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo -e "${GREEN}✓ Created directory: ${dir}${NC}"
        fi
    done
}

create_dirs

# Set proper permissions
set_permissions() {
    # Only if running as root
    if [ "$(id -u)" = "0" ]; then
        echo -e "${YELLOW}→ Setting permissions...${NC}"
        
        # Ensure mailserver user owns its directories
        chown -R mailserver:mailserver /var/mail /var/log/mailserver /var/run/mailserver 2>/dev/null || true
        
        echo -e "${GREEN}✓ Permissions set${NC}"
    fi
}

set_permissions

# Run pre-start hooks (if exists)
if [ -f "/usr/local/bin/pre-start.sh" ]; then
    echo -e "${BLUE}→ Running pre-start hooks...${NC}"
    
    if bash /usr/local/bin/pre-start.sh; then
        echo -e "${GREEN}✓ Pre-start hooks completed${NC}"
    else
        echo -e "${RED}✗ Pre-start hooks failed${NC}"
        exit 1
    fi
fi

# Run component-specific initialization (if exists)
if [ -f "/usr/local/bin/init-${COMPONENT_NAME}.sh" ]; then
    echo -e "${BLUE}→ Running ${COMPONENT_NAME} initialization...${NC}"
    
    if bash "/usr/local/bin/init-${COMPONENT_NAME}.sh"; then
        echo -e "${GREEN}✓ ${COMPONENT_NAME} initialization completed${NC}"
    else
        echo -e "${RED}✗ ${COMPONENT_NAME} initialization failed${NC}"
        exit 1
    fi
fi

# Display environment variables (excluding sensitive ones)
if [ "${LOG_LEVEL}" = "DEBUG" ]; then
    echo -e "${BLUE}→ Environment variables:${NC}"
    env | grep -v -E '(PASSWORD|SECRET|KEY|TOKEN)' | sort
fi

# Trap signals for graceful shutdown
trap_handler() {
    echo -e "\n${YELLOW}Received shutdown signal, cleaning up...${NC}"
    
    # Run cleanup script if exists
    if [ -f "/usr/local/bin/cleanup.sh" ]; then
        bash /usr/local/bin/cleanup.sh
    fi
    
    echo -e "${GREEN}✓ Cleanup completed, exiting${NC}"
    exit 0
}

trap trap_handler SIGTERM SIGINT SIGQUIT

# Final message
echo -e "${GREEN}=========================================="
echo "✓ Initialization complete"
echo "→ Starting main process..."
echo -e "==========================================${NC}"
echo ""

# Execute the main command
# If running as root and command should run as mailserver user
if [ "$(id -u)" = "0" ] && [ "${RUN_AS_ROOT}" != "true" ]; then
    # Use su-exec to drop privileges
    echo "Executing as user: mailserver"
    exec su-exec mailserver "$@"
else
    # Run directly
    exec "$@"
fi