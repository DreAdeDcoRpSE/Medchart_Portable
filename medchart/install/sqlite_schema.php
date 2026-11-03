<?php
// SQLite-only fresh installation schema. Never run on an existing MariaDB data directory.
return [
"CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT, is_admin INTEGER DEFAULT 0, is_approved INTEGER NOT NULL DEFAULT 1, must_change_password INTEGER NOT NULL DEFAULT 0, email TEXT)",
"CREATE TABLE allergy_list (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, allergy TEXT, sort_order INTEGER)",
"CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)",
"CREATE TABLE login_attempts (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL, ip_address TEXT NOT NULL, attempted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
"CREATE INDEX ix_account_time ON login_attempts(username,attempted_at)",
"CREATE INDEX ix_ip_time ON login_attempts(ip_address,attempted_at)",
"CREATE TABLE medical_data (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, dob TEXT, notes TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, name TEXT DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)",
"CREATE INDEX ix_medical_data_user ON medical_data(user_id)",
"CREATE TRIGGER medical_data_updated AFTER UPDATE ON medical_data FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at BEGIN UPDATE medical_data SET updated_at=CURRENT_TIMESTAMP WHERE id=NEW.id; END",
"CREATE TABLE medical_team (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, role TEXT, sort_order INTEGER, phone TEXT DEFAULT '')",
"CREATE TABLE medications (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, name TEXT, is_active INTEGER DEFAULT 1, sort_order INTEGER, dose TEXT DEFAULT '', frequency TEXT DEFAULT '')",
"CREATE TABLE password_reset_tokens (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, token_hash TEXT NOT NULL UNIQUE, expires_at TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
"CREATE INDEX ix_user_created ON password_reset_tokens(user_id,created_at)",
"CREATE TABLE security_events (id INTEGER PRIMARY KEY AUTOINCREMENT, event_type TEXT NOT NULL, username TEXT NOT NULL DEFAULT '', ip_address TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)",
"CREATE INDEX ix_created ON security_events(created_at)"
];
