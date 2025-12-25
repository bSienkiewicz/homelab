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
- **Web UI**: http://your-server:8000

Configure via the web UI after first start, or create `/srv/data/noip/config.json` manually.

### Media Stack

- **Location**: `docker/media/`
- **Services**: Prowlarr, Radarr, Sonarr, qBittorrent
- **Data**: `/srv/data/media/`
- **Media**: `/srv/media/`

## Backup

### What to Backup

- **`/srv/data/`** - All container configs and databases (critical)
- **`env/secrets.env`** - Secrets file (critical)
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
