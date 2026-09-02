# FnNAS AI Operating Rules

This file defines the operating rules for AI agents working on the FnNAS S922X NAS.

## 1. Scope

These rules apply to Gemini CLI, Codex, and other AI agents operating on or against FnNAS.

The authoritative host is the FnNAS S922X running Debian 12 with Docker.

## 2. Core principle

**Inspect first. Change second. Destructive actions require explicit approval.**

The agent may diagnose, read, collect status, and perform low-risk maintenance automatically. It must ask the user before any action that can delete data, interrupt an important service, expose credentials, or change the host security model.

## 3. Actions allowed automatically

The agent may perform these without asking first when necessary to complete the user's request:

### Read-only host operations

- `whoami`, `id`, `uname`, OS/version checks
- CPU, RAM, swap, disk and filesystem status
- `df`, `du` for inspection
- `ps`, `top`/`free` and process inspection
- `systemctl status`, `is-active`, `show`, and journal/log inspection
- Network/interface/route/DNS inspection
- Read configuration files that do not contain secrets
- Inspect file ownership and permissions

### Docker inspection

- `docker ps`, `docker ps -a`
- `docker images`, `docker network ls`, `docker volume ls`
- `docker inspect`
- `docker stats`
- `docker logs`
- `docker version`, `docker info`
- `docker compose config` when it is only validating configuration

### Safe test operations

- Run a temporary test container such as Alpine when explicitly needed for diagnosis.
- Pull a small public test image when needed for a permission/connectivity test.
- Remove only a temporary test container created by the agent itself for that test.

## 4. Actions requiring explicit user approval

The agent MUST ask before executing any of the following on a real FnNAS service or persistent resource:

### Containers and Docker

- `docker stop` on a real service
- `docker restart` on a real service
- `docker rm` on a real container
- `docker rmi` / deleting images
- `docker volume rm` or deleting persistent volumes
- `docker network rm`
- `docker system prune`, `docker image prune`, `docker volume prune`, or any broad cleanup
- `docker compose down` for a real stack
- `docker compose up` if it changes or recreates existing services
- Changing container environment, mounts, ports, capabilities, devices, or privileges
- Pulling/updating an image that will replace a production container

### Host and filesystem

- Deleting or moving user data
- Deleting Docker data under `/var/lib/docker`
- Changing filesystem mounts, partitions, RAID/storage configuration, or boot configuration
- Changing SSH configuration or authorized keys
- Changing firewall/security policy
- Changing users, groups, sudo rules, or permissions in a way that expands privileges
- Installing or removing system packages
- Installing, removing, or replacing Docker Engine
- Rebooting or shutting down the NAS

### Services

- Disabling or removing a systemd service
- Changing scheduled jobs/cron timers that affect backups, snapshots, monitoring, or camera recording
- Changing Cloudflare Tunnel, Telegram/ntfy notification, Frigate, backup, or snapshot behavior

## 5. Destructive-action protocol

Before a destructive or service-impacting action, the agent must:

1. State exactly what it intends to change.
2. Identify the affected container, file, volume, service, or host component.
3. Explain the expected impact briefly.
4. Ask for explicit confirmation.
5. Only proceed after confirmation.

Do not interpret vague statements such as "clean it up" or "fix it" as permission to delete or recreate persistent resources.

## 6. Docker privilege model

The normal Gemini execution path is:

`Gemini CLI -> FnNAS MCP/SSH -> admin@FnNAS -> Docker`

The `admin` account is a member of the Docker group. Docker access is therefore highly privileged and must be treated as root-equivalent for security decisions.

Do NOT add Docker socket access to the Gemini container merely to make Docker commands work.

Do NOT grant unrestricted passwordless `sudo` to the agent.

Do NOT install Docker CLI/Engine inside the Gemini container as a workaround for host access.

## 7. Secrets

Never print, commit, or expose:

- API keys
- passwords
- SSH private keys
- Cloudflare tokens
- Telegram bot tokens
- `.env` secret values
- cookies/session tokens

If a command output contains a secret, redact it before reporting or committing it.

## 8. Git and repository safety

For `fnnas-system-snapshot`:

- Never commit secrets or private keys.
- Prefer sanitized configuration and inventory.
- Do not overwrite a snapshot merely to hide an error.
- Keep operating rules and collection scripts separate from generated snapshot data.
- Before changing repository structure, inspect the existing files and preserve the established layout.

AI agents may create commits when the user has explicitly requested repository changes. The commit message must describe the actual change.

## 9. Recovery and backup principle

Before making a high-impact configuration change, verify that the relevant configuration or snapshot can be recovered.

If recovery status is unknown, stop and ask the user before proceeding with a destructive change.

## 10. User intent hierarchy

Use this order:

1. User's explicit current instruction.
2. These FnNAS operating rules.
3. Existing repository/configuration conventions.
4. Conservative, reversible behavior.

If the user's request conflicts with these rules, ask for confirmation rather than silently weakening the safety rules.

## 11. Recommended behavior

When troubleshooting:

`inspect -> identify cause -> propose fix -> ask if impact is significant -> change -> verify -> report`

When managing Docker:

`docker ps -> inspect relevant compose/config -> identify dependencies -> change only the requested service -> verify health/logs`

When uncertain whether an action is destructive, treat it as requiring approval.
