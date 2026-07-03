# 老K AIUI Craft Import

Voice-first AIUI project used to import Tony's glasses-side `老K` agent into Rokid Craft.

This repository intentionally contains no credentials, tokens, or private runtime data. The default bridge URL is a LAN development endpoint and must be adjusted for the active test network before real-device validation.

## 2026-07-04 Status

- User-visible name: `老K`
- Current source version: `0.5.3+codex.20260704-contract-v2`
- Last native version uploaded to Craft: `1.0.9`
- Runtime UI is voice-first and has no manual engineering controls.
- Old Lingzhu SSE fallback was renamed to `老K旧通道` to avoid competing with the `老K` wake name.
- Bridge access is now HTTPS-first: `https://agent.debetter.com/rokid-laok-native` with LAN fallback only for same-network debugging.
- The public bridge requires an authorization token. Source code keeps `__LAOK_BRIDGE_TOKEN__` as a placeholder; release AIX packages inject the private token at build time.
- Current-frame recognition posts directly to `/v1/session/turn` with stable session `aiui-laok-native-tony-main`, `fast: true`, and `vision_timeout: 8`.
- The local bridge is expected to degrade quickly and truthfully if GLM vision times out instead of blocking the glasses UI.
- `1.0.9` keeps the official `wx.createCameraContext("laokCamera")` path first, with `wx.media.createCameraContext("laokCamera")` retained as compatibility fallback.
- `1.0.9` hardens the Craft agent metadata so every LaoK utterance should invoke the AIUI tool: ordinary dialogue uses `connect`, current-frame recognition uses `capture`, OpenClaw memory uses `memory_search`, and local computer files use `file_search`.
- AIUI calls now include `native_contract_version=laok-aiui-native-contract-20260704-v2` for real-device log verification.
- Craft CDN: `https://basecloud.rokidcdn.com/basecloud/prod/5928bd344588429c8e2771f1eeeb1a2f.aix`
- AIX MD5: `9f510fa10c5ff5626e4135eb73198470`
- AIX SHA256: `e483c46839d3bdeae3d99eba9ea68cbeeb1a0beda10adbf7328a962a2664dfc3`
