# Snapshot Repository Operating Rules

This file supplements the Global `GEMINI.md` with rules specific to the FnNAS system snapshot repository.

## 1. Snapshot Structure & Integrity
- **Authoritative Data**: The `snapshots/latest/` directory contains the most recent sanitized system state.
- **Integrity**: Never overwrite a snapshot merely to hide an error or a failed collection.
- **History**: Maintain the established directory layout and file naming conventions.

## 2. Sanitization & Security
- **Mandatory Sanitization**: Before committing generated data, inspect it for secrets (passwords, tokens, keys).
- **Redaction**: Secret `.env` values, private keys, and session cookies must be redacted or excluded.
- **Scope**: Keep collection scripts (`scripts/`) separate from generated data (`snapshots/`).

## 3. Data Safety
- Do not commit raw credential files or session tokens.
- Prefer deterministic, text-based output for system inventories.
- Verify that a snapshot is successful and readable before considering a collection task complete.

## 4. Discovery
- Refer to `docs/snapshot-format.md` for detailed file schemas.
- Refer to `AGENTS.md` for repository scope and agent instructions.
