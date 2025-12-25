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
   cp env/secrets.env.example env/secrets.env
   vim env/secrets.env  # Fill in your secrets
   ```

4. **Apply the infrastructure**:
   ```bash
   ./scripts/apply.sh
   ```

5. **Access services**:
   - Services are accessible via direct ports (e.g., `http://your-server-ip:7878` for Radarr)
   - Configure reverse proxy in `docker/nginx/conf/conf.d/` to access via domain names
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

**Check status of all containers**:
```bash
./scripts/status.sh
```

**Check status of specific stack**:
```bash
cd docker/<stack-name> && docker compose ps
```

**View logs**:
```bash
cd docker/<stack-name> && docker compose logs -f
```

## Services

### Reverse Proxy (NGINX)

- **Location**: `docker/nginx/`
- **Configuration**: File-based in `docker/nginx/conf/`
- **Data**: `/srv/data/nginx/ssl` (SSL certificates), `/srv/data/nginx/html` (static files)
- **Ports**: 80 (HTTP), 443 (HTTPS)

**Configuration**: Edit `docker/nginx/conf/conf.d/*.conf` files to add proxy hosts.

**Example configuration** (add to `docker/nginx/conf/conf.d/radarr.conf`):
```nginx
server {
    listen 80;
    server_name radarr.example.com;
    
    location / {
        proxy_pass http://radarr:7878;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

After editing config files, reload nginx:
```bash
cd docker/nginx && docker compose restart
```

### No-IP Dynamic DNS

- **Location**: `docker/noip/`
- **Data**: `/srv/data/noip/`
- **Web UI**: http://your-server:8000 (optional, for monitoring)

**Configuration**: Set the following in `env/secrets.env`:
- `NOIP_USER` - Your No-IP username
- `NOIP_PASS` - Your No-IP password (or DDNS key)
- `NOIP_HOST` - Your hostname (e.g., `example.ddns.net`)

The container will automatically update your No-IP hostname when your public IP changes.

**Troubleshooting**: If the container fails to start with "fetcher is not valid" error, delete any existing config file:
```bash
rm /srv/data/noip/config.json
```
Then restart the container to use environment variables.

### Media Stack

- **Location**: `docker/media/`
- **Services**: Prowlarr, Radarr, Sonarr, qBittorrent
- **Data**: `/srv/data/media/`
- **Media**: `/srv/media/`

**Access**: Services are accessible directly via IP:PORT:
- **Prowlarr**: http://your-server:9696
- **Radarr**: http://your-server:7878
- **Sonarr**: http://your-server:8989
- **qBittorrent**: http://your-server:8080

### Jellyfin Media Server

- **Location**: `docker/jellyfin/`
- **Data**: `/srv/data/jellyfin/`
- **Media**: Mounts from `/srv/media/` (movies, tv, music)

**Access**: http://your-server:8096

**Features**:
- Hardware acceleration enabled (via `/dev/dri` device passthrough)
- DLNA support (ports 7359/udp, 1900/udp)
- Automatically scans media directories from the media stack

### Samba

- **Location**: `docker/samba/`
- **Shares**: `/srv/smb/`

**Access**: 
- SMB/CIFS: `\\your-server-ip\smb` or `smb://your-server-ip/smb`
- Ports: 445 (SMB), 139 (NetBIOS)
- Username: `samba`
- Password: Set via `SAMBA_PASSWORD` in `env/secrets.env` (default: `samba`)

## Backup

### What to Backup

- **`/srv/data/`** - All container configs and databases (critical)
- **`env/secrets.env`** - Secrets file (critical)
- **Git repository** - Infrastructure as code
- **`/srv/smb/`** - Samba shares (backup separately as needed)

### What NOT to Backup (Disposable)

- OS
- Containers
- Images
- Docker runtime state

### Media

- Stored separately in `/srv/media/`
- Requires separate backup strategy (external drive, cloud, etc.)

## Recovery

If the OS is wiped or you're starting fresh:

1. Install Ubuntu Server LTS
2. Clone the repository
3. Run `sudo bash bootstrap/install.sh`
4. Copy `env/secrets.env` (from backup) or recreate it
5. Restore `/srv/data/` from backup
6. Run `./scripts/apply.sh`

**Time to recovery**: Minutes, not days.

## Adding New Services

1. Create a new directory: `docker/my-service/`
2. Create `docker-compose.yml` in that directory
3. Use the `proxy` network for services that need reverse proxy
4. Store persistent data in `/srv/data/my-service/`
5. Run `./scripts/apply.sh`

Example:
```yaml
services:
  my-service:
    image: my-service:latest
    networks:
      - proxy
    volumes:
      - /srv/data/my-service:/data
networks:
  proxy:
    external: true
```

## Troubleshooting

**Docker permission denied**:
- Log out and back in after bootstrap (user added to docker group)
- Or use `sudo` (not recommended for daily use)

**Service won't start**:
- Check logs: `cd docker/<service> && docker compose logs`
- Verify secrets.env is configured
- Check network exists: `docker network ls | grep proxy`

**Port conflicts**:
- Check what's using the port: `sudo netstat -tulpn | grep <port>`
- Adjust ports in docker-compose.yml if needed

**Container restarting**:
- Check logs: `cd docker/<service> && docker compose logs`
- Verify configuration files exist (e.g., `/srv/data/noip/config.json` for noip)
- Check environment variables are set correctly
- For noip: If you see "fetcher is not valid" error, delete `/srv/data/noip/config.json` to use environment variables instead

**Services not accessible via direct IP:PORT**:
- Check that ports are mapped in docker-compose.yml (format: `"7878:7878"`)
- Verify firewall allows the ports: `sudo ufw status`
- Check if port is in use: `sudo netstat -tulpn | grep <port>`
