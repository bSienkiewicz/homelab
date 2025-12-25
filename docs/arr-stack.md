# ARR Stack Setup

Complete setup guide for the media automation stack (Prowlarr, Radarr, Sonarr, qBittorrent, Jellyseerr, Bazarr, Jellyfin).

## Services Overview

- **Flaresolverr** (8191) - CloudFlare bypass proxy
- **Prowlarr** (9696) - Indexer manager
- **Radarr** (7878) - Movie management
- **Sonarr** (8989) - TV show management
- **qBittorrent** (8080) - Download client
- **Jellyseerr** (5055) - Request management
- **Bazarr** (6767) - Subtitle management
- **Jellyfin** (8096) - Media server

## Initial Setup

### 1. Start Services

```bash
./scripts/apply.sh
```

All services will be available at `http://your-server:PORT` after startup.

### 2. Configure Flaresolverr (CloudFlare Bypass)

Flaresolverr is required for indexers protected by CloudFlare (like 1337x.to).

1. Access: http://your-server:8191
2. Verify it's running (should show Flaresolverr status page)
3. No configuration needed - it's ready to use

### 3. Configure Prowlarr

1. Access: http://your-server:9696
2. Go to **Settings** → **General**
   - Set **FlareSolverr URL**: `http://flaresolverr:8191`
   - This enables CloudFlare bypass for protected indexers
3. Go to **Settings** → **Indexers**
4. Add indexers (Jackett, Prowlarr, or direct indexers)
5. For CloudFlare-protected indexers (like 1337x.to):
   - When adding the indexer, enable **Use FlareSolverr**
   - Prowlarr will automatically use Flaresolverr to bypass CloudFlare
6. Test indexers to verify they work

**Important: Configure Indexer Settings to Avoid Dead Downloads**

For each indexer, configure these settings:

1. **Categories** (Critical):
   - Go to **Settings** → **Indexers** → Select your indexer → **Categories**
   - For movie indexers: Select `2000` (Movies)
   - For TV indexers: Select `5000` (TV)
   - This filters out irrelevant content and reduces dead downloads

2. **Minimum Seeders** (Recommended):
   - In indexer settings, look for **Minimum Seeders** or **Seed Ratio**
   - Set to `1` or `2` minimum
   - Filters out completely dead torrents
   - Note: Not all indexers support this feature

3. **Indexer Priority**:
   - Set **Priority** (lower number = checked first)
   - Put reliable indexers at priority `1-10`
   - Less reliable ones at `20+`
   - Radarr/Sonarr will try indexers in priority order

4. **Test Indexers Regularly**:
   - Use **Test** button on each indexer
   - Remove or disable non-working indexers
   - Dead indexers cause failed searches and delays

5. **Sync to Radarr/Sonarr**:
   - Go to **Settings** → **Apps** → Add Radarr and Sonarr
   - Enable **Sync Indexers** checkbox
   - This automatically adds/updates indexers in Radarr/Sonarr
   - Set **Sync Categories**:
     - Radarr: `2000` (Movies only)
     - Sonarr: `5000` (TV only)

### 4. Configure qBittorrent

1. Access: http://your-server:8080
2. Default login: `admin` / `adminadmin`
3. **Change password immediately** in Settings → Web UI
4. Go to **Settings** → **Connection**
   - Set port (default 6881 is fine)
   - Enable "Use UPnP / NAT-PMP"
5. Go to **Settings** → **Downloads**
   - Set default save path: `/downloads`
   - Enable "Create subfolder" (optional)

### 5. Configure Radarr

1. Access: http://your-server:7878
2. **Settings** → **Download Clients**
   - Add qBittorrent:
     - Host: `qbittorrent`
     - Port: `8080`
     - Username: `admin` (or your changed username)
     - Password: (your qBittorrent password)
     - Category: `radarr` (optional)
3. **Settings** → **Indexers**
   - Add Prowlarr:
     - URL: `http://prowlarr:9696`
     - API Key: (from Prowlarr Settings → General → API Key)
