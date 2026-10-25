# Contributing to uz_MugShot

Thanks for taking the time. Bug reports, fixes, docs improvements and support for more frameworks or weathersync scripts are all welcome.

For questions and setup help, use [Discord](https://discord.uz-scripts.com) instead of the issue tracker. Issues are for bugs and concrete feature requests.

## Reporting a bug

Use the [bug report form](https://github.com/uz-scripts/uz_MugShot/issues/new?template=bug_report.yml). The things that make a bug fixable:

- uz_MugShot version (`version` in `fxmanifest.lua`), framework and its version, server artifact build
- Your appearance script (illenium-appearance, fivem-appearance, qb-clothing, esx_skin, ...) and weathersync, if any
- Server console and F8 output with `Config.Debug = true`
- For a bad photo: the final `shots/{cid}/mugshot.png` and the unkeyed `shots/{cid}/mugshot.raw.png` (kept when `Config.Debug` is on)

Photos and citizenids belong to your players. Only attach ones you are allowed to share.

## Development setup

1. A local FiveM server with one of `qbx_core`, `qb-core` or `es_extended`, plus `screenshot-basic` and `yarn`.
2. Clone into your resources folder under the exact name `uz_MugShot`:
   ```
   git clone https://github.com/uz-scripts/uz_MugShot.git uz_MugShot
   ```
3. `ensure uz_MugShot` in `server.cfg`, set `Config.Debug = true`, start the server. Node dependencies (`pngjs`) install through yarn on first start.
4. After a change, `restart uz_MugShot` in the server console and take a photo with `/remugshot`.

## Project layout

| Path | What lives there |
|---|---|
| `fxmanifest.lua`, `config.lua` | Manifest and every user-facing setting |
| `bridge/` | Framework detection and the Qbox / QBCore / ESX adapters |
| `client/studio.lua` | Chroma studio: clone ped, camera, lights, weathersync pause |
| `client/capture.lua` | Appearance fingerprint, plain gameplay guard, the capture itself |
| `client/main.lua` | Fingerprint watch loop, forced captures, natural triggers |
| `client/api.lua`, `client/compat.lua` | Client exports and the MugShotBase64 compat export |
| `client/nui.lua`, `nui/` | Capture curtain and the canvas helper for compat |
| `server/main.lua` | Capture requests, fingerprint checks, `/remugshot` |
| `server/processor.js` | Chroma key, edge cleanup and resize (Node, pngjs) |
| `server/storage.lua`, `server/cache.lua` | Files under `shots/` and the in-memory photo cache |
| `server/api.lua`, `server/limits.lua` | Server exports, photo requests, rate limits |

## Code style

- Lua 5.4, 4 spaces, `local` everything. Shared state goes through the existing module tables (`Bridge`, `Capture`, `Studio`, `NUI`, `Storage`, `Cache`, `Limits`), not new globals.
- Short comments that explain why, not what. English only.
- Keep `config.lua` backwards compatible. A new setting needs a default that keeps the current behaviour and a line in the README.
- Anything a client sends to the server is untrusted. Validate types and sizes, and keep it behind `Limits`.
- No new dependencies unless there is no reasonable way around it.

## Testing

There is no automated test suite yet, so test in game before opening a pull request:

- [ ] A new character gets a photo after creation
- [ ] Changing a hat or top in your clothing menu updates the photo when the menu closes
- [ ] Pants or shoes alone do not trigger a photo
- [ ] `/remugshot` and `/remugshot <id>` work, from chat and from the console
- [ ] `restart uz_MugShot` while players are online does not break anything
- [ ] Clock and weather are back to normal after a photo
- [ ] If you touched `bridge/`, test every framework you changed

## Pull requests

1. Fork, then branch from `main` (`fix/edge-fringe`, `feat/qs-appearance`).
2. One change per pull request. A refactor and a fix in the same PR are hard to review.
3. Write commit messages in the imperative, short first line: `Fix hat hair showing through beanies`.
4. Fill in the pull request template, including what you tested and on which framework.
5. Update the README and the comments in `config.lua` when behaviour or settings change.
6. Do not commit `shots/`, `node_modules/` or your server's config changes. Do not bump the version in `fxmanifest.lua`; that happens at release.

A maintainer will review as soon as possible. Small, focused PRs get merged fastest.

## License

uz_MugShot is licensed under [Apache 2.0](LICENSE). By opening a pull request you agree that your contribution is licensed under the same terms (section 5 of the license).
