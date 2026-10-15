# Nodify.Me Agent

The Nodify.Me agent is a small program that runs on your server and connects it to your [Nodify.Me](https://nodifyme.app) account. It reports how the server is doing, and it carries out the actions you start in the web app. On its own it does nothing useful: it needs a Nodify.Me account.

See [CHANGELOG.md](CHANGELOG.md) for what changed in each release.

---

## Install

**Recommended: from the Nodify.Me web app.** Choose *Add a server*, enter the server's IP address and login, and let the app check the server and install the agent. The app shows everything it finds and every step as it happens. Your login is used once for the install.

**Or install it yourself.** In the web app choose *I will install it myself* (or *Get install command* on a server's page). It shows a command like this; run it on the server as root:

```bash
curl -fsSL https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh | \
  sudo bash -s -- --api-url https://YOUR-NODIFYME-URL --token YOUR-AGENT-TOKEN
```

The token belongs to one server. A new install command replaces the old token. More detail: [docs/manual-install.md](docs/manual-install.md).

### Requirements

- Linux with **systemd**, `curl`, `openssl` and `sha256sum`; root or `sudo` for the install.
- Outgoing HTTPS from the server to your Nodify.Me URL and to `github.com`.
- **Tested on Ubuntu 24.04 LTS (x86_64).** Binaries are also built for arm64. Other distributions are untested; the installer stops with a clear message if something it needs is missing.

---

## What the agent does

- **Reports** a heartbeat, CPU, memory and disk use, the Docker containers running on the server (names, images, state), and which common server software is installed and how it is set up: Docker, nginx, Certbot, the firewall (UFW), Fail2ban, automatic updates and SSH hardening settings.
- **Runs actions you ask for.** Actions run only when you start them in the web app, from a fixed list that is built into the agent. Today that list is: install Docker, install nginx, install Certbot. If something is already installed it is left alone. If something is already on the server that an action would have to change, the action stops, changes nothing, and tells you what it found. Nothing is replaced unless you approve it, and replaced files are backed up first.
- **Updates itself** (see below).

It does not run free-form commands. It never sends your applications' environment variables, files, logs or databases: for each container it reports only the name, image, state, ports and labels (the agent reads a container's environment locally to recognise frameworks, and discards it).

## What gets installed

| What | Where |
|---|---|
| Agent program | `/usr/local/bin/nodifyme-agent` |
| Dedicated user and group | `nodifyme` (no login shell) |
| Settings: your Nodify.Me URL and this server's token (readable only by `nodifyme` and root) | `/etc/nodifyme/agent.env` |
| Data and logs | `/var/lib/nodifyme`, `/var/log/nodifyme` |
| Agent service | `nodifyme-agent.service` |
| Update service | `nodifyme-agent-update.path` and `.service`, with files in `/usr/local/lib/nodifyme` |
| Privileged helper | `nodifyme-helper.socket` and `.service` |

## How it stays safe

- The agent runs as the unprivileged `nodifyme` user with systemd hardening. It **opens no listening port** that is reachable from the network. It makes outgoing connections only to your Nodify.Me URL and to GitHub (to look for new versions).
- Work that needs root is done by a small **privileged helper**. It is started only when the agent asks, stops after about a minute without a request, accepts requests only from the `nodifyme` user, and can run only the built-in actions above, with fixed programs and arguments, never a command string.
- **Everything downloaded is verified.** The installer checks the binary's SHA-256 checksum and its RSA-4096 signature against [build-public-key.pem](build-public-key.pem) and refuses to install if either is missing or wrong. Automatic updates are checked the same way.
- The agent needs **no SSH access** to your server after it is installed.

To verify a download yourself:

```bash
openssl dgst -sha256 -verify build-public-key.pem \
  -signature nodifyme-agent-linux-amd64.sig nodifyme-agent-linux-amd64
sha256sum -c checksums.txt --ignore-missing
```

## Updates

The agent checks GitHub for a newer release every six hours. It downloads and verifies it, and a small root service re-verifies and installs it, restoring the previous version if the new one does not start. To update by hand (this also adds the privileged helper to servers installed with an older version):

```bash
curl -fsSLO https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/update.sh
sudo bash update.sh            # latest; or: sudo bash update.sh v0.1.7
```

## Everyday commands

```bash
systemctl status nodifyme-agent            # is it running?
journalctl -u nodifyme-agent -f            # live log
sudo systemctl restart nodifyme-agent
nodifyme-agent --version
sudo -u nodifyme nodifyme-agent helper-check   # is the privileged helper working?
```

## Uninstall

```bash
curl -fsSLO https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/uninstall.sh
sudo bash uninstall.sh
```

It asks you to confirm, tells Nodify.Me the agent was removed (the server then shows as *Agent Missing* in your account and its data is kept), and removes the agent, its services, user and files. Software installed by actions (Docker, nginx, Certbot) is **not** removed.

## Problems

See [docs/troubleshooting.md](docs/troubleshooting.md).
