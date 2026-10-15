# Nodify.Me Agent changelog

User-facing notes for each release. This file is copied to the public repository and its newest section becomes the GitHub release notes (see `scripts/agent/`), so write for someone who installs the agent, and keep internals out. Newest first. Each release is a `## X.Y.Z` heading.

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
- The installer now verifies the downloaded binary's SHA-256 checksum **and** its RSA signature, and refuses to install if either is missing or wrong.
- Automatic updates no longer need sudo: the agent downloads and verifies a signed update, and a small root service re-verifies and applies it, restoring the previous version if the new one does not start.
- Older Nodify.Me onboarding left a permanent `nodifyme-api` login on the server. The installer and uninstaller now remove it.

**Fixed**
- The installer works on minimal server images (it no longer needs the `file` command).
- Upgrading no longer leaves an old privileged helper running.
- Uninstalling lists everything it removes, including the helper.

## 0.1.6

Monitoring only: heartbeat, metrics, Docker container discovery and server stack detection.
