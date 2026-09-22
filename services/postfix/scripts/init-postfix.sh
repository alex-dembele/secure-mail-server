#!/bin/bash
# ============================================
# Postfix Initialization Script
# ============================================

set -e

echo "==========================================="
echo "Initializing Postfix..."
echo "==========================================="

# Default environment variables
export HOSTNAME="${HOSTNAME:-mail.example.com}"
export PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-example.com}"
export DB_HOST="${DB_HOST:-mysql}"
export DB_PORT="${DB_PORT:-3306}"
export DB_NAME="${DB_NAME:-mailserver}"
export DB_USER="${DB_USER:-mailserver_app}"
export DB_PASSWORD="${DB_PASSWORD:-changeme}"
export MAX_MESSAGE_SIZE_MB="${MAX_MESSAGE_SIZE_MB:-50}"
export MAX_MAILBOX_SIZE_GB="${MAX_MAILBOX_SIZE_GB:-10}"
export TLS_CERT_FILE="${TLS_CERT_FILE:-/etc/postfix/ssl/cert.pem}"
export TLS_KEY_FILE="${TLS_KEY_FILE:-/etc/postfix/ssl/key.pem}"
export TLS_CA_FILE="${TLS_CA_FILE:-/etc/postfix/ssl/ca.pem}"
export RELAY_HOST="${RELAY_HOST:-}"
export RELAY_DOMAINS="${RELAY_DOMAINS:-}"
export TRUSTED_NETWORKS="${TRUSTED_NETWORKS:-10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"
export SMTPD_CLIENT_CONNECTION_COUNT_LIMIT="${SMTPD_CLIENT_CONNECTION_COUNT_LIMIT:-50}"
export SMTPD_CLIENT_CONNECTION_RATE_LIMIT="${SMTPD_CLIENT_CONNECTION_RATE_LIMIT:-100}"
export SMTPD_CLIENT_MESSAGE_RATE_LIMIT="${SMTPD_CLIENT_MESSAGE_RATE_LIMIT:-100}"
export SMTPD_CLIENT_RECIPIENT_RATE_LIMIT="${SMTPD_CLIENT_RECIPIENT_RATE_LIMIT:-200}"
export DEBUG_PEER_LEVEL="${DEBUG_PEER_LEVEL:-0}"
export DEBUG_PEER_LIST="${DEBUG_PEER_LIST:-}"
export DEFAULT_PROCESS_LIMIT="${DEFAULT_PROCESS_LIMIT:-100}"

echo "→ Configuration:"
echo "  Hostname: ${HOSTNAME}"
echo "  Primary Domain: ${PRIMARY_DOMAIN}"
echo "  Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "  Max Message Size: ${MAX_MESSAGE_SIZE_MB}MB"
echo "  Max Mailbox Size: ${MAX_MAILBOX_SIZE_GB}GB"

# Create required directories
echo "→ Creating directories..."
mkdir -p /var/spool/postfix/{active,bounce,corrupt,defer,deferred,flush,hold,incoming,maildrop,private,public,saved,trace}
mkdir -p /var/log/postfix
mkdir -p /etc/postfix/ssl

# Set proper permissions
echo "→ Setting permissions..."
chown -R postfix:postfix /var/spool/postfix
chown -R postfix:postfix /var/log/postfix
chmod 755 /var/spool/postfix
chmod 700 /var/spool/postfix/maildrop

# Process configuration templates with environment variables
echo "→ Processing configuration templates..."

# Main configuration
envsubst < /etc/postfix/main.cf.template > /etc/postfix/main.cf
echo "  ✓ main.cf generated"

# Master configuration
cp /etc/postfix/master.cf.template /etc/postfix/master.cf
echo "  ✓ master.cf generated"

# MySQL configuration files
for mysql_file in mysql-virtual-mailbox-domains.cf \
                  mysql-virtual-mailbox-maps.cf \
                  mysql-virtual-alias-maps.cf \
                  mysql-virtual-sender-login-maps.cf \
                  mysql-virtual-mailbox-limit-maps.cf; do
    if [ -f "/etc/postfix/${mysql_file}.template" ]; then
        envsubst < "/etc/postfix/${mysql_file}.template" > "/etc/postfix/${mysql_file}"
        chmod 640 "/etc/postfix/${mysql_file}"
        chown root:postfix "/etc/postfix/${mysql_file}"
        echo "  ✓ ${mysql_file} generated"
    fi
done

# Generate default TLS certificates if not provided
if [ ! -f "${TLS_CERT_FILE}" ] || [ ! -f "${TLS_KEY_FILE}" ]; then
    echo "→ Generating self-signed TLS certificate..."
    openssl req -new -x509 -days 365 -nodes \
        -out "${TLS_CERT_FILE}" \
        -keyout "${TLS_KEY_FILE}" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${HOSTNAME}" 2>/dev/null
    chmod 644 "${TLS_CERT_FILE}"
    chmod 600 "${TLS_KEY_FILE}"
    echo "  ✓ Self-signed certificate generated"
    echo "  ⚠ WARNING: Using self-signed certificate. Replace with valid certificate in production!"
fi

# Create default aliases
if [ ! -f /etc/postfix/aliases ]; then
    echo "→ Creating default aliases..."
    cat > /etc/postfix/aliases <<EOF
# Default aliases
postmaster: root
abuse: root
hostmaster: root
webmaster: root
EOF
    newaliases
    echo "  ✓ Aliases created"
fi

# Initialize Postfix databases
echo "→ Initializing Postfix databases..."
postfix check
postmap /etc/postfix/aliases 2>/dev/null || true

# Update chroot environment
echo "→ Updating chroot environment..."
postfix set-permissions 2>/dev/null || true

# Test database connectivity
echo "→ Testing database connectivity..."
timeout=30
elapsed=0
while ! nc -z ${DB_HOST} ${DB_PORT} 2>/dev/null; do
    if [ $elapsed -ge $timeout ]; then
        echo "  ✗ Database not reachable after ${timeout}s"
        echo "  ⚠ WARNING: Database connectivity issues may affect mail delivery"
        break
    fi
    echo "  Waiting for database... (${elapsed}/${timeout}s)"
    sleep 2
    elapsed=$((elapsed + 2))
done

if nc -z ${DB_HOST} ${DB_PORT} 2>/dev/null; then
    echo "  ✓ Database is reachable"
fi

# Show configuration summary
echo ""
echo "==========================================="
echo "Postfix Configuration Summary"
echo "==========================================="
postconf -n | grep -E "(myhostname|mydomain|inet_interfaces|virtual_mailbox_domains|smtpd_tls|smtp_tls)"
echo "==========================================="

echo "✓ Postfix initialization complete"