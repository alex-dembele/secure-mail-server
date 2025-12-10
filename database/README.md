# 📊 Database Schema Documentation

## Overview

The mailserver database uses MySQL/MariaDB with a normalized relational schema designed for performance, scalability, and data integrity.

## Quick Start

```bash
# Create database
mysql -u root -p -e "CREATE DATABASE mailserver CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Apply schema
mysql -u root -p mailserver < database/schemas/mailserver.sql

# Apply migrations
mysql -u root -p mailserver < database/migrations/001_initial_schema.sql

# Load development data (optional)
mysql -u root -p mailserver < database/seeds/dev_seed.sql
```

## Schema Version

**Current Version**: 1.0.0  
**Last Updated**: 2025-12-10

## Entity Relationship Diagram

```
┌─────────────┐         ┌──────────────┐
│   domains   │────────<│    users     │
└─────────────┘         └──────────────┘
      │                       │
      │                       ├─────────┬────────────┬──────────────┐
      │                       │         │            │              │
      ▼                       ▼         ▼            ▼              ▼
┌─────────────┐      ┌────────────┐  ┌──────────┐ ┌────────────┐ ┌─────────────┐
│   aliases   │      │quota_usage │  │forwardings││auto_replies│ │shared_mailbox│
└─────────────┘      └────────────┘  └──────────┘ └────────────┘ └─────────────┘
      │
      ▼
┌─────────────┐         ┌──────────────┐
│   groups    │────────<│group_members │
└─────────────┘         └──────────────┘
                              │
                              ▼
                        ┌──────────────┐
                        │    users     │
                        └──────────────┘
```

## Core Tables

### 1. domains

Stores email domains managed by the system.

| Column | Type | Description |
|--------|------|-------------|
| id | INT UNSIGNED | Primary key |
| domain | VARCHAR(255) | Domain name (unique) |
| description | VARCHAR(255) | Optional description |
| max_users | INT UNSIGNED | Maximum users (0 = unlimited) |
| max_quota | BIGINT UNSIGNED | Total quota in bytes |
| active | BOOLEAN | Domain active status |
| dkim_selector | VARCHAR(63) | DKIM selector |
| dkim_private_key | TEXT | DKIM private key |
| dkim_public_key | TEXT | DKIM public key |
| spf_policy | VARCHAR(255) | SPF record |
| dmarc_policy | VARCHAR(255) | DMARC policy |

**Indexes**: domain, active

### 2. users

Email user accounts.

| Column | Type | Description |
|--------|------|-------------|
| id | INT UNSIGNED | Primary key |
| domain_id | INT UNSIGNED | Foreign key to domains |
| username | VARCHAR(64) | Username part |
| email | VARCHAR(255) | Full email (unique) |
| password | VARCHAR(255) | Hashed password |
| name | VARCHAR(255) | Full name |
| quota | BIGINT UNSIGNED | Mailbox quota in bytes |
| quota_messages | INT UNSIGNED | Message count limit |
| active | BOOLEAN | Account active |
| admin | BOOLEAN | Domain admin privileges |
| super_admin | BOOLEAN | Super admin privileges |
| enable_imap | BOOLEAN | IMAP access |
| enable_pop3 | BOOLEAN | POP3 access |
| enable_smtp | BOOLEAN | SMTP access |
| smtp_rate_limit | INT UNSIGNED | Messages per hour |
| last_login | TIMESTAMP | Last login time |
| last_login_ip | VARCHAR(45) | Last login IP |

**Indexes**: email, domain_id, username, active, (username, domain_id)

**Security Features**:
- Failed login attempt tracking
- Account lockout mechanism
- Password reset tokens
- Session management

### 3. aliases

Email aliases and forwarders.

