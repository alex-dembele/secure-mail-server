-- ============================================
-- Rollback: 001 - Initial Schema
-- Description: Removes all tables created in initial migration
-- WARNING: This will delete ALL data!
-- ============================================

SET FOREIGN_KEY_CHECKS = 0;

-- Drop triggers first
DROP TRIGGER IF EXISTS `tr_users_after_insert`;
DROP TRIGGER IF EXISTS `tr_users_after_delete`;

-- Drop stored procedures
DROP PROCEDURE IF EXISTS `sp_create_user`;
DROP PROCEDURE IF EXISTS `sp_update_quota`;

-- Drop views
DROP VIEW IF EXISTS `v_quota_warnings`;
DROP VIEW IF EXISTS `v_domain_stats`;
DROP VIEW IF EXISTS `v_active_users`;

-- Drop tables (reverse order of dependencies)
DROP TABLE IF EXISTS `api_keys`;
DROP TABLE IF EXISTS `audit_log`;
DROP TABLE IF EXISTS `tls_policies`;
DROP TABLE IF EXISTS `shared_mailboxes`;
DROP TABLE IF EXISTS `user_policies`;
DROP TABLE IF EXISTS `smtp_policies`;
DROP TABLE IF EXISTS `quota_usage`;
DROP TABLE IF EXISTS `auto_replies`;
DROP TABLE IF EXISTS `forwardings`;
DROP TABLE IF EXISTS `group_members`;
DROP TABLE IF EXISTS `groups`;
DROP TABLE IF EXISTS `aliases`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `domains`;

SET FOREIGN_KEY_CHECKS = 1;

-- Remove migration record
DELETE FROM `schema_migrations` WHERE `version` = '001';

-- ============================================
-- Rollback complete
-- ============================================