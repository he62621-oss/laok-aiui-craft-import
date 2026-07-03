<script type="application/json" def>
{
  "navigationBarTitleText": "LaoK Native Bridge",
  "description": "Runs the LaoK native capability bridge probe for Rokid AIUI, including bridge health, local file search, and current-view photo upload.",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "statusText": {
          "type": "string",
          "description": "Current probe status shown on the glasses page"
        },
        "relayText": {
          "type": "string",
          "description": "Current bridge URL, result summary, or saved image path"
        }
      }
    }
  }
}
</script>

<script setup>
import wx from 'wx';

const BRIDGE_BASE_URL = "http://192.168.60.5:8766";
const TURN_URL = `${BRIDGE_BASE_URL}/v1/session/turn`;
const PHOTO_URL = `${BRIDGE_BASE_URL}/v1/vision/photo`;

function parseJsonResponse(data) {
  if (data && typeof data === "object") {
    return data;
  }
  if (typeof data === "string" && data.trim()) {
    return JSON.parse(data);
  }
  return {};
}

async function postJson(url, payload) {
  return new Promise((resolve, reject) => {
    wx.request({
      url,
      method: "POST",
      dataType: "json",
      header: { "content-type": "application/json" },
      data: payload,
      success: (res) => {
        try {
          const body = parseJsonResponse(res.data);
          if (res.statusCode < 200 || res.statusCode >= 300 || !body.ok) {
            reject(new Error(body.error || `bridge_http_${res.statusCode}`));
            return;
          }
          resolve(body);
        } catch (error) {
          reject(error);
        }
      },
      fail: (error) => {
        reject(new Error(error && error.errMsg ? error.errMsg : String(error)));
      }
    });
  });
}

export default {
  data: {
    busy: false,
    statusText: "Ready",
    relayText: BRIDGE_BASE_URL,
    sessionId: `aiui-laok-native-${Date.now()}`
  },

  onShow() {
    this.ensureCameraContext({ silent: true });
  },

  onHide() {
    this.cameraContext = null;
  },

  onKeyDown(event) {
    if (event?.code === "Backspace") {
      wx.exitMiniProgram();
      return;
    }

    if (event?.code === "Enter") {
      this.captureAndSend();
    }
  },

  ensureCameraContext(options = {}) {
    if (this.cameraContext && typeof this.cameraContext.takePhoto === "function") {
      return true;
    }

    try {
      this.cameraContext = wx.media && typeof wx.media.createCameraContext === "function"
        ? wx.media.createCameraContext()
        : null;
      const ok = !!(this.cameraContext && typeof this.cameraContext.takePhoto === "function");
      this.setData({ statusText: ok ? "Camera context ready" : "Camera context unavailable" });
      if (!ok && !options.silent) {
        this.setData({ relayText: "wx.media.createCameraContext unavailable" });
      }
      return ok;
    } catch (error) {
      this.cameraContext = null;
      this.setData({
        statusText: "Camera context failed",
        relayText: error && error.message ? error.message : String(error)
      });
      return false;
    }
  },

  async probeBridge() {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "Probing LaoK native bridge..." });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: "老K，AIUI 原生 Agent 桥接探针已启动。记住当前任务是验证眼镜原生 Agent 加本地能力桥。",
        channel: "rokid_aiui_native"
      });
      this.setData({
        statusText: body.answer_brief || "Bridge accepted",
        relayText: `turns=${body.work_memory && body.work_memory.turn_count}`
      });
    } catch (error) {
      this.setData({
        statusText: `Bridge failed: ${error && error.message ? error.message : String(error)}`
      });
    } finally {
      this.setData({ busy: false });
    }
  },

  async searchReference() {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "Searching local Reference files..." });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: "老K，查文件 Reference。",
        capability: "file.search",
        args: { query: "Reference", limit: 8 }
      });
      const matches = (body.capability_result && body.capability_result.matches) || [];
      this.setData({
        statusText: `Local file search returned ${matches.length} matches`,
        relayText: matches[0] ? matches[0].path : "No match"
      });
    } catch (error) {
      this.setData({
        statusText: `Search failed: ${error && error.message ? error.message : String(error)}`
      });
    } finally {
      this.setData({ busy: false });
    }
  },

  async captureAndSend() {
    if (this.data.busy) return;
    if (!this.ensureCameraContext()) {
      this.setData({ statusText: "Camera context is not ready" });
      return;
    }

    this.setData({ busy: true, statusText: "Taking photo..." });
    try {
      const photo = await this.cameraContext.takePhoto({ quality: "high" });
      const imageBase64 = wx.arrayBufferToBase64(photo.data);
      if (!imageBase64) {
        throw new Error("empty image data");
      }
      this.setData({ statusText: `Uploading ${photo.mimeType || "image/jpeg"}...` });
      const body = await postJson(PHOTO_URL, {
        image_base64: imageBase64,
        mime_type: photo.mimeType || "image/jpeg",
        session_id: this.data.sessionId,
        question: "老K，基于这张眼镜当前视野照片，简短说明眼前是什么。"
      });
      this.setData({
        statusText: `Bridge accepted ${body.bytes || 0} bytes`,
        relayText: body.saved_image || PHOTO_URL
      });
    } catch (error) {
      this.setData({
        statusText: `Capture failed: ${error && error.message ? error.message : String(error)}`
      });
    } finally {
      this.setData({ busy: false });
    }
  }
};
</script>

<page>
  <view class="page">
    <view class="status">
      <text class="title">LaoK Bridge</text>
      <text class="line">{{ statusText }}</text>
      <text class="line small">{{ relayText }}</text>
    </view>

    <camera id="laokCamera" class="camera"></camera>

    <view class="actions">
      <button class="secondary" bindtap="probeBridge">Probe Bridge</button>
      <button class="secondary" bindtap="searchReference">Search Reference</button>
      <button class="primary" bindtap="captureAndSend">{{ busy ? "Sending..." : "Capture" }}</button>
    </view>
  </view>
</page>

<style>
.page {
  min-height: 100vh;
  padding: 28rpx;
  background: #101820;
  color: #f7f7f2;
}

.status {
  margin-bottom: 20rpx;
}

.title {
  display: block;
  font-size: 34rpx;
  font-weight: 700;
  margin-bottom: 12rpx;
}

.line {
  display: block;
  font-size: 24rpx;
  line-height: 1.5;
  color: #dfe7e2;
}

.small {
  font-size: 20rpx;
  color: #9fb1aa;
}

.camera {
  width: 424rpx;
  height: 240rpx;
  background: #000;
  border-radius: 8rpx;
  overflow: hidden;
}

.actions {
  margin-top: 22rpx;
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}

.primary,
.secondary {
  width: 220rpx;
  height: 64rpx;
  line-height: 64rpx;
  border-radius: 8rpx;
  color: #ffffff;
  font-size: 22rpx;
}

.primary {
  background: #2fb344;
}

.secondary {
  background: #243642;
}
</style>
