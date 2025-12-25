# Homelab Infrastructure

A fully replicable, disposable homelab built on Ubuntu Server with Docker Compose.
## Architecture

- **OS**: Ubuntu Server LTS
- **Orchestration**: Docker + Docker Compose
- **Pattern**: Multiple independent compose stacks (not one monolith)
- **Networking**: Shared external Docker network (`proxy`) for service communication
- **Reverse Proxy**: NGINX Proxy Manager (containerized, Web UI)
- **Data**: Persistent data in `/srv/data`, media in `/srv/media`

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

All services automatically start on boot via a systemd service installed during bootstrap. The service runs `scripts/apply.sh` which ensures all stacks are up and running.

**Manual control**:
```bash
sudo systemctl start homelab    # Start services
sudo systemctl stop homelab     # Stop services
sudo systemctl status homelab   # Check status
sudo journalctl -u homelab -f   # View logs
```

## Daily Operations

**Update and apply changes**:
```bash
git pull
./scripts/apply.sh
```

The systemd service will also auto-start everything on boot, so manual intervention is only needed for updates.

**Check status**:
```bash
cd docker/nginx && docker compose ps
cd docker/noip && docker compose ps
cd docker/media && docker compose ps
```

**View logs**:
```bash
cd docker/nginx && docker compose logs -f
```

## Services

### Reverse Proxy (NGINX)

- **Location**: `docker/nginx/`
- **Configuration**: File-based in `docker/nginx/conf/`
- **Data**: `/srv/data/nginx/ssl` (SSL certificates), `/srv/data/nginx/html` (static files)
- **Ports**: 80 (HTTP), 443 (HTTPS)

**Configuration**: Edit `docker/nginx/conf/conf.d/*.conf` files to add proxy hosts. All config is in Git for full reproducibility.

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

**Direct Port Access**: Yes! Even with NGINX running, you can still access services directly via their exposed ports (e.g., `http://your-server:7878` for Radarr). NGINX is optional for reverse proxy/domain routing - ports remain accessible.

### No-IP Dynamic DNS

- **Location**: `docker/noip/`
- **Data**: `/srv/data/noip/`
- **Web UI**: http://your-server:8000

Configure via the web UI after first start, or create `/srv/data/noip/config.json` manually.
The configuration is stored in `/srv/data/noip/`

### Media Stack

- **Location**: `docker/media/`
- **Services**: Prowlarr, Radarr, Sonarr, qBittorrent
- **Data**: `/srv/data/media/`
- **Media**: `/srv/media/`

Access via NGINX Proxy Manager after configuring proxy hosts.

## State Management

### Backed Up

- `/srv/data/` - All container configs and databases
- Git repository

### Not Backed Up (Disposable)

- OS
- Containers
- Images
- Docker runtime state

### Media

- Stored separately in `/srv/media/`
- Requires separate backup strategy (external drive, cloud, etc.)

## Recovery ("Fuck It" Recovery)

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
version: '3.8'
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

## Convergence Model

The `apply.sh` script is the convergence mechanism:

1. **git pull** - Get latest repo state
2. **./scripts/apply.sh** - Apply all compose stacks

This script:
- Loops through all compose stacks
- Runs `docker compose up -d` for each
- Destroys drift by reapplying declared state
- Manual changes are overwritten by repo state

**No Ansible, no Terraform** - just Git + Docker Compose.

## Out of Scope (For Now)

- Home Assistant
- CI/CD (but architecture allows it later)
- Monitoring
- Advanced secrets management (Vault, etc.)
- Host configuration management tools

## Mental Model

> "My homelab is a Git repo that happens to be running somewhere."

The machine is irrelevant. Reinstalling should be boring.

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

## Contributing

This is a personal homelab, but the architecture is designed to be:
- Reproducible
- Documented
- Maintainable

When adding services, follow the patterns:
- One compose file per logical service/stack
- Use the `proxy` network for web services
- Store data in `/srv/data/<service>/`
- Document in README if it's a core service

## License

Personal use. Do whatever you want.