| Column | Type | Description |
|--------|------|-------------|
| id | INT UNSIGNED | Primary key |
| domain_id | INT UNSIGNED | Foreign key to domains |
| source | VARCHAR(255) | Alias email |
| destination | TEXT | Target email(s), comma-separated |
| active | BOOLEAN | Alias active |
| comment | VARCHAR(255) | Optional description |

**Indexes**: source, domain_id, active

**Usage Examples**:
- `postmaster@example.com` → `admin@example.com`
- `sales@example.com` → `john@example.com,jane@example.com`

### 4. groups

Email distribution groups.

| Column | Type | Description |
|--------|------|-------------|
| id | INT UNSIGNED | Primary key |
| domain_id | INT UNSIGNED | Foreign key to domains |
| name | VARCHAR(255) | Group name |
| email | VARCHAR(255) | Group email (unique) |
| description | TEXT | Optional description |
| active | BOOLEAN | Group active |

**Related**: group_members (many-to-many with users)

### 5. quota_usage

Tracks actual mailbox usage.

| Column | Type | Description |
|--------|------|-------------|
| id | INT UNSIGNED | Primary key |
| user_id | INT UNSIGNED | Foreign key to users (unique) |
| bytes_used | BIGINT UNSIGNED | Bytes consumed |
| messages_count | INT UNSIGNED | Number of messages |
| last_updated | TIMESTAMP | Last update time |

**Updates**: Automatically via triggers and stored procedures

### 6. smtp_policies

SMTP sending policies.

| Column | Type | Description |
|--------|------|-------------|
| id | INT UNSIGNED | Primary key |
| policy_name | VARCHAR(64) | Policy identifier |
| rate_limit | INT UNSIGNED | Messages per hour |
| max_recipients | INT UNSIGNED | Max recipients per message |
| max_message_size | INT UNSIGNED | Max size in MB |
| require_encryption | BOOLEAN | TLS required |
| allow_relay | BOOLEAN | Allow relaying |

**Default Policies**:
- `default`: 100 msg/hr, 100 recipients, 25MB
- `strict`: 50 msg/hr, 50 recipients, 10MB, TLS required
- `unlimited`: No limits (for admin use)

## Supporting Tables

### forwardings
User-level email forwarding rules.

### auto_replies
Vacation/out-of-office auto-responders.

### shared_mailboxes
Delegated mailbox access (read/write/delete/admin permissions).

### api_keys
API authentication tokens with scopes.

### audit_log
Complete audit trail of system actions.

### tls_policies
Per-domain TLS enforcement policies.

## Views

### v_active_users
Active users with domain information.

```sql
SELECT * FROM v_active_users WHERE domain = 'example.com';
```

### v_domain_stats
Aggregated domain statistics.

```sql
SELECT * FROM v_domain_stats ORDER BY user_count DESC;
```

### v_quota_warnings
Users exceeding 80% quota usage.

```sql
SELECT * FROM v_quota_warnings;
```

## Stored Procedures

### sp_create_user
Creates a user with automatic quota tracking initialization.

```sql
CALL sp_create_user(
    1,                    -- domain_id
    'newuser',            -- username
    'newuser@example.com', -- email
    '$2y$10$...',         -- password hash
    2147483648            -- quota (2GB)
);
```

### sp_update_quota
Updates quota usage atomically.

```sql
CALL sp_update_quota(
    1,          -- user_id
    1048576,    -- bytes_delta (1MB added)
    1           -- messages_delta (1 message added)
);
```

## Triggers

### tr_users_after_insert
Logs user creation to audit_log.

### tr_users_after_delete
Logs user deletion to audit_log.

## Indexes Strategy

- **Primary keys**: Auto-increment INT UNSIGNED
- **Foreign keys**: Indexed for JOIN performance
- **Frequently queried columns**: email, domain, active status
- **Composite indexes**: (domain_id, active) for filtered queries
- **Text search**: Consider full-text indexes for future search features

## Performance Considerations

