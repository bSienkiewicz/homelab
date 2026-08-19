# Homelab Infrastructure

A fully replicable, disposable homelab built on Ubuntu Server with Docker Compose, accessible only over Tailscale.

## Quick Start

### Initial Setup (Fresh Ubuntu Server)

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url> homelab
   cd homelab
   ```

2. **Run bootstrap** (installs Docker, Tailscale, firewall, creates directories):
   ```bash
   sudo bash bootstrap/install.sh
   ```

   **Note**: On Linux, make scripts executable:
   ```bash
   chmod +x bootstrap/*.sh scripts/*.sh
   ```

   The script will:
   - Install Docker, Tailscale, and other base tools
   - Bring up Tailscale (prints a login URL on first run - open it in a browser to authenticate)
   - Harden the firewall to Tailscale-only access **once Tailscale is confirmed connected** (see [Network Access](#network-access-tailscale) below)
   - Create `secrets.env` from `secrets.env.example` if it doesn't exist yet, and interactively prompt for a restic backup directory (default `/srv/backup/homelab`)

3. **Fill in secrets**:
   ```bash
   vim secrets.env  # Fill in SAMBA_PASSWORD and RESTIC_PASSWORD
   ```

4. **Apply the infrastructure**:
   ```bash
   ./scripts/apply.sh
   ```

5. **Access services**:
   - Services are reachable only over Tailscale, via the host's Tailscale IP/MagicDNS name (e.g. `http://<tailscale-ip>:8880` for NGINX Proxy Manager) — not the raw LAN/public IP
   - NGINX Proxy Manager: `http://<tailscale-ip>:8880` (default: `admin@example.com` / `changeme`)
   - All services will auto-start on boot via systemd

### Auto-Start on Boot

All services automatically start on boot via a systemd service installed during bootstrap.

**Manual control**:
```bash
sudo systemctl start homelab    # Start services
sudo systemctl stop homelab     # Stop services
sudo systemctl status homelab   # Check status
sudo journalctl -u homelab -f   # View logs
```

## Daily Operations

**Update repository and apply changes**:
```bash
./scripts/update.sh
```

**Check status**:
```bash
docker compose ps
# or
./scripts/status.sh
```

**View logs**:
```bash
docker compose logs -f [service-name]
```

## Repository Structure

```
homelab/
├── bootstrap/
│   ├── install.sh        # Idempotent OS bootstrap (Docker, Tailscale, firewall)
│   ├── sanity.sh         # Health checks
│   └── homelab.service   # Systemd service template
├── scripts/
│   ├── apply.sh          # Convergence script (applies repo state)
│   ├── update.sh         # Git pull + apply
│   ├── status.sh         # Check container status
│   └── backup.sh         # Restic backup of /srv/data
├── docker-compose.yml     # All services in one file
├── common.env             # Shared environment variables (committed)
├── secrets.env.example   # Secrets template
├── .gitignore
└── README.md
```

## Services

All services are defined in `docker-compose.yml`:

### Reverse Proxy
- **NGINX Proxy Manager**: Ports 80, 443, 8880 (Admin UI)
- **Data**: `/srv/data/nginx/`

### Docker Management
- **Portainer**: Port 9000
- **Data**: `/srv/data/portainer/`

### File Sharing
- **Samba**: Ports 445 (SMB), 139 (NetBIOS)
- **Shares**: `/srv/smb/`
- Username: `samba`, Password: Set via `SAMBA_PASSWORD` in `secrets.env`

### Budgeting
- **Actual Budget Server**: Port 5006
- **Data**: `/srv/data/actual-data/`

### Home Automation
- **Home Assistant**: Host networking (privileged container), UI on port 8123
- **Data**: `/srv/data/homeassistant/`

## Network Access (Tailscale)

This homelab is **Tailscale-only**: no service ports are exposed on the raw LAN or public interface, not even SSH. All access — including SSH — goes through the `tailscale0` interface.

`bootstrap/install.sh`:
- Installs Tailscale and enables persistent IP forwarding (`/etc/sysctl.d/99-homelab-tailscale.conf`), required for subnet routing.
- Runs `tailscale up --advertise-routes=<LAN CIDR> --accept-dns=false`, auto-detecting the LAN CIDR from the host's default-route interface. Override with `TAILSCALE_ADVERTISE_ROUTES=<cidr>` before running the script if auto-detection picks the wrong interface.
- On first run this is interactive: `tailscale up` prints a login URL to open in a browser. The script blocks until login completes (or times out).
- **Only once Tailscale is confirmed connected** does it reset `ufw` to: deny all incoming by default, allow all outgoing, and `allow in on tailscale0` (trusting the Tailscale interface as a whole, gated by Tailscale's own device auth/ACLs, rather than maintaining a per-service port allowlist).
- If Tailscale isn't connected yet when the script runs, firewall hardening is **skipped** with a loud warning, to avoid locking out SSH. Complete `sudo tailscale up` login, then re-run `sudo bash bootstrap/install.sh`.

**Manual step required**: advertised subnet routes must be approved in the Tailscale admin console before other tailnet devices can use them: https://login.tailscale.com/admin/machines

**Reaching the host**: once hardened, use `tailscale ip -4` (or the MagicDNS name) instead of the LAN/public IP for SSH and for all service URLs.

**Safety note**: when running `bootstrap/install.sh` on a remote box, keep a second SSH/console session open until you've confirmed you can reach the host over its Tailscale IP — the script is designed not to lock you out, but verify before closing your only session.

## Backup

### Manual Backup
```bash
./scripts/backup.sh
```

Uses [restic](https://restic.net/) to back up `/srv/data`:
- Pauses running containers, backs up `/srv/data` into the restic repository at `RESTIC_REPO` (set in `secrets.env`, chosen interactively during bootstrap - defaults to `/srv/backup/homelab`), then unpauses containers
- Tags each snapshot `homelab`
- Auto-initializes the restic repository on first run
- Enforces a retention policy: keeps the last 7 daily, 4 weekly, and 12 monthly snapshots, pruning the rest

### What to Backup
- **`/srv/data/`** - All container configs and databases (critical) - handled by `scripts/backup.sh`
- **`secrets.env`** - Secrets file (critical)
- **Git repository** - Infrastructure as code

### What NOT to Backup (Disposable)
- OS
- Containers
- Images
- Docker runtime state

### Media
- Stored separately in `/srv/media/`
- Requires separate backup strategy (external drive, cloud, etc.)

## Recovery
1. Install Ubuntu Server LTS
2. Clone the repository
3. Run `sudo bash bootstrap/install.sh`
4. Copy `secrets.env` (from backup) or recreate it, including `RESTIC_REPO`/`RESTIC_PASSWORD`
5. Restore `/srv/data/` with `restic -r <RESTIC_REPO> restore latest --target /srv/data`
6. Run `./scripts/apply.sh`


## Adding/Removing Services

Edit `docker-compose.yml` directly:
- Add a new service section
- Remove a service section
- Run `./scripts/apply.sh` to apply changes

The `--remove-orphans` flag automatically removes containers that are no longer in the compose file.

## Troubleshooting

**Docker permission denied**:
- Log out and back in after bootstrap (user added to docker group)
- Or use `sudo` (not recommended for daily use)

**Service won't start**:
- Check logs: `docker compose logs [service-name]`
- Verify `secrets.env` is configured
- Check network exists: `docker network ls | grep proxy`

**Can't reach a service**:
- Confirm Tailscale is connected: `tailscale status`
- Confirm ufw trusts `tailscale0`: `sudo ufw status`
- Use the host's Tailscale IP/MagicDNS name, not the LAN/public IP

**Port conflicts**:
- Check what's using the port: `sudo netstat -tulpn | grep <port>`
- Adjust ports in `docker-compose.yml` if needed
