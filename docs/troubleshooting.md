# Troubleshooting

When you ask for help, include the output of:

```bash
nodifyme-agent --version
systemctl status nodifyme-agent --no-pager
journalctl -u nodifyme-agent -n 50 --no-pager
sudo -u nodifyme nodifyme-agent helper-check
```

Never share the contents of `/etc/nodifyme/agent.env`: it holds this server's token.

---

## The installer stopped

| Message | What it means and what to do |
|---|---|
| `This script must be run as root` | Run it with `sudo`. |
| `Could not download verification files; refusing to install` | The server cannot reach `github.com` or `raw.githubusercontent.com`. Check DNS and any outgoing firewall. |
| `Checksum mismatch ... refusing to install` or `Signature verification failed` | The download did not match what was published. Nothing was installed. Try again; if it repeats, do not install and report it. |
| `sha256sum` / `openssl` / `curl` `is required` | Install the missing tool (Debian/Ubuntu: `sudo apt-get install -y curl openssl coreutils`). |
| `Unsupported architecture` | Builds exist for x86_64 and arm64 only. |
| `systemctl: command not found`, or the service cannot start | The server does not use systemd (common in containers). The agent needs a normal server image. |

## The server never shows as connected

1. **Is the agent running?** `systemctl status nodifyme-agent`. If it is not, `journalctl -u nodifyme-agent -n 50`.
2. **Can the server reach Nodify.Me?** `curl -sS https://YOUR-NODIFYME-URL/api/v1/internal/ping` should print `{"status":"ok"}`. If not, check DNS and the outgoing firewall on the server.
3. **Is the token current?** An install command is valid for one server, and getting a new command (or uninstalling the agent) revokes the old token. A log line such as `401` or `Unauthorized` means the token is no longer valid: get a new install command from the server's page and run it again.
4. **Wrong address?** The `API_URL` in `/etc/nodifyme/agent.env` must be the address the server can reach, not an address that only works on your own network.

## "Privileged helper did not answer" (or `helper-check` fails)

Monitoring still works; actions will not.

```bash
systemctl status nodifyme-helper.socket     # should be "active (listening)"
ls -l /run/nodifyme/helper.sock             # srw-rw---- root nodifyme
journalctl -u nodifyme-helper -n 30 --no-pager
```

The helper starts when the agent asks and stops after about a minute without a request, so `nodifyme-helper.service` being "inactive" is normal. Running the installer again repairs the units. A message about `CAP_SETUID` means the helper's service file was edited; run the installer again to restore it.

## An action failed

Actions started from the web app show their steps and, on failure, the end of the failing command's output.

- **"found N things already on this server ... Nothing was changed"**: the action stopped because something it would have to replace is already there (for example an existing Docker repository file or the `docker.io` package). The web app lists each item. Tick what may be replaced and run it again; replaced files are backed up under `/var/lib/nodifyme/backups/`.
- **"cannot continue: Port 80 is already in use (apache2)"**: another program uses the port the web server needs. Nodify.Me does not stop other programs. Stop or reconfigure it, then run the action again.
- **Waiting a long time at the package step**: right after a server is created, the system's own updates may hold the package manager. The action waits up to ten minutes for it.
- **"supports Ubuntu and Debian"**: that action is only available on those systems.
- **"is already installed; leaving it as it is"**: not an error. The software was already there and was not touched.

## Updates

The agent checks for updates every six hours. To see what the update service did: `journalctl -u nodifyme-agent-update -n 30 --no-pager`. To update now: `sudo bash update.sh` (see the README). If an update does not start, the previous version is restored automatically.

## Uninstalling

```bash
curl -fsSLO https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/uninstall.sh
sudo bash uninstall.sh
```

The server then shows as **Agent Missing** in the web app (your data there is kept). To bring it back, get a new install command from the server's page.
