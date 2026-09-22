# 📧 Postfix MTA Service

Postfix Mail Transfer Agent (MTA) container for mailserver-k8s.

## Features

- ✅ **Virtual domains** via MySQL
- ✅ **SASL authentication** via Dovecot
- ✅ **TLS/SSL** support (STARTTLS + implicit TLS)
- ✅ **Rate limiting** and anti-abuse measures
- ✅ **Milter integration** (Rspamd, OpenDKIM)
- ✅ **Header checks** for spam/phishing
- ✅ **Multi-architecture** (amd64, arm64)
- ✅ **Health checks** and monitoring

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 25 | SMTP | Mail transfer (MTA to MTA) |
| 587 | Submission | Mail submission with STARTTLS (recommended) |
| 465 | SMTPS | Mail submission with implicit TLS (legacy) |

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOSTNAME` | `mail.example.com` | Mail server hostname |
| `PRIMARY_DOMAIN` | `example.com` | Primary domain |
| `DB_HOST` | `mysql` | Database host |
| `DB_PORT` | `3306` | Database port |
| `DB_NAME` | `mailserver` | Database name |
| `DB_USER` | `mailserver_app` | Database user |
| `DB_PASSWORD` | `changeme` | Database password |
| `MAX_MESSAGE_SIZE_MB` | `50` | Maximum message size (MB) |
| `MAX_MAILBOX_SIZE_GB` | `10` | Maximum mailbox size (GB) |
| `TLS_CERT_FILE` | `/etc/postfix/ssl/cert.pem` | TLS certificate |
| `TLS_KEY_FILE` | `/etc/postfix/ssl/key.pem` | TLS private key |
| `RELAY_HOST` | - | Relay host (optional) |
| `TRUSTED_NETWORKS` | `10.0.0.0/8...` | Trusted networks |

### Volume Mounts

- `/var/spool/postfix` - Mail queue (persistent)
- `/var/mail` - Mail storage (persistent)
- `/etc/postfix/ssl` - TLS certificates

## Building

```bash
# Build for local architecture
docker build -t mailserver/postfix:latest ./services/postfix

# Build multi-arch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t mailserver/postfix:latest \
  ./services/postfix
```

## Running

### Docker Compose

```yaml
services:
  postfix:
    image: mailserver/postfix:latest
    ports:
      - "25:25"
      - "587:587"
    environment:
      HOSTNAME: mail.example.com
      PRIMARY_DOMAIN: example.com
      DB_HOST: mysql
      DB_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mail_queue:/var/spool/postfix
      - mail_data:/var/mail
      - ./ssl:/etc/postfix/ssl:ro
    depends_on:
      - mysql
      - dovecot
```

### Docker Run

```bash
docker run -d \
  --name postfix \
  -p 25:25 \
  -p 587:587 \
  -e HOSTNAME=mail.example.com \
  -e PRIMARY_DOMAIN=example.com \
  -e DB_HOST=mysql \
  -e DB_PASSWORD=secret \
  -v postfix_queue:/var/spool/postfix \
  -v mail_data:/var/mail \
  mailserver/postfix:latest
```

## Security Features

### TLS/SSL

- **Mandatory TLS** for submission (port 587)
- **Opportunistic TLS** for SMTP (port 25)
- **Modern ciphers** only (no SSLv2, SSLv3, TLS 1.0, TLS 1.1)
- **Perfect Forward Secrecy** support

### Authentication

- SASL authentication via Dovecot
- Sender verification (prevent spoofing)
- Rate limiting per IP/user

### Anti-Spam/Abuse

- RBL checks (Spamhaus, SpamCop)
- Header checks for common spam patterns
- Milter integration (Rspamd)
- Connection rate limiting
- Greylisting support

## Monitoring

### Health Check

The container includes a comprehensive health check:

```bash
# Manual health check
docker exec postfix /usr/local/bin/healthcheck-postfix.sh
```

Checks performed:
- Postfix master process running
- SMTP port listening
- Submission port listening
- SMTP responding correctly
- Queue size monitoring

### Logs

```bash
# View logs
docker logs postfix

# Follow logs
docker logs -f postfix

# View Postfix queue
docker exec postfix postqueue -p
```

### Metrics

Postfix exposes metrics for Prometheus via postfix_exporter (separate container).

## Troubleshooting

### Check Configuration

```bash
# View active configuration
docker exec postfix postconf -n

# Test configuration
docker exec postfix postfix check
```

### Queue Management

```bash
# View queue
docker exec postfix postqueue -p

# Flush queue
docker exec postfix postqueue -f

# Delete all messages
docker exec postfix postsuper -d ALL

# Delete deferred messages
docker exec postfix postsuper -d ALL deferred
```

### Test SMTP

```bash
# Test SMTP connection
telnet localhost 25

# Test with authentication
openssl s_client -connect localhost:587 -starttls smtp
```

### Common Issues

#### Port 25 blocked by ISP

Many ISPs block outbound port 25. Use a relay host:

```bash
RELAY_HOST=smtp.sendgrid.net:587
```

#### TLS certificate errors

Generate self-signed certificate (dev only):

```bash
docker exec postfix openssl req -new -x509 -days 365 -nodes \
  -out /etc/postfix/ssl/cert.pem \
  -keyout /etc/postfix/ssl/key.pem \
  -subj "/CN=mail.example.com"
```

#### Database connection issues

Check database connectivity:

```bash
docker exec postfix nc -zv mysql 3306
```

## Integration

### Dovecot (LMTP)

Postfix delivers mail to Dovecot via LMTP:

```
virtual_transport = lmtp:dovecot:24
```

### Rspamd (Milter)

Spam filtering via Rspamd milter:

```
smtpd_milters = inet:rspamd:11332
```

### OpenDKIM (Milter)

DKIM signing via OpenDKIM milter:

```
smtpd_milters = inet:opendkim:8891
```

## Performance Tuning

### For high volume

```bash
# Increase process limits
DEFAULT_PROCESS_LIMIT=200

# Increase connection limits
SMTPD_CLIENT_CONNECTION_COUNT_LIMIT=100
```

### For low resources

```bash
# Decrease process limits
DEFAULT_PROCESS_LIMIT=50

# Increase queue run delay
# (in main.cf: queue_run_delay = 600s)
```

## References

- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Postfix Configuration](http://www.postfix.org/postconf.5.html)
- [Postfix Virtual Domains](http://www.postfix.org/VIRTUAL_README.html)
- [Postfix TLS](http://www.postfix.org/TLS_README.html)