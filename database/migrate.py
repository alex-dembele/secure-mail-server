#!/usr/bin/env python3
"""
Database Migration Manager
Handles applying and rolling back database migrations
"""

import os
import sys
import time
import argparse
from pathlib import Path
from typing import List, Tuple, Optional
import mysql.connector
from mysql.connector import Error
from datetime import datetime


class MigrationManager:
    """Manages database migrations for mailserver"""

    def __init__(
        self,
        host: str = "localhost",
        port: int = 3306,
        database: str = "mailserver",
        user: str = "root",
        password: str = "",
    ):
        self.host = host
        self.port = port
        self.database = database
        self.user = user
        self.password = password
        self.connection = None
        self.migrations_dir = Path(__file__).parent / "migrations"
        self.schemas_dir = Path(__file__).parent / "schemas"

    def connect(self) -> bool:
        """Establish database connection"""
        try:
            self.connection = mysql.connector.connect(
                host=self.host,
                port=self.port,
                database=self.database,
                user=self.user,
                password=self.password,
                autocommit=False,
            )
            print(f"✓ Connected to database: {self.database}")
            return True
        except Error as e:
            print(f"✗ Database connection failed: {e}")
            return False

    def disconnect(self):
        """Close database connection"""
        if self.connection and self.connection.is_connected():
            self.connection.close()
            print("✓ Database connection closed")

    def ensure_migration_table(self):
        """Create schema_migrations table if it doesn't exist"""
        cursor = self.connection.cursor()
        try:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS `schema_migrations` (
                    `version` VARCHAR(14) PRIMARY KEY,
                    `description` VARCHAR(255) NOT NULL,
                    `applied_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    `execution_time_ms` INT UNSIGNED DEFAULT NULL,
                    INDEX `idx_applied_at` (`applied_at`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                """
            )
            self.connection.commit()
            print("✓ Migration tracking table ready")
        except Error as e:
            print(f"✗ Failed to create migration table: {e}")
            self.connection.rollback()
            raise
        finally:
            cursor.close()

    def get_applied_migrations(self) -> List[str]:
        """Get list of applied migration versions"""
        cursor = self.connection.cursor()
        try:
            cursor.execute("SELECT version FROM schema_migrations ORDER BY version")
            return [row[0] for row in cursor.fetchall()]
        except Error as e:
            print(f"✗ Failed to fetch migrations: {e}")
            return []
        finally:
            cursor.close()

    def get_pending_migrations(self) -> List[Tuple[str, Path]]:
        """Get list of pending migrations"""
        applied = set(self.get_applied_migrations())
        all_migrations = []

        for migration_file in sorted(self.migrations_dir.glob("*.sql")):
            filename = migration_file.name
            # Skip rollback files
            if "rollback" in filename.lower():
                continue

            # Extract version (e.g., "001" from "001_initial_schema.sql")
            version = filename.split("_")[0]

            if version not in applied:
                all_migrations.append((version, migration_file))

        return all_migrations

    def apply_migration(self, version: str, filepath: Path) -> bool:
        """Apply a single migration"""
        print(f"\n→ Applying migration {version}: {filepath.name}")

        cursor = self.connection.cursor()
        start_time = time.time()

        try:
            # Read migration file
            with open(filepath, "r", encoding="utf-8") as f:
                sql_content = f.read()

            # Split by semicolon and execute each statement
            statements = [
                stmt.strip()
                for stmt in sql_content.split(";")
                if stmt.strip() and not stmt.strip().startswith("--")
            ]

            for i, statement in enumerate(statements, 1):
                if statement:
                    cursor.execute(statement)
                    print(f"  [{i}/{len(statements)}] Executed statement")

            # Record migration
            execution_time = int((time.time() - start_time) * 1000)
            cursor.execute(
                """
                INSERT INTO schema_migrations (version, description, execution_time_ms)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE description = VALUES(description)
                """,
                (version, filepath.stem, execution_time),
            )

            self.connection.commit()
            print(f"✓ Migration {version} applied successfully ({execution_time}ms)")
            return True

        except Error as e:
            print(f"✗ Migration {version} failed: {e}")
            self.connection.rollback()
            return False
        finally:
            cursor.close()

    def rollback_migration(self, version: str) -> bool:
        """Rollback a migration"""
        rollback_file = self.migrations_dir / f"{version}_rollback.sql"

        if not rollback_file.exists():
            print(f"✗ Rollback file not found: {rollback_file}")
            return False

        print(f"\n→ Rolling back migration {version}")

        cursor = self.connection.cursor()
        try:
            # Read rollback file
            with open(rollback_file, "r", encoding="utf-8") as f:
                sql_content = f.read()

            # Execute rollback
            statements = [
                stmt.strip()
                for stmt in sql_content.split(";")
                if stmt.strip() and not stmt.strip().startswith("--")
            ]

            for statement in statements:
                if statement:
                    cursor.execute(statement)

            # Remove migration record
            cursor.execute(
                "DELETE FROM schema_migrations WHERE version = %s", (version,)
            )

            self.connection.commit()
            print(f"✓ Migration {version} rolled back successfully")
            return True

        except Error as e:
            print(f"✗ Rollback {version} failed: {e}")
            self.connection.rollback()
            return False
        finally:
            cursor.close()

    def migrate_up(self, target: Optional[str] = None):
        """Apply all pending migrations or up to target version"""
        pending = self.get_pending_migrations()

        if not pending:
            print("✓ No pending migrations")
            return

        if target:
            pending = [(v, p) for v, p in pending if v <= target]

        print(f"\nFound {len(pending)} pending migration(s)")

        success_count = 0
        for version, filepath in pending:
            if self.apply_migration(version, filepath):
                success_count += 1
            else:
                print(f"\n✗ Migration process stopped at {version}")
                break

        print(f"\n{'='*50}")
        print(f"Applied {success_count}/{len(pending)} migration(s)")

    def migrate_down(self, steps: int = 1):
        """Rollback last N migrations"""
        applied = self.get_applied_migrations()

        if not applied:
            print("✓ No migrations to rollback")
            return

        to_rollback = applied[-steps:]
        print(f"\nRolling back {len(to_rollback)} migration(s)")

        success_count = 0
        for version in reversed(to_rollback):
            if self.rollback_migration(version):
                success_count += 1
            else:
                print(f"\n✗ Rollback process stopped at {version}")
                break

        print(f"\n{'='*50}")
        print(f"Rolled back {success_count}/{len(to_rollback)} migration(s)")

    def status(self):
        """Show migration status"""
        applied = self.get_applied_migrations()
        pending = self.get_pending_migrations()

        print(f"\n{'='*50}")
        print(f"Database: {self.database}")
        print(f"{'='*50}")

        if applied:
            print(f"\n✓ Applied Migrations ({len(applied)}):")
            cursor = self.connection.cursor()
            cursor.execute(
                """
                SELECT version, description, applied_at, execution_time_ms 
                FROM schema_migrations 
                ORDER BY version
                """
            )
            for row in cursor.fetchall():
                print(
                    f"  [{row[0]}] {row[1]} "
                    f"(applied: {row[2]}, time: {row[3]}ms)"
                )
            cursor.close()
        else:
            print("\n✗ No applied migrations")

        if pending:
            print(f"\n⚠ Pending Migrations ({len(pending)}):")
            for version, filepath in pending:
                print(f"  [{version}] {filepath.name}")
        else:
            print("\n✓ No pending migrations")

        print(f"\n{'='*50}")

    def reset(self, confirm: bool = False):
        """Drop all tables and reset database"""
        if not confirm:
            print("\n⚠ WARNING: This will delete ALL data!")
            response = input("Type 'YES' to confirm: ")
            if response != "YES":
                print("✗ Reset cancelled")
                return

        print("\n→ Resetting database...")

        cursor = self.connection.cursor()
        try:
            # Disable foreign key checks
            cursor.execute("SET FOREIGN_KEY_CHECKS = 0")

            # Get all tables
            cursor.execute("SHOW TABLES")
            tables = [row[0] for row in cursor.fetchall()]

            # Drop all tables
            for table in tables:
                cursor.execute(f"DROP TABLE IF EXISTS `{table}`")
                print(f"  Dropped table: {table}")

            # Re-enable foreign key checks
            cursor.execute("SET FOREIGN_KEY_CHECKS = 1")

            self.connection.commit()
            print("✓ Database reset complete")

        except Error as e:
            print(f"✗ Reset failed: {e}")
            self.connection.rollback()
        finally:
            cursor.close()


def main():
    parser = argparse.ArgumentParser(description="Database Migration Manager")
    parser.add_argument("--host", default="localhost", help="Database host")
    parser.add_argument("--port", type=int, default=3306, help="Database port")
    parser.add_argument("--database", default="mailserver", help="Database name")
    parser.add_argument("--user", default="root", help="Database user")
    parser.add_argument(
        "--password", default="", help="Database password (use env var DB_PASSWORD)"
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Status command
    subparsers.add_parser("status", help="Show migration status")

    # Up command
    up_parser = subparsers.add_parser("up", help="Apply pending migrations")
    up_parser.add_argument("--target", help="Target version to migrate to")

    # Down command
    down_parser = subparsers.add_parser("down", help="Rollback migrations")
    down_parser.add_argument(
        "--steps", type=int, default=1, help="Number of migrations to rollback"
    )

    # Reset command
    reset_parser = subparsers.add_parser("reset", help="Reset database (DESTRUCTIVE)")
    reset_parser.add_argument("--confirm", action="store_true", help="Skip confirmation")

    args = parser.parse_args()

    # Use environment variable for password if not provided
    password = args.password or os.getenv("DB_PASSWORD", "")

    # Create manager
    manager = MigrationManager(
        host=args.host,
        port=args.port,
        database=args.database,
        user=args.user,
        password=password,
    )

    # Connect to database
    if not manager.connect():
        sys.exit(1)

    try:
        # Ensure migration table exists
        manager.ensure_migration_table()

        # Execute command
        if args.command == "status":
            manager.status()
        elif args.command == "up":
            manager.migrate_up(target=args.target)
        elif args.command == "down":
            manager.migrate_down(steps=args.steps)
        elif args.command == "reset":
            manager.reset(confirm=args.confirm)
        else:
            parser.print_help()

    finally:
        manager.disconnect()


if __name__ == "__main__":
    main()