# Nodify.Me Agent changelog

User-facing notes for each release. This file is copied to the public repository and its newest section becomes the GitHub release notes (see `scripts/agent/`), so write for someone who installs the agent, and keep internals out. Newest first. Each release is a `## X.Y.Z` heading.

## 0.1.14

**New**
- **Container logs and restart.** The web app can show the recent logs of any container on the server. For containers of apps that Nodify.Me deployed it can also restart them, and start, stop and restart the app as a whole. Containers that Nodify.Me did not deploy are read-only: you can look at their logs, and nothing else is done to them.
- **Container CPU and memory.** The agent now reports how much CPU and memory each running container uses, so the web app can show it per container and over time.
- **Automatic security updates from the web app.** Where `unattended-upgrades` is missing or switched off, the web app can install it and turn it on. Nothing else about the server's update settings is changed, and a server that already had it on is left alone.
- **Server settings.** Set the server's timezone from a list the server itself provides, and restart the whole server from the web app. A restart is scheduled a minute ahead so you can still read the warning, and the result reaches the web app before the server goes down.
- **Scheduled tasks, read-only.** The web app can list the server's cron jobs (from the system crontab, `/etc/cron.d`, user crontabs and the daily, weekly and monthly folders) and its systemd timers with their last and next run. Cron does not record when a job last ran, so only timers show that. Commands are shortened and values that look like passwords or tokens are hidden. Nothing is changed.
- **Git.** The agent reports whether Git is installed and its version, and the web app can install it from your distribution's packages. A Git that is already on the server is left exactly as it is.
- **The server's timezone** is part of what the agent reports.

**Fixed**
- A container is no longer labelled as infrastructure just because its image name contains something like `nginx` or `redis`.
- Enabling automatic updates reports correctly that it installed the package, instead of saying it was already on.

## 0.1.13

**New**
- **Reports on your plan's schedule.** The agent now takes its reporting interval from Nodify.Me, so a Pro server reports about every 5 minutes and a Business server about every minute. Until now every agent used the 15-minute default whatever the plan. The interval arrives with each heartbeat answer, so a plan change takes effect by itself, and an agent that has not heard from Nodify.Me keeps its last interval (15 minutes on a fresh install). Values outside 30 seconds to 1 hour are ignored.
- **Checks for updates soon after it starts.** A newly started agent looks for a newer release about two minutes after it connects, instead of waiting for its next six-hourly check. A server that was offline when a release came out no longer waits hours to catch up.
- **A clearer message when Let's Encrypt is blocked.** If a certificate request fails because Let's Encrypt was answered with a 403 (what Cloudflare and similar proxies send to its checker), the deploy now says so and explains the fix: a rule that skips security checks for `/.well-known/acme-challenge/`, or setting the record to DNS only until the certificate is issued.

## 0.1.12

**New**
- **HTTPS for an app's domain.** When an app has a domain, the agent can request a free Let's Encrypt certificate with Certbot and serve the app over HTTPS. The domain must already point at the server, because Let's Encrypt checks it over plain HTTP. The app goes live over HTTP first, the certificate is requested, and only then is HTTPS switched on. If the certificate cannot be issued, the app keeps running over HTTP and the deploy says why. Certificates renew by themselves through Certbot's timer, and deploying again reuses an existing certificate instead of asking for a new one.
- **Optional redirect to HTTPS.** Plain HTTP can redirect to HTTPS. The path Let's Encrypt uses to check the domain stays reachable over HTTP, so renewals keep working. If the domain sits behind a proxy such as Cloudflare, use the redirect only when the proxy talks HTTPS to your server (Cloudflare's Full or Full (strict) mode); otherwise visitors get a redirect loop.
- Deploying with HTTPS needs Certbot installed (the web app tells you when it is missing). If the firewall is on and port 443 is closed, the deploy warns you that visitors cannot reach HTTPS yet; it never changes the firewall itself. Removing an app also removes the certificate that app's site used.

## 0.1.11

**New**
- **Run a Docker app from the web app.** Give Nodify.Me a public image (such as `ghcr.io/you/site:1.4.0`), the port it listens on, optional environment variables and, optionally, a domain. The agent pulls the image, runs it with Docker Compose, publishes it only on the server's own loopback address, and (with a domain) adds an nginx site that proxies the domain to it. Start, stop, restart, redeploy, view logs and remove from the web app. Nothing is built on your server.
- **What is touched.** Apps live in `/srv/nodifyme/apps/<name>/` and their nginx sites in `/etc/nginx/conf.d/nodifyme-app-<name>.conf`; the agent only modifies files it created and asks before replacing anything else. Environment values are written only to a root-only file on the server and are never logged. Uninstalling the agent leaves your apps running and their files in place.
- **Private images.** Add a registry login (registry, username, access token) to an app. The agent signs in for that one pull only, using a temporary file that is removed straight afterwards; nothing stays logged in on your server.
- **Image check before it starts.** The agent inspects a pulled image first. An image built for the wrong CPU (for example arm64 on an amd64 server) is refused with a clear message and nothing is changed, instead of failing later with "exec format error". It also warns when the image declares a different port than the one you set, runs as root, declares volumes, or is very large.
- **Protection against a runaway app.** A container is limited to 75% of the server's memory so an app that leaks or spikes is stopped on its own instead of taking SSH or the agent down with it, and its logs rotate (10 MB, 3 files) so they cannot fill the disk. Before pulling, the agent refuses to continue with less than 2 GB of free disk space, and warns on servers with little memory or no swap.
- **Firewall (UFW) from the web app.** Install UFW, see what is open, open or close a port (optionally only for one address or range), and turn the firewall on or off. Turning it on always keeps SSH open (and can keep web ports 80 and 443 open), and it switches itself off again if it cannot confirm SSH is allowed. The rule that lets you in over SSH cannot be removed while the firewall is on. Rules you already had are kept.
- **Fail2ban from the web app.** Install Fail2ban (its standard settings watch SSH; no configuration is written), see each jail with the addresses it has banned, and release one address or all of them, for example if you banned yourself.
- Deploying needs Docker (and nginx, if you use a domain); the web app tells you when one is missing. HTTPS certificates are not part of this release.

## 0.1.10

**New**
- **The server page catches up at once after an install.** When Install Docker, nginx or Certbot succeeds, the agent reports the new server stack and containers right away, instead of at its next 10-minute scan.

## 0.1.9

**New**
- **Check now.** The web app can ask the agent to report immediately (heartbeat, metrics, server stack and containers), for example after you changed something on the server. The web app limits it to once per your plan's reporting interval.
- **Update from the web app.** When a newer release exists, the web app can tell the agent to update itself. The agent downloads the release, verifies its checksum and signature, reports the result, and only then restarts through the same root update service as automatic updates. A download that fails verification is refused and nothing changes.

**Fixed**
- **A misleading first CPU reading.** The first metrics are sent as soon as the agent connects, which on a new server is right after the installer ran and the machine is at its busiest, so the server page could show 100% CPU for the first 15 minutes. CPU is now measured over three seconds instead of one, and a second sample is sent a minute after connecting to replace that first reading.

## 0.1.8

**Fixed**
- **Docker monitoring.** The agent runs as its own unprivileged user, which cannot read Docker's socket (by design: access to it is equivalent to root). Docker therefore showed as "not running", Docker Compose as "not installed", and no containers were listed. The agent now asks the privileged helper for these read-only checks. Only what monitoring needs is passed back: container names, images, states, ports, labels and the value of `NODE_ENV`. No other environment variables, arguments or mounts.
- **A newly connected server fills in at once.** Metrics and the container list are now sent right after the agent connects, instead of after the first interval (15 minutes on the smallest plan).

## 0.1.7

Released 2026-10-15.

**New**
- **Actions from the web app.** Things you start in Nodify.Me (install Docker, nginx or Certbot on a server) now reach the agent immediately. The agent keeps one outgoing connection to Nodify.Me; it still opens no incoming ports.
- **A small privileged helper** does the work that needs root. It is started only when the agent asks, stops after a minute without a request, only accepts requests from the agent's own user, and can run only a fixed built-in list of actions. The agent itself still runs as an ordinary user.
- **Clear results.** If something is already on the server that an action would have to change (an existing Docker repository, a conflicting package), the action stops, changes nothing, and tells you what it found. Nothing is replaced unless you approve it, and replaced files are backed up first. Software that is already installed is left alone.
- **"Agent Missing".** Uninstalling the agent now tells Nodify.Me, so the server shows as missing (your data is kept) instead of quietly going silent.
- **`update.sh`** updates an installed agent through the same verified installer. Re-running it also adds the helper to servers installed with an older version.
- Support commands: `nodifyme-agent helper-check` and `nodifyme-agent helper-call`.

**Security**
- Container environment variables (which usually contain an application's secrets) are never sent from the server. Earlier versions read them to recognise frameworks and sent them along with the container list.
- The installer now verifies the downloaded binary's SHA-256 checksum **and** its RSA signature, and refuses to install if either is missing or wrong.
- Automatic updates no longer need sudo: the agent downloads and verifies a signed update, and a small root service re-verifies and applies it, restoring the previous version if the new one does not start.
- Older Nodify.Me onboarding left a permanent `nodifyme-api` login on the server. The installer and uninstaller now remove it.

**Fixed**
- The installer works on minimal server images (it no longer needs the `file` command).
- Upgrading no longer leaves an old privileged helper running.
- Uninstalling lists everything it removes, including the helper.

## 0.1.6

Monitoring only: heartbeat, metrics, Docker container discovery and server stack detection.
