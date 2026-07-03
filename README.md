# 老K AIUI Craft Import

Voice-first AIUI project used to import Tony's glasses-side `老K` agent into Rokid Craft.

This repository intentionally contains no credentials, tokens, or private runtime data. The default bridge URL is a LAN development endpoint and must be adjusted for the active test network before real-device validation.

## 2026-07-04 Status

- User-visible name: `老K`
- Current source version: `0.5.2+codex.20260704-camera-context`
- Last native version uploaded to Craft: `1.0.8`
- Runtime UI is voice-first and has no manual engineering controls.
- Old Lingzhu SSE fallback was renamed to `老K旧通道` to avoid competing with the `老K` wake name.
- Bridge access is now HTTPS-first: `https://agent.debetter.com/rokid-laok-native` with LAN fallback only for same-network debugging.
- The public bridge requires an authorization token. Source code keeps `__LAOK_BRIDGE_TOKEN__` as a placeholder; release AIX packages inject the private token at build time.
- Current-frame recognition posts directly to `/v1/session/turn` with stable session `aiui-laok-native-tony-main`, `fast: true`, and `vision_timeout: 8`.
- The local bridge is expected to degrade quickly and truthfully if GLM vision times out instead of blocking the glasses UI.
- `1.0.8` uses the official `wx.createCameraContext("laokCamera")` path first, with `wx.media.createCameraContext("laokCamera")` retained as compatibility fallback.
- Craft CDN: `https://basecloud.rokidcdn.com/basecloud/prod/a575e2ffc784467e94b7696bee7fda24.aix`
- AIX SHA256: `906fb1fa51b7efd730a59325bfad1a229d9518006b17d1e170b830d16476061e`
