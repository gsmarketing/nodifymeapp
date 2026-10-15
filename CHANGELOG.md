# Nodify.Me Agent changelog

User-facing notes for each release. This file is copied to the public repository and its newest section becomes the GitHub release notes (see `scripts/agent/`), so write for someone who installs the agent, and keep internals out. Newest first. Each release is a `## X.Y.Z` heading.

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
