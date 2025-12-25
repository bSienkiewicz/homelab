# Systemd Service Configuration

The `homelab.service` file uses placeholders that are automatically replaced by `bootstrap/install.sh`.

## Automatic Replacement

When you run `sudo bash bootstrap/install.sh`, it automatically:
- Detects your username from `$SUDO_USER`
- Detects the repository path from the script location
- Replaces the placeholders in the service file

**You don't need to manually edit the service file.**

## Manual Values (for reference)

If you need to know what values will be used:

### Find Your Username
```bash
whoami
# or
echo $USER
```

### Find Your Group
```bash
id -gn
# or
groups
```

On Linux, your primary group is typically the same as your username.

### Find Repository Path
```bash
cd /path/to/homelab
pwd
```

Example output: `/home/username/homelab` or `/opt/homelab`

## Example

If your username is `bartek` and repo is at `/home/bartek/homelab`:

- `REPLACE_USER` → `bartek`
- `REPLACE_REPO_PATH` → `/home/bartek/homelab`
- Group → `bartek` (same as username)

## Verification

After running `bootstrap/install.sh`, you can verify the service file:

```bash
cat /etc/systemd/system/homelab.service
```

You should see the actual values, not the placeholders.

