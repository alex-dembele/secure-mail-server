#!/bin/bash
# ============================================
# Postfix Health Check Script
# ============================================

set -e

# Check if Postfix master process is running
if ! pgrep -x "master" > /dev/null; then
    echo "ERROR: Postfix master process not running"
    exit 1
fi

# Check if SMTP port is listening
if ! nc -z localhost 25 2>/dev/null; then
    echo "ERROR: SMTP port 25 not listening"
    exit 1
fi

# Check if submission port is listening (if configured)
if [ "${ENABLE_SUBMISSION:-true}" = "true" ]; then
    if ! nc -z localhost 587 2>/dev/null; then
        echo "ERROR: Submission port 587 not listening"
        exit 1
    fi
fi

# Try to connect and send EHLO command
EHLO_RESPONSE=$(echo "EHLO healthcheck" | nc -w 5 localhost 25 2>/dev/null | head -n 1)
if ! echo "$EHLO_RESPONSE" | grep -q "^220"; then
    echo "ERROR: SMTP not responding correctly"
    exit 1
fi

# Check queue size (warn if too large)
QUEUE_SIZE=$(postqueue -p | tail -n 1 | awk '{print $5}')
if [ ! -z "$QUEUE_SIZE" ] && [ "$QUEUE_SIZE" != "empty" ]; then
    QUEUE_COUNT=$(postqueue -p | grep -c "^[A-F0-9]" || echo "0")
    if [ "$QUEUE_COUNT" -gt 1000 ]; then
        echo "WARNING: Large queue size: $QUEUE_COUNT messages"
        # Don't fail health check, just warn
    fi
fi

# Check for deferred queue buildup
DEFERRED_COUNT=$(find /var/spool/postfix/deferred -type f 2>/dev/null | wc -l)
if [ "$DEFERRED_COUNT" -gt 500 ]; then
    echo "WARNING: Large deferred queue: $DEFERRED_COUNT messages"
    # Don't fail health check, just warn
fi

# Check if Postfix is in a healthy state
POSTFIX_STATUS=$(postfix status 2>&1)
if ! echo "$POSTFIX_STATUS" | grep -q "is running"; then
    echo "ERROR: Postfix not in running state"
    exit 1
fi

# All checks passed
exit 0