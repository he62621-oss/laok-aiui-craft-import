# 老K AIUI Craft Import

Voice-first AIUI project used to import Tony's glasses-side `老K` agent into Rokid Craft.

This repository intentionally contains no credentials, tokens, or private runtime data. The default bridge URL is a LAN development endpoint and must be adjusted for the active test network before real-device validation.

## 2026-07-04 Status

- User-visible name: `老K`
- Current source version: `0.5.0+codex.20260704-native`
- Last native version uploaded to Craft before this source update: `1.0.5`
- Runtime UI is voice-first and has no manual engineering controls.
- Old Lingzhu SSE fallback was renamed to `老K旧通道` to avoid competing with the `老K` wake name.
- Current-frame recognition posts directly to `/v1/session/turn` with stable session `aiui-laok-native-tony-main`, `fast: true`, and `vision_timeout: 8`.
- The local bridge is expected to degrade quickly and truthfully if GLM vision times out instead of blocking the glasses UI.
