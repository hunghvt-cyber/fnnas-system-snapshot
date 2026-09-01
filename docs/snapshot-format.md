# FnNAS Snapshot Format

The snapshot is a sanitized machine-readable representation of the FnNAS host.

## Included

- Host OS
- Kernel
- Architecture
- CPU
- Memory and swap
- Storage and mounts
- Docker version
- Docker containers
- Docker images
- Docker networks
- Docker volumes
- Docker resource usage
- Docker Compose file inventory
- Cron configuration
- Custom script inventory
- Security sanitization audit

## Excluded

The snapshot must not contain:

- Passwords
- API keys
- Access tokens
- Private keys
- `.env` contents
- Credentials
- User files
- Photos
- Videos
- Databases
- Docker overlay filesystem contents
- Container runtime data

## Design goal

The snapshot should provide enough information for an AI tool to understand:

1. What hardware and OS the NAS uses.
2. How Docker is configured.
3. Which services are running.
4. Where important configuration files live.
5. Which automation scripts exist.
6. Which parts of the system should not be modified blindly.
