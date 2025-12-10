-- ============================================
-- Migration: 001 - Initial Schema
-- Description: Creates all base tables for mailserver
-- Version: 1.0.0
-- Date: 2025-12-10
-- ============================================

-- Migration metadata table
CREATE TABLE IF NOT EXISTS `schema_migrations` (
  `version` VARCHAR(14) PRIMARY KEY,
  `description` VARCHAR(255) NOT NULL,
  `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `execution_time_ms` INT UNSIGNED DEFAULT NULL,
  INDEX `idx_applied_at` (`applied_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Record this migration
INSERT INTO `schema_migrations` (`version`, `description`) 
VALUES ('001', 'Initial schema with domains, users, aliases, groups, and policies')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- ============================================
-- Migration queries are in mailserver.sql
-- This is just the migration tracker
-- ============================================

-- To apply: source database/schemas/mailserver.sql
-- To rollback: see 001_rollback.sql