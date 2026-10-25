# Security Policy

## Supported versions

Only the latest release gets security fixes. Update before reporting.

## Reporting a vulnerability

Do not open a public issue for security problems. Report them privately instead:

- [Open a private security advisory](https://github.com/uz-scripts/uz_MugShot/security/advisories/new) on GitHub, or
- Open a ticket on our [Discord](https://discord.uz-scripts.com) and ask for a staff member.

Include the version, what an attacker can do, and the steps to reproduce it. You will get a reply within a few days. Once a fix is released, we credit you in the release notes unless you prefer otherwise.

## Scope

Things we treat as security issues:

- A client uploading data that crashes the server, fills the disk or bypasses `Config.InputLimits` / `Config.RequestLimit`
- Reading or writing files outside `shots/` (for example through a crafted citizenid)
- Getting another player's photo or triggering captures for other players without the server allowing it
- Running `/remugshot` without the ACE permission

Things that are not: problems that need server console or file access, and bugs in screenshot-basic, yarn or the frameworks themselves (report those upstream).
