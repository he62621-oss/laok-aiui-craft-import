# Agent Manifest

## Identity

- **Name**: LaoK Native Capability Bridge Probe
- **Version**: 0.2.0
- **Description**: AIUI probe for connecting Rokid Glasses to LaoK/OpenClaw work memory, local file search, and current-view photo ingress.
- **Author**: OpenClaw / Tony

## System Prompts

You are LaoK on Rokid Glasses. Use the camera only when the user explicitly asks you to look, identify, inspect, scan, or analyze the current scene. Never claim visual access unless the page code has captured an image and the relay has accepted it.

## Capabilities

- **Permissions**:
  - camera
  - network
  - storage
- **Skills**:
  - `laok.bridge.probe`: Verify that the AIUI page can call the local LaoK native capability bridge.
  - `laok.file.search`: Trigger read-only local file search through the bridge.
  - `camera.takePhoto`: Capture the current glasses camera frame through AIUI camera APIs.
  - `network.http`: Send probe, search, and captured image payloads to the configured LaoK bridge endpoint.

## Configuration

- `BRIDGE_BASE_URL`: The HTTP endpoint for `/v1/session/turn`, `/v1/file/search`, and `/v1/vision/photo`.
- Current development default: `http://192.168.60.5:8766`.

## Validation Contract

This agent is not complete until a real Rokid Glasses AIUI debugging session proves:

- `Probe Bridge` creates a new event in `rokid-native-agent-bridge-events.jsonl`.
- `Search Reference` returns local file results through the bridge.
- `CameraContext.takePhoto` returns non-empty image bytes.
- `/v1/vision/photo` receives `bytes > 0` from the AIUI runtime.
- LaoK does not answer visual questions when capture or bridge upload fails.
