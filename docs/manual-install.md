# Installing the agent yourself

Use this when you prefer to run the installer on the server yourself, or when the web app's automatic install could not finish. The web app creates the command for you and shows it with a copy button.

## 1. Get your install command

In the Nodify.Me web app, open the server (add it first with *I will install it myself* if it is new) and choose **Get install command**. The command contains a token that belongs to this one server. Getting a new command replaces the previous token, so an agent installed with an older command stops connecting.

## 2. Check the server

The installer needs:

- root, or `sudo`
- systemd
- `curl`, `openssl`, `sha256sum`
- outgoing HTTPS to `github.com`, `raw.githubusercontent.com` and your Nodify.Me URL

A quick test from the server:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://YOUR-NODIFYME-URL/api/v1/internal/ping   # 200
curl -sS -o /dev/null -w "%{http_code}\n" https://github.com                              # 200
```

On Debian or Ubuntu, missing tools can be installed with `sudo apt-get install -y curl openssl coreutils`.

## 3. Run it

```bash
curl -fsSL https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh | \
  sudo bash -s -- --api-url https://YOUR-NODIFYME-URL --token YOUR-AGENT-TOKEN
```

Prefer to read it first? Download it, look at it, then run it:

```bash
curl -fsSLO https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh
less install.sh
sudo bash install.sh --api-url https://YOUR-NODIFYME-URL --token YOUR-AGENT-TOKEN
```

Options:

| Option | Meaning |
|---|---|
| `--api-url URL` | Your Nodify.Me address (required) |
| `--token TOKEN` | This server's token (required, at least 16 characters) |
| `--version vX.Y.Z` | Install a specific release instead of the latest |

## 4. What the installer does

1. Downloads the agent for your CPU and **verifies its SHA-256 checksum and RSA signature**. It stops if either check fails.
2. Creates the `nodifyme` user, the folders, and the settings file `/etc/nodifyme/agent.env`.
3. Installs and starts the agent service, the update service, and the privileged helper's socket.
4. Checks that the agent and the helper answer. A failure to reach the helper is a warning (monitoring still works, actions do not).

The installer can be run again at any time on the same server; it replaces the agent and keeps your settings.

## 5. Check that it worked

```bash
systemctl status nodifyme-agent
sudo -u nodifyme nodifyme-agent helper-check
```

Within a minute the server shows as connected in the web app. If it does not, see [troubleshooting.md](troubleshooting.md).
