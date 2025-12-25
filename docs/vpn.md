# Gluetun VPN Setup - Proton VPN (Free)

Simple guide to configure Gluetun with Proton VPN free tier.

## Prerequisites

- Proton VPN free account (sign up at https://protonvpn.com/free-vpn)
- Your Proton VPN OpenVPN credentials

## Quick Setup

### 1. Get Your OpenVPN Credentials

1. Log in to https://account.protonvpn.com
2. Go to **Account** → **OpenVPN / IKEv2 username**
3. Copy your OpenVPN username (format: `yourusername+1`)
4. Your password is your Proton VPN account password

### 2. Configure secrets.env

Add to `secrets.env`:

```bash
GLUETUN_VPN_PROVIDER=protonvpn
GLUETUN_VPN_TYPE=openvpn
GLUETUN_OPENVPN_USER=your_openvpn_username
GLUETUN_OPENVPN_PASSWORD=your_proton_password
```

**Important**: Use your **OpenVPN username** (not your email) and your **Proton account password**.

### 3. Optional: Select Server

Free tier servers available in: US, NL, JP, PL, RO

```bash
# Choose country (optional)
GLUETUN_SERVER_COUNTRIES=US,NL
```

If not specified, Gluetun auto-selects a free server.

### 4. Apply

```bash
./scripts/apply.sh
```

### 5. Verify

Check logs:
```bash
docker compose logs gluetun
```

Look for: `VPN is up` and `Public IP: <vpn-ip>`

## Route Container Through VPN

Add to service in `docker-compose.yml`:

```yaml
services:
  qbittorrent:
    # ... existing config ...
    network_mode: "service:gluetun"
    # Remove 'networks:' section
```

Restart:
```bash
docker compose restart gluetun qbittorrent
```

## Troubleshooting

**Won't connect**:
- Verify OpenVPN username format (`username+1`)
- Check password is correct
- Check logs: `docker compose logs gluetun`

**Free tier limits**:
- 5 countries only (US, NL, JP, PL, RO)
- 1 device connection
- No P2P/streaming support

## Resources

- [Gluetun Wiki](https://github.com/qdm12/gluetun/wiki)
- [Proton VPN Free](https://protonvpn.com/free-vpn)
