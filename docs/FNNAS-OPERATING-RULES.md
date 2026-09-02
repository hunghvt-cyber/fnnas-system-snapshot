# FnNAS Operating Rules

Version: 1.0

This document is the detailed operational policy referenced by `AGENTS.md`.

## Permission levels

| Level | Meaning | Examples |
|---|---|---|
| L0 | Read-only | status, logs, inspect, disk/RAM/network checks |
| L1 | Reversible/sandbox | temporary test container, temporary diagnostics |
| L2 | Service-impacting | restart/stop/remove/recreate a real service |
| L3 | Destructive/host-security | delete persistent data, change sudo/SSH, storage, Docker Engine, reboot |

**L0 and L1 may be automatic. L2 and L3 require explicit confirmation.**

## Automatic operations

The agent can automatically:

- inspect the host and Docker state;
- read non-secret configuration;
- inspect logs and service status;
- validate Compose configuration without applying it;
- inspect container mounts, ports, networks and health;
- create and remove its own temporary test container;
- test SSH and Docker connectivity;
- collect a sanitized snapshot;
- run non-destructive Git operations such as status/diff/log.

## Confirmation required

Ask first before:

- stopping/restarting/removing an existing service;
- recreating a container;
- changing a Compose file and applying it;
- updating a production image/container;
- deleting an image, volume, network, backup, snapshot, or user data;
- pruning Docker resources;
- changing persistent mounts or permissions;
- changing SSH, sudo, firewall, users, groups, or security settings;
- installing/removing packages;
- installing/removing/upgrading Docker Engine;
- rebooting/shutting down;
- changing backup, snapshot, Frigate, Cloudflare, notification, or monitoring behavior.

## Special rule for Docker updates

Never run an update workflow blindly.

Before updating a real container:

1. Inspect its current Compose definition.
2. Identify persistent volumes and bind mounts.
3. Check whether a backup/snapshot exists when relevant.
4. Tell the user which image/service will change.
5. Ask for confirmation.
6. Apply the smallest possible change.
7. Verify the container, logs, ports, and dependent services.

## Special rule for deletion

A deletion command is not considered safe merely because Docker accepts it.

For any persistent resource, identify exactly what will be deleted and obtain confirmation.

Broad commands such as these always require confirmation:

- `docker system prune`
- `docker volume prune`
- `docker image prune`
- `docker container prune`
- `docker network prune`
- recursive filesystem deletion

## Snapshot repository rules

The repository is a sanitized operational record, not a secrets store.

Never commit:

- private keys;
- API keys;
- passwords;
- access tokens;
- session cookies;
- secret `.env` values;
- raw credential files.

Before committing generated data, inspect it for secrets.

## MCP and SSH rules

Preferred path:

`Gemini -> FnNAS MCP -> SSH -> admin@FnNAS -> Docker/system tools`

The Gemini container does not need the host Docker socket.

The agent must not bypass MCP/SSH controls by introducing a second privileged access path unless explicitly requested and approved.

## Reporting

After every applied change, report:

- what changed;
- where it changed;
- the command/action category used;
- verification result;
- any remaining warning or follow-up.

Keep reports concise and do not include secrets.
