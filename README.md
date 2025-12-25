# Homelab Infrastructure

A fully replicable, disposable homelab built on Ubuntu Server with Docker Compose.

## Quick Start

### Initial Setup (Fresh Ubuntu Server)

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url> homelab
   cd homelab
   ```

2. **Run bootstrap** (installs Docker, firewall, creates directories):
   ```bash
   sudo bash bootstrap/install.sh
   ```
   
   **Note**: On Linux, make scripts executable:
   ```bash
   chmod +x bootstrap/*.sh scripts/*.sh
   ```

3. **Configure secrets**:
   ```bash
   cp secrets.env.example secrets.env
   vim secrets.env  # Fill in your secrets
   ```

4. **Apply the infrastructure**:
   ```bash
   ./scripts/apply.sh
   ```

5. **Access services**:
   - Services are accessible via direct ports (e.g., `http://your-server-ip:7878` for Radarr)
   - NGINX Proxy Manager: http://your-server-ip:8880 (default: `admin@example.com` / `changeme`)
   - All services will auto-start on boot via systemd service

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
│   ├── install.sh        # Idempotent OS bootstrap
│   ├── sanity.sh         # Health checks
│   └── homelab.service   # Systemd service template
├── scripts/
│   ├── apply.sh          # Convergence script (applies repo state)
│   ├── update.sh         # Git pull + apply
│   └── status.sh         # Check container status
├── docker-compose.yml     # All services in one file
├── common.env            # Shared environment variables (committed)
├── secrets.env.example   # Secrets template
├── .gitignore
└── README.md
```

## Services

All services are defined in `docker-compose.yml`:

### Reverse Proxy
- **NGINX Proxy Manager**: Ports 80, 443, 8880 (Admin UI)
- **Data**: `/srv/data/nginx/`

### Dynamic DNS
- **No-IP**: Port 8008 (Web UI)
- **Data**: `/srv/data/noip/`
- Configure via web UI at http://your-server:8008

### Docker Management
- **Portainer**: Port 9000
- **Data**: `/srv/data/portainer/`

### File Sharing
- **Samba**: Ports 445 (SMB), 139 (NetBIOS)
- **Shares**: `/srv/smb/`
- Username: `samba`, Password: Set via `SAMBA_PASSWORD` in `secrets.env`

### VPN Client
- **Gluetun**: Ports 8888 (HTTP proxy), 8388 (Shadowsocks)
- **Data**: `/srv/data/gluetun/`
- Configure VPN provider in `secrets.env`

### Media Stack
- **Prowlarr**: Port 9696 (Indexer manager)
- **Radarr**: Port 7878 (Movies)
- **Sonarr**: Port 8989 (TV Shows)
- **qBittorrent**: Port 8080 (Downloader)
- **Jellyseerr**: Port 5055 (Request management)
- **Bazarr**: Port 6767 (Subtitles)
- **Jellyfin**: Port 8096 (Media server)
- **Data**: `/srv/data/media/` and `/srv/data/jellyfin/`
- **Media**: `/srv/media/`

## Backup

### Manual Backup
```bash
./scripts/backup.sh
```

Creates a backup archive in `/srv/backup/`:
- Format: `backup_<branch>_<commit>_<timestamp>.tar.gz`
- Contains: `/srv/data/` (all container configs and databases)
- Keeps last 10 backups automatically

### What to Backup
- **`/srv/data/`** - All container configs and databases (critical)
- **`secrets.env`** - Secrets file (critical)
- **Git repository** - Infrastructure as code
- **`/srv/backup/`** - Backup archives (optional, can be regenerated)

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
4. Copy `secrets.env` (from backup) or recreate it
5. Restore `/srv/data/` from backup
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

**Port conflicts**:
- Check what's using the port: `sudo netstat -tulpn | grep <port>`
- Adjust ports in `docker-compose.yml` if needed