4. **Settings** → **Media Management**
   - Root folder: `/movies`
   - Enable "Rename movies"
   - Enable "Create empty movie folders"

### 6. Configure Sonarr

1. Access: http://your-server:8989
2. **Settings** → **Download Clients**
   - Add qBittorrent (same as Radarr):
     - Host: `qbittorrent`
     - Port: `8080`
     - Category: `sonarr` (optional)
3. **Settings** → **Indexers**
   - Add Prowlarr:
     - URL: `http://prowlarr:9696`
     - API Key: (from Prowlarr)
4. **Settings** → **Media Management**
   - Root folder: `/tv`
   - Enable "Rename episodes"
   - Enable "Create empty series folders"

### 7. Configure Jellyseerr

1. Access: http://your-server:5055
2. Complete initial setup wizard:
   - Create admin account
   - Add Radarr:
     - URL: `http://radarr:7878`
     - API Key: (from Radarr Settings → General → API Key)
   - Add Sonarr:
     - URL: `http://sonarr:8989`
     - API Key: (from Sonarr Settings → General → API Key)
   - Add Jellyfin:
     - URL: `http://jellyfin:8096`
     - API Key: (from Jellyfin Dashboard → Settings → API Keys)

### 8. Configure Bazarr

1. Access: http://your-server:6767
2. **Settings** → **General**
   - Language: Select your preferred subtitle languages
3. **Settings** → **Radarr**
   - Enable Radarr
   - URL: `http://radarr:7878`
   - API Key: (from Radarr)
4. **Settings** → **Sonarr**
   - Enable Sonarr
   - URL: `http://sonarr:8989`
   - API Key: (from Sonarr)
5. **Settings** → **Subtitles**
   - Add subtitle providers (OpenSubtitles, etc.)

### 9. Configure Jellyfin

1. Access: http://your-server:8096
2. Complete initial setup wizard:
   - Create admin account
   - Add media libraries:
     - Movies: `/data/movies`
     - TV Shows: `/data/tv`
     - Music: `/data/music`
3. **Dashboard** → **Settings** → **API Keys**
   - Create API key for Jellyseerr integration

## Integration Flow

```
Jellyseerr (requests)
    ↓
Radarr/Sonarr (scheduling)
    ↓
Prowlarr (indexer search)
    ↓
qBittorrent (download)
    ↓
Radarr/Sonarr (organize/rename)
    ↓
Jellyfin (playback)
    ↓
Bazarr (subtitles)
```

## Quick Reference

**API Keys** (needed for integrations):
- Prowlarr: Settings → General → API Key
- Radarr: Settings → General → API Key
- Sonarr: Settings → General → API Key
- Jellyfin: Dashboard → Settings → API Keys

**Service URLs** (for container-to-container communication):
- Flaresolverr: `http://flaresolverr:8191`
- Prowlarr: `http://prowlarr:9696`
- Radarr: `http://radarr:7878`
- Sonarr: `http://sonarr:8989`
- qBittorrent: `http://qbittorrent:8080`
- Jellyfin: `http://jellyfin:8096`

## Troubleshooting

**Downloads not starting**:
- Verify qBittorrent credentials in Radarr/Sonarr
- Check qBittorrent is accessible: `docker compose logs qbittorrent`
- Verify download path permissions

**Indexers not working**:
- Test indexers in Prowlarr first
- Verify API key is correct in Radarr/Sonarr
- Check Prowlarr logs: `docker compose logs prowlarr`
- For CloudFlare-protected indexers:
  - Verify Flaresolverr is running: `docker compose ps flaresolverr`
  - Check Flaresolverr URL is set in Prowlarr Settings → General: `http://flaresolverr:8191`
  - Enable "Use FlareSolverr" checkbox on the indexer
  - Check Flaresolverr logs: `docker compose logs flaresolverr`

**Media not organizing**:
- Check root folder paths in Radarr/Sonarr
- Verify media management settings are enabled
- Check file permissions on `/srv/media/`

