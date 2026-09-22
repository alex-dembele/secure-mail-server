#!/bin/bash
# ============================================
# Common Health Check Script
# Override this in specific service images
# ============================================

set -e

# Component-specific health check script location
COMPONENT_HEALTHCHECK="/usr/local/bin/healthcheck-${COMPONENT_NAME}.sh"

# If component-specific healthcheck exists, use it
if [ -f "${COMPONENT_HEALTHCHECK}" ]; then
    exec bash "${COMPONENT_HEALTHCHECK}"
fi

# Default health checks based on COMPONENT_NAME
case "${COMPONENT_NAME}" in
    postfix)
        # Check if Postfix master process is running
        if pgrep -x "master" > /dev/null; then
            # Try to connect to SMTP port
            if nc -z localhost 25 2>/dev/null; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    dovecot)
        # Check if Dovecot is running
        if pgrep -x "dovecot" > /dev/null; then
            # Try to connect to IMAP port
            if nc -z localhost 143 2>/dev/null; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    rspamd)
        # Check if Rspamd is running
        if pgrep -x "rspamd" > /dev/null; then
            # Check controller interface
            if curl -sf http://localhost:11334/ping > /dev/null 2>&1; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    opendkim)
        # Check if OpenDKIM is running
        if pgrep -x "opendkim" > /dev/null; then
            # Check socket
            if [ -S /var/run/opendkim/opendkim.sock ]; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    clamav)
        # Check if ClamAV daemon is running
        if pgrep -x "clamd" > /dev/null; then
            # Try to ping clamd
            if echo "PING" | nc -w 1 localhost 3310 | grep -q "PONG"; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    mysql|mariadb)
        # Check if MySQL/MariaDB is running
        if pgrep -x "mysqld" > /dev/null; then
            # Try to connect
            if mysqladmin ping -h localhost --silent 2>/dev/null; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    redis)
        # Check if Redis is running
        if pgrep -x "redis-server" > /dev/null; then
            # Try to ping Redis
            if redis-cli ping 2>/dev/null | grep -q "PONG"; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    nginx)
        # Check if Nginx is running
        if pgrep -x "nginx" > /dev/null; then
            # Check if responding on port 80
            if curl -sf http://localhost/ > /dev/null 2>&1; then
                exit 0
            fi
        fi
        exit 1
        ;;
        
    admin-api)
        # Check if API is running and responding
        if [ -n "${API_PORT}" ]; then
            if curl -sf "http://localhost:${API_PORT}/health" > /dev/null 2>&1; then
                exit 0
            fi
        fi
        # Fallback to port 8080
        if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
            exit 0
        fi
        exit 1
        ;;
        
    web-ui)
        # Check if web UI is responding
        if [ -n "${WEB_UI_PORT}" ]; then
            if curl -sf "http://localhost:${WEB_UI_PORT}/" > /dev/null 2>&1; then
                exit 0
            fi
        fi
        # Fallback to port 3000
        if curl -sf http://localhost:3000/ > /dev/null 2>&1; then
            exit 0
        fi
        exit 1
        ;;
        
    *)
        # Generic health check
        
        # Check if specific process name is defined
        if [ -n "${PROCESS_NAME}" ]; then
            if pgrep -f "${PROCESS_NAME}" > /dev/null; then
                exit 0
            else
                exit 1
            fi
        fi
        
        # Check if health check port is defined
        if [ -n "${HEALTHCHECK_PORT}" ]; then
            if nc -z localhost "${HEALTHCHECK_PORT}" 2>/dev/null; then
                exit 0
            else
                exit 1
            fi
        fi
        
        # Check if health check URL is defined
        if [ -n "${HEALTHCHECK_URL}" ]; then
            if curl -sf "${HEALTHCHECK_URL}" > /dev/null 2>&1; then
                exit 0
            else
                exit 1
            fi
        fi
        
        # Default: assume healthy if we got here
        # (Override this in component-specific images)
        exit 0
        ;;
esac

# Should not reach here
exit 1