-- ============================================
-- Mailserver Database Schema
-- Version: 1.0.0
-- Description: Complete schema for mailserver
--              user management, domains, aliases,
--              quotas, and policies
-- ============================================

-- Enable strict mode and UTF8
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ============================================
-- 1. DOMAINS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `domains` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `domain` VARCHAR(255) NOT NULL UNIQUE,
  `description` VARCHAR(255) DEFAULT NULL,
  `max_users` INT UNSIGNED DEFAULT 0 COMMENT '0 = unlimited',
  `max_quota` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Total quota in bytes, 0 = unlimited',
  `max_aliases` INT UNSIGNED DEFAULT 0 COMMENT '0 = unlimited',
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `dkim_selector` VARCHAR(63) DEFAULT 'mail',
  `dkim_private_key` TEXT DEFAULT NULL,
  `dkim_public_key` TEXT DEFAULT NULL,
  `spf_policy` VARCHAR(255) DEFAULT 'v=spf1 mx ~all',
  `dmarc_policy` VARCHAR(255) DEFAULT 'v=DMARC1; p=quarantine; rua=mailto:postmaster@',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_domain` (`domain`),
  INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 2. USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `users` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `domain_id` INT UNSIGNED NOT NULL,
  `username` VARCHAR(64) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL COMMENT 'Hashed password (bcrypt/argon2)',
  `name` VARCHAR(255) DEFAULT NULL,
  `quota` BIGINT UNSIGNED DEFAULT 0 COMMENT 'Quota in bytes, 0 = unlimited',
  `quota_messages` INT UNSIGNED DEFAULT 0 COMMENT '0 = unlimited',
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `admin` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Domain admin privileges',
  `super_admin` BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Super admin privileges',
  `enable_imap` BOOLEAN NOT NULL DEFAULT TRUE,
  `enable_pop3` BOOLEAN NOT NULL DEFAULT TRUE,
  `enable_smtp` BOOLEAN NOT NULL DEFAULT TRUE,
  `smtp_rate_limit` INT UNSIGNED DEFAULT 100 COMMENT 'Messages per hour',
  `language` VARCHAR(5) DEFAULT 'en',
  `timezone` VARCHAR(50) DEFAULT 'UTC',
  `last_login` TIMESTAMP NULL DEFAULT NULL,
  `last_login_ip` VARCHAR(45) DEFAULT NULL,
  `failed_login_attempts` INT UNSIGNED DEFAULT 0,
  `locked_until` TIMESTAMP NULL DEFAULT NULL,
  `password_reset_token` VARCHAR(255) DEFAULT NULL,
  `password_reset_expires` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`domain_id`) REFERENCES `domains`(`id`) ON DELETE CASCADE,
  INDEX `idx_email` (`email`),
  INDEX `idx_domain_id` (`domain_id`),
  INDEX `idx_username` (`username`),
  INDEX `idx_active` (`active`),
  UNIQUE KEY `unique_username_domain` (`username`, `domain_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 3. ALIASES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `aliases` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `domain_id` INT UNSIGNED NOT NULL,
  `source` VARCHAR(255) NOT NULL COMMENT 'Alias email address',
  `destination` TEXT NOT NULL COMMENT 'Destination email(s), comma-separated',
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `comment` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`domain_id`) REFERENCES `domains`(`id`) ON DELETE CASCADE,
  INDEX `idx_source` (`source`),
  INDEX `idx_domain_id` (`domain_id`),
  INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 4. GROUPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `groups` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `domain_id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE COMMENT 'Group email address',
  `description` TEXT DEFAULT NULL,
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`domain_id`) REFERENCES `domains`(`id`) ON DELETE CASCADE,
  INDEX `idx_email` (`email`),
  INDEX `idx_domain_id` (`domain_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 5. GROUP MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `group_members` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `group_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `role` ENUM('member', 'moderator', 'owner') DEFAULT 'member',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`group_id`) REFERENCES `groups`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  UNIQUE KEY `unique_group_member` (`group_id`, `user_id`),
  INDEX `idx_group_id` (`group_id`),
  INDEX `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 6. FORWARDINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `forwardings` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `destination` VARCHAR(255) NOT NULL,
  `keep_copy` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Keep a copy in mailbox',
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 7. AUTO REPLY (Vacation) TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `auto_replies` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `subject` VARCHAR(255) NOT NULL,
  `body` TEXT NOT NULL,
  `active` BOOLEAN NOT NULL DEFAULT FALSE,
  `start_date` DATE DEFAULT NULL,
  `end_date` DATE DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 8. QUOTA USAGE TABLE (for tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS `quota_usage` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL UNIQUE,
  `bytes_used` BIGINT UNSIGNED DEFAULT 0,
  `messages_count` INT UNSIGNED DEFAULT 0,
  `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  INDEX `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 9. SMTP POLICIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `smtp_policies` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `policy_name` VARCHAR(64) NOT NULL UNIQUE,
  `rate_limit` INT UNSIGNED DEFAULT 100 COMMENT 'Messages per hour',
  `max_recipients` INT UNSIGNED DEFAULT 100,
  `max_message_size` INT UNSIGNED DEFAULT 25 COMMENT 'MB',
  `require_encryption` BOOLEAN DEFAULT FALSE,
  `allow_relay` BOOLEAN DEFAULT FALSE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_policy_name` (`policy_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 10. USER POLICIES (link users to policies)
-- ============================================
CREATE TABLE IF NOT EXISTS `user_policies` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `policy_id` INT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`policy_id`) REFERENCES `smtp_policies`(`id`) ON DELETE CASCADE,
  UNIQUE KEY `unique_user_policy` (`user_id`, `policy_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_policy_id` (`policy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 11. MAILBOX SHARED ACCESS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `shared_mailboxes` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `owner_user_id` INT UNSIGNED NOT NULL COMMENT 'Mailbox owner',
  `shared_with_user_id` INT UNSIGNED NOT NULL COMMENT 'User granted access',
  `permission` ENUM('read', 'write', 'delete', 'admin') DEFAULT 'read',
  `folder` VARCHAR(255) DEFAULT NULL COMMENT 'Specific folder, NULL = all',
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`owner_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`shared_with_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  UNIQUE KEY `unique_share` (`owner_user_id`, `shared_with_user_id`, `folder`),
  INDEX `idx_owner` (`owner_user_id`),
  INDEX `idx_shared_with` (`shared_with_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 12. AUDIT LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED DEFAULT NULL,
  `action` VARCHAR(64) NOT NULL COMMENT 'login, logout, create_user, delete_user, etc.',
  `resource_type` VARCHAR(64) DEFAULT NULL COMMENT 'user, domain, alias, etc.',
  `resource_id` INT UNSIGNED DEFAULT NULL,
  `details` TEXT DEFAULT NULL COMMENT 'JSON or text details',
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `user_agent` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_action` (`action`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_resource` (`resource_type`, `resource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 13. API KEYS TABLE (for API authentication)
-- ============================================
CREATE TABLE IF NOT EXISTS `api_keys` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `key_hash` VARCHAR(255) NOT NULL UNIQUE COMMENT 'Hashed API key',
  `name` VARCHAR(64) NOT NULL,
  `scopes` TEXT DEFAULT NULL COMMENT 'JSON array of allowed scopes',
  `active` BOOLEAN NOT NULL DEFAULT TRUE,
  `last_used` TIMESTAMP NULL DEFAULT NULL,
  `expires_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_key_hash` (`key_hash`),
  INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 14. TLS POLICIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tls_policies` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `domain` VARCHAR(255) NOT NULL UNIQUE,
  `policy` ENUM('none', 'may', 'encrypt', 'dane', 'dane-only', 'fingerprint', 'verify', 'secure') DEFAULT 'may',
  `params` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_domain` (`domain`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- INITIAL DEFAULT DATA
-- ============================================

-- Insert default SMTP policies
INSERT INTO `smtp_policies` (`policy_name`, `rate_limit`, `max_recipients`, `max_message_size`, `require_encryption`) VALUES
('default', 100, 100, 25, FALSE),
('strict', 50, 50, 10, TRUE),
('unlimited', 0, 0, 50, FALSE);

-- ============================================
-- VIEWS FOR CONVENIENCE
-- ============================================

-- View: Active users with domain info
CREATE OR REPLACE VIEW `v_active_users` AS
SELECT 
    u.id,
    u.email,
    u.username,
    u.name,
    d.domain,
    u.quota,
    u.active,
    u.admin,
    u.created_at
FROM users u
INNER JOIN domains d ON u.domain_id = d.id
WHERE u.active = TRUE AND d.active = TRUE;

-- View: Domain statistics
CREATE OR REPLACE VIEW `v_domain_stats` AS
SELECT 
    d.id as domain_id,
    d.domain,
    COUNT(DISTINCT u.id) as user_count,
    COUNT(DISTINCT a.id) as alias_count,
    SUM(qu.bytes_used) as total_bytes_used,
    d.max_quota,
    d.active
FROM domains d
LEFT JOIN users u ON d.id = u.domain_id AND u.active = TRUE
LEFT JOIN aliases a ON d.id = a.domain_id AND a.active = TRUE
LEFT JOIN quota_usage qu ON u.id = qu.user_id
GROUP BY d.id;

-- View: Quota warnings (users over 80%)
CREATE OR REPLACE VIEW `v_quota_warnings` AS
SELECT 
    u.id,
    u.email,
    u.quota,
    qu.bytes_used,
    ROUND((qu.bytes_used / u.quota * 100), 2) as usage_percent
FROM users u
INNER JOIN quota_usage qu ON u.id = qu.user_id
WHERE u.quota > 0 
  AND (qu.bytes_used / u.quota) >= 0.80
  AND u.active = TRUE;

-- ============================================
-- STORED PROCEDURES
-- ============================================

DELIMITER //

-- Procedure: Create user with automatic quota tracking
CREATE PROCEDURE `sp_create_user`(
    IN p_domain_id INT UNSIGNED,
    IN p_username VARCHAR(64),
    IN p_email VARCHAR(255),
    IN p_password VARCHAR(255),
    IN p_quota BIGINT UNSIGNED
)
BEGIN
    DECLARE v_user_id INT UNSIGNED;
    
    -- Insert user
    INSERT INTO users (domain_id, username, email, password, quota)
    VALUES (p_domain_id, p_username, p_email, p_password, p_quota);
    
    SET v_user_id = LAST_INSERT_ID();
    
    -- Initialize quota tracking
    INSERT INTO quota_usage (user_id, bytes_used, messages_count)
    VALUES (v_user_id, 0, 0);
    
    SELECT v_user_id as user_id;
END //

-- Procedure: Update quota usage
CREATE PROCEDURE `sp_update_quota`(
    IN p_user_id INT UNSIGNED,
    IN p_bytes_delta BIGINT,
    IN p_messages_delta INT
)
BEGIN
    INSERT INTO quota_usage (user_id, bytes_used, messages_count)
    VALUES (p_user_id, p_bytes_delta, p_messages_delta)
    ON DUPLICATE KEY UPDATE
        bytes_used = bytes_used + p_bytes_delta,
        messages_count = messages_count + p_messages_delta,
        last_updated = CURRENT_TIMESTAMP;
END //

DELIMITER ;

-- ============================================
-- TRIGGERS
-- ============================================

DELIMITER //

-- Trigger: Log user creation
CREATE TRIGGER `tr_users_after_insert`
AFTER INSERT ON `users`
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (user_id, action, resource_type, resource_id, details)
    VALUES (NEW.id, 'create_user', 'user', NEW.id, CONCAT('Created user: ', NEW.email));
END //

-- Trigger: Log user deletion
CREATE TRIGGER `tr_users_after_delete`
AFTER DELETE ON `users`
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (user_id, action, resource_type, resource_id, details)
    VALUES (OLD.id, 'delete_user', 'user', OLD.id, CONCAT('Deleted user: ', OLD.email));
END //

DELIMITER ;

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Additional composite indexes for common queries
CREATE INDEX `idx_users_domain_active` ON `users` (`domain_id`, `active`);
CREATE INDEX `idx_aliases_domain_active` ON `aliases` (`domain_id`, `active`);
CREATE INDEX `idx_audit_log_created` ON `audit_log` (`created_at` DESC);

-- ============================================
-- END OF SCHEMA
-- ============================================