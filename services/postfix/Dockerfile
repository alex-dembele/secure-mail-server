# ============================================
# Postfix MTA Docker Image
# Multi-architecture: amd64, arm64
# ============================================

FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    postfix \
    postfix-mysql \
    cyrus-sasl \
    cyrus-sasl-login \
    cyrus-sasl-crammd5

# ============================================
# Final stage
# ============================================
FROM ghcr.io/your-org/base:latest

# Metadata
LABEL maintainer="mailserver-team@example.com"
LABEL version="1.0.0"
LABEL description="Postfix MTA for mailserver-k8s"
LABEL org.opencontainers.image.source="https://github.com/your-org/mailserver-k8s"
LABEL org.opencontainers.image.title="Postfix MTA"

# Set component name for scripts
ENV COMPONENT_NAME=postfix

# Install Postfix and dependencies
RUN apk add --no-cache \
    # Postfix packages
    postfix \
    postfix-mysql \
    # SASL authentication
    cyrus-sasl \
    cyrus-sasl-login \
    cyrus-sasl-crammd5 \
    cyrus-sasl-digestmd5 \
    # TLS support
    ca-certificates \
    # Utilities
    mailx \
    s-nail \
    # Monitoring
    pflogsumm && \
    # Cleanup
    rm -rf /var/cache/apk/* /tmp/*

# Create postfix user and directories
RUN addgroup -g 101 postfix && \
    adduser -D -u 101 -G postfix -h /var/spool/postfix -s /sbin/nologin postfix && \
    addgroup -g 102 postdrop && \
    adduser -D -u 102 -G postdrop -h /var/spool/postfix -s /sbin/nologin postdrop

# Create required directories
RUN mkdir -p \
    /var/spool/postfix \
    /var/mail \
    /etc/postfix \
    /var/log/postfix && \
    # Set permissions
    chown -R postfix:postfix /var/spool/postfix /var/log/postfix && \
    chmod 755 /var/spool/postfix

# Copy Postfix configuration files
COPY config/main.cf /etc/postfix/main.cf.template
COPY config/master.cf /etc/postfix/master.cf.template
COPY config/virtual /etc/postfix/virtual.template
COPY config/header_checks /etc/postfix/header_checks
COPY config/mime_header_checks /etc/postfix/mime_header_checks

# Copy initialization and health check scripts
COPY scripts/init-postfix.sh /usr/local/bin/init-postfix.sh
COPY scripts/healthcheck-postfix.sh /usr/local/bin/healthcheck-postfix.sh
COPY scripts/postconf-setup.sh /usr/local/bin/postconf-setup.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/init-postfix.sh \
    /usr/local/bin/healthcheck-postfix.sh \
    /usr/local/bin/postconf-setup.sh

# Create SASL configuration
RUN mkdir -p /etc/sasl2 && \
    echo 'pwcheck_method: saslauthd' > /etc/sasl2/smtpd.conf && \
    echo 'mech_list: PLAIN LOGIN' >> /etc/sasl2/smtpd.conf

# Expose ports
# 25   - SMTP
# 587  - Submission (with STARTTLS)
# 465  - SMTPS (deprecated but sometimes needed)
EXPOSE 25 587 465

# Volumes
VOLUME ["/var/spool/postfix", "/var/mail", "/etc/postfix/ssl"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/healthcheck-postfix.sh

# Switch to root for Postfix (needs privileges for binding to ports)
USER root

# Start Postfix
CMD ["/usr/sbin/postfix", "start-fg"]