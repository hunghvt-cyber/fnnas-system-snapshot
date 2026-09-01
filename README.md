# FnNAS System Snapshot

Sanitized system inventory and configuration snapshot for FnNAS.

## Purpose

This repository provides a machine-readable snapshot of the FnNAS host for system administration, troubleshooting, Gemini CLI, Codex, and automation.

## Principles

- Snapshot system state, not user data.
- Never store passwords, API keys, tokens, private keys, or other secrets.
- Prefer deterministic text-based output.
- Keep generated snapshots separate from collection scripts.
- Keep the repository safe for AI tooling.

## Snapshot contents

- Host OS, kernel, CPU, RAM and swap
- Storage, filesystems and mounts
- Docker version, containers, images, networks and volumes
- Docker Compose files
- System cron and custom scripts
- Cloudflare, Telegram and Gemini integration structure
- Snapshot metadata
