# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-03-20

### Added
- PostgreSQL backend with full schema browsing, TLS support, and type decoders
- MySQL backend with multi-database support and TLS fallback
- MariaDB backend
- SQLite backend (file-based, no external dependency)
- MongoDB backend with shell-style commands and document schema inference
- Redis backend with command-based execution and dynamic type discovery
- ScyllaDB backend (CQL)
- Cassandra backend (CQL)
- Elasticsearch backend with REST-style query execution
- Sidebar tree for browsing databases, schemas, tables, views, indexes, and keys
- Inline row editing with SQL/CQL preview before commit
- Query editor with syntax highlighting for keywords, strings, numbers, and comments
- SQL/CQL autocomplete engine with schema-aware completions
- Multiple tabs with independent connections (Cmd+T)
- Connection environments (local, dev, staging, production)
- SSH tunneling with password and private key authentication
- Session persistence and restore across app relaunches
- Encrypted credential storage via macOS Keychain
- Color-coded connection indicators
- Connection tooltips
- Context menu actions for creating and dropping database objects
- Data pagination with sorting
- Table structure tab showing columns, indexes, and triggers
- Refresh action (Cmd+R)
- GitHub Actions CI (build + test on macOS 15)
- GitHub Actions release workflow (DMG + ZIP on tag push)
- Unit tests for completion engine, SQL generation, highlighter, query state, and table state
- Contributing guide
- Security policy
- Issue templates for bug reports and feature requests
- Pull request template
- Code of Conduct

### Fixed
- Enable TLS for PostgreSQL connections (cloud-hosted databases now work)
- Completion engine cursor boundary off-by-one
- Replace precondition with guard in SQL generation
- Improve PostgreSQL error handling and connection lifecycle
- Use atomic writes and error logging in stores
- Remove force unwrap in SSH tunnel connection flow
