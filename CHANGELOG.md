# Changelog

Notable changes to uz_MugShot. Versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-25

First public release.

- Automatic capture on appearance change through a client fingerprint watch, works with any appearance script
- Plain gameplay guard: captures wait for menus, cameras, fades and cutscenes to finish
- Chroma studio with fixed framing and lighting, server-side key with soft edges, 512×512 transparent PNG
- Weathersync pause during the shot for Renewed-Weathersync, qb-weathersync and qbx_weathersync
- Photos stored per character under `shots/`, in-memory cache, latent events, per-player rate limits
- Exports: `GetPhotoDataURI`, `HasPhoto`, `GetPhotoByCitizenId`, `CaptureAndReturn`, `ForceRecapture`, `TriggerInitialCapture`
- Drop-in `MugShotBase64` replacement: 128×128 photo by default, native headshot fallback, never `nil`
- `/remugshot [id]` admin command
- Update notice in the server console when a newer GitHub release is out
- Qbox, QBCore and ESX bridges with auto-detection

[1.0.0]: https://github.com/uz-scripts/uz_MugShot/releases/tag/v1.0.0