### Query Optimization
- Use prepared statements to prevent SQL injection
- Leverage indexes on WHERE clauses
- Use LIMIT for pagination
- Consider caching frequently accessed data (Redis)

### Storage
- UTF8MB4 for full Unicode support (emoji in names)
- InnoDB engine for ACID compliance
- Row-level locking for concurrency

### Scaling
- **Read replicas**: For read-heavy workloads
- **Partitioning**: By domain_id for large installations
- **Archiving**: Move old audit_log entries to archive table

## Backup Strategy

### Full Backup
```bash
mysqldump -u root -p \
  --single-transaction \
  --routines \
  --triggers \
  mailserver > backup_full_$(date +%Y%m%d).sql
```

### Incremental Backup
```bash
# Enable binary logging in my.cnf
# Then use mysqlbinlog for point-in-time recovery
```

### Restore
```bash
mysql -u root -p mailserver < backup_full_20251210.sql
```

## Migration Management

Migrations are numbered sequentially: `001_initial_schema.sql`, `002_add_column.sql`, etc.

### Apply Migration
```bash
mysql -u root -p mailserver < database/migrations/002_add_feature.sql
```

### Rollback Migration
```bash
mysql -u root -p mailserver < database/migrations/002_rollback.sql
```

### Check Applied Migrations
```sql
SELECT * FROM schema_migrations ORDER BY version;
```

## Security Best Practices

1. **Password Hashing**: Use bcrypt or Argon2
2. **SQL Injection**: Always use prepared statements
3. **Least Privilege**: Grant minimal required permissions
4. **Encryption**: Encrypt DKIM keys at rest
5. **Audit**: Enable query logging for production
6. **Backups**: Encrypt backup files
7. **Network**: Use TLS for database connections

## Database Users

### Application User
```sql
CREATE USER 'mailserver_app'@'%' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON mailserver.* TO 'mailserver_app'@'%';
FLUSH PRIVILEGES;
```

### Admin User
```sql
CREATE USER 'mailserver_admin'@'localhost' IDENTIFIED BY 'admin_password';
GRANT ALL PRIVILEGES ON mailserver.* TO 'mailserver_admin'@'localhost';
FLUSH PRIVILEGES;
```

### Read-Only User (for monitoring)
```sql
CREATE USER 'mailserver_ro'@'%' IDENTIFIED BY 'readonly_password';
GRANT SELECT ON mailserver.* TO 'mailserver_ro'@'%';
FLUSH PRIVILEGES;
```

## Monitoring Queries

### Check quota usage
```sql
SELECT 
    u.email,
    u.quota / 1073741824 as quota_gb,
    qu.bytes_used / 1073741824 as used_gb,
    ROUND((qu.bytes_used / u.quota * 100), 2) as usage_percent
FROM users u
JOIN quota_usage qu ON u.id = qu.user_id
WHERE u.quota > 0
ORDER BY usage_percent DESC;
```

### Active sessions
```sql
SELECT * FROM audit_log 
WHERE action = 'login' 
AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR);
```

### Domain statistics
```sql
SELECT * FROM v_domain_stats;
```

## Troubleshooting

### Slow Queries
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;

-- Check slow queries
SHOW FULL PROCESSLIST;
```

### Lock Issues
```sql
SHOW ENGINE INNODB STATUS\G
```

### Table Size
```sql
SELECT 
    table_name,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
FROM information_schema.tables
WHERE table_schema = 'mailserver'
ORDER BY size_mb DESC;
```

## Future Enhancements

- [ ] Add full-text search indexes
- [ ] Implement table partitioning for large deployments
- [ ] Add support for LDAP/AD synchronization tables
- [ ] Create materialized views for analytics
- [ ] Add support for multi-language content
- [ ] Implement data retention policies

## References

- [MySQL 8.0 Reference](https://dev.mysql.com/doc/refman/8.0/en/)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [Database Design Best Practices](https://www.postgresql.org/docs/current/ddl.html)