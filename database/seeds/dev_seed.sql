-- ============================================
-- Development Seed Data
-- Description: Sample data for development and testing
-- WARNING: Use only in dev/test environments!
-- ============================================

-- Passwords are bcrypt hashed version of "password123"
-- Hash: $2b$10$rQ/qN3j5i5K5K5K5K5K5KeuN.9RxL/JKlqvKWqKqKqKqKqKqKqKqK (example)

-- ============================================
-- 1. SEED DOMAINS
-- ============================================
INSERT INTO `domains` (`domain`, `description`, `max_users`, `max_quota`, `active`, `dkim_selector`) VALUES
('example.com', 'Primary domain for testing', 100, 10737418240, TRUE, 'mail'),
('test.local', 'Local test domain', 50, 5368709120, TRUE, 'mail'),
('demo.org', 'Demo domain', 0, 0, TRUE, 'default');

-- ============================================
-- 2. SEED USERS
-- ============================================
-- Super admin
INSERT INTO `users` (
    `domain_id`, `username`, `email`, `password`, `name`, 
    `quota`, `active`, `admin`, `super_admin`
) VALUES (
    1, 'admin', 'admin@example.com', 
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'System Administrator', 10737418240, TRUE, TRUE, TRUE
);

-- Domain admin
INSERT INTO `users` (
    `domain_id`, `username`, `email`, `password`, `name`, 
    `quota`, `active`, `admin`
) VALUES (
    1, 'domain-admin', 'domain-admin@example.com',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'Domain Administrator', 5368709120, TRUE, TRUE
);

-- Regular users
INSERT INTO `users` (
    `domain_id`, `username`, `email`, `password`, `name`, `quota`, `active`
) VALUES
(1, 'john', 'john@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'John Doe', 2147483648, TRUE),
(1, 'jane', 'jane@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Jane Smith', 2147483648, TRUE),
(1, 'bob', 'bob@example.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Bob Johnson', 1073741824, TRUE),
(2, 'test', 'test@test.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Test User', 1073741824, TRUE),
(3, 'demo', 'demo@demo.org', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Demo User', 536870912, TRUE);

-- ============================================
-- 3. INITIALIZE QUOTA TRACKING
-- ============================================
INSERT INTO `quota_usage` (`user_id`, `bytes_used`, `messages_count`) 
SELECT `id`, 0, 0 FROM `users`;

-- ============================================
-- 4. SEED ALIASES
-- ============================================
INSERT INTO `aliases` (`domain_id`, `source`, `destination`, `active`, `comment`) VALUES
(1, 'postmaster@example.com', 'admin@example.com', TRUE, 'Standard postmaster alias'),
(1, 'abuse@example.com', 'admin@example.com', TRUE, 'Abuse reports'),
(1, 'noc@example.com', 'admin@example.com', TRUE, 'Network operations'),
(1, 'hostmaster@example.com', 'admin@example.com', TRUE, 'DNS and domain admin'),
(1, 'webmaster@example.com', 'admin@example.com', TRUE, 'Webmaster contact'),
(1, 'sales@example.com', 'john@example.com,jane@example.com', TRUE, 'Sales team distribution'),
(1, 'support@example.com', 'bob@example.com', TRUE, 'Support contact'),
(1, 'info@example.com', 'admin@example.com', TRUE, 'General information'),
(2, 'info@test.local', 'test@test.local', TRUE, 'Test info alias'),
(3, 'contact@demo.org', 'demo@demo.org', TRUE, 'Demo contact');

-- ============================================
-- 5. SEED GROUPS
-- ============================================
INSERT INTO `groups` (`domain_id`, `name`, `email`, `description`, `active`) VALUES
(1, 'All Staff', 'staff@example.com', 'All company staff members', TRUE),
(1, 'Engineering', 'engineering@example.com', 'Engineering team', TRUE),
(1, 'Management', 'management@example.com', 'Management team', TRUE);

-- ============================================
-- 6. SEED GROUP MEMBERS
-- ============================================
-- All Staff group (users 3, 4, 5 = john, jane, bob)
INSERT INTO `group_members` (`group_id`, `user_id`, `role`) VALUES
(1, 3, 'member'),
(1, 4, 'member'),
(1, 5, 'member');

-- Engineering group
INSERT INTO `group_members` (`group_id`, `user_id`, `role`) VALUES
(2, 3, 'owner'),
(2, 5, 'member');

-- Management group
INSERT INTO `group_members` (`group_id`, `user_id`, `role`) VALUES
(3, 2, 'owner'),
(3, 4, 'moderator');

-- ============================================
-- 7. SEED FORWARDINGS
-- ============================================
INSERT INTO `forwardings` (`user_id`, `destination`, `keep_copy`, `active`) VALUES
(3, 'john.doe@external.com', TRUE, FALSE),  -- Disabled example
(4, 'jane.smith@external.com', TRUE, TRUE);

-- ============================================
-- 8. SEED AUTO REPLIES (Vacation)
-- ============================================
INSERT INTO `auto_replies` (`user_id`, `subject`, `body`, `active`, `start_date`, `end_date`) VALUES
(5, 'Out of Office', 'Thank you for your email. I am currently out of office and will respond when I return.', FALSE, '2025-12-20', '2025-12-30');

-- ============================================
-- 9. SEED SMTP POLICIES (already done in schema)
-- ============================================
-- Default policies are inserted in main schema

-- ============================================
-- 10. ASSIGN POLICIES TO USERS
-- ============================================
-- Assign default policy to most users
INSERT INTO `user_policies` (`user_id`, `policy_id`) VALUES
(1, 3),  -- Admin gets unlimited
(2, 3),  -- Domain admin gets unlimited
(3, 1),  -- Regular users get default
(4, 1),
(5, 1),
(6, 1),
(7, 1);

-- ============================================
-- 11. SEED SHARED MAILBOXES
-- ============================================
INSERT INTO `shared_mailboxes` (`owner_user_id`, `shared_with_user_id`, `permission`, `active`) VALUES
(1, 2, 'admin', TRUE),    -- Admin shares with domain admin
(3, 4, 'read', TRUE),      -- John shares with Jane (read-only)
(4, 3, 'write', TRUE);     -- Jane shares with John (write access)

-- ============================================
-- 12. SEED API KEYS
-- ============================================
-- Example API key for admin (key: test-api-key-please-change)
INSERT INTO `api_keys` (`user_id`, `key_hash`, `name`, `scopes`, `active`) VALUES
(1, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 
 'Admin API Key', '["users:read", "users:write", "domains:read", "domains:write"]', TRUE),
(2, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
 'Domain Admin Key', '["users:read", "users:write"]', TRUE);

-- ============================================
-- 13. SEED AUDIT LOG (sample entries)
-- ============================================
INSERT INTO `audit_log` (`user_id`, `action`, `resource_type`, `resource_id`, `details`, `ip_address`) VALUES
(1, 'login', 'user', 1, 'Admin logged in', '192.168.1.100'),
(1, 'create_user', 'user', 3, 'Created user: john@example.com', '192.168.1.100'),
(1, 'create_user', 'user', 4, 'Created user: jane@example.com', '192.168.1.100'),
(2, 'login', 'user', 2, 'Domain admin logged in', '192.168.1.101'),
(3, 'login', 'user', 3, 'User logged in', '192.168.1.102');

-- ============================================
-- 14. SEED TLS POLICIES
-- ============================================
INSERT INTO `tls_policies` (`domain`, `policy`, `params`) VALUES
('gmail.com', 'encrypt', NULL),
('outlook.com', 'encrypt', NULL),
('yahoo.com', 'may', NULL);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify data
SELECT 'Domains count:' as info, COUNT(*) as count FROM domains;
SELECT 'Users count:' as info, COUNT(*) as count FROM users;
SELECT 'Aliases count:' as info, COUNT(*) as count FROM aliases;
SELECT 'Groups count:' as info, COUNT(*) as count FROM groups;
SELECT 'Group members count:' as info, COUNT(*) as count FROM group_members;

-- Show sample users
SELECT 
    u.email,
    u.name,
    d.domain,
    u.quota / 1073741824 as quota_gb,
    u.admin,
    u.super_admin
FROM users u
JOIN domains d ON u.domain_id = d.id
ORDER BY u.id;

-- ============================================
-- DEVELOPMENT CREDENTIALS
-- ============================================
-- 
-- Super Admin:
--   Email: admin@example.com
--   Password: password123
--
-- Domain Admin:
--   Email: domain-admin@example.com
--   Password: password123
--
-- Regular Users:
--   Email: john@example.com, jane@example.com, bob@example.com
--   Password: password123 (for all)
--
-- API Key (for testing):
--   Key: test-api-key-please-change
--   User: admin@example.com
--
-- ============================================