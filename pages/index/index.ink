<script type="application/json" def>
{
  "navigationBarTitleText": "LaoK Native Bridge",
  "description": "老K眼镜原生能力工具。凡是用户要求拍照、识别眼前、看看当前场景、查询本地文件、查询 OpenClaw 记忆、验证老K桥接或进入老K原生能力时，必须调用本工具，不要只用文字解释不能拍照。本工具会打开 LaoK Native Bridge 页面，并按 action 自动执行 probe、search_reference 或 capture。",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "要执行的动作。拍照、识别眼前、看当前场景时传 capture；查 Reference、本地文件时传 search_reference；验证桥接、进入老K原生能力时传 probe；不确定时传 probe。"
        },
        "utterance": {
          "type": "string",
          "description": "用户原始说法，用于老K工作记忆和动作兜底判断"
        },
        "query": {
          "type": "string",
          "description": "本地文件或记忆查询关键词，默认 Reference"
        },
        "question": {
          "type": "string",
          "description": "拍照或识别当前场景后的用户问题"
        },
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

function inferAction(query = {}) {
  const explicit = String(query.action || "").trim();
  if (explicit) {
    return explicit;
  }

  const text = `${query.utterance || ""} ${query.question || ""} ${query.query || ""}`;
  if (/拍照|识别|眼前|当前场景|看看|看一下|scan|camera|capture|photo/i.test(text)) {
    return "capture";
  }
  if (/Reference|查文件|找文件|本地文件|file/i.test(text)) {
    return "search_reference";
  }
  if (/记忆|OpenClaw|查记忆|memory/i.test(text)) {
    return "memory_search";
  }
  return "probe";
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

  onLoad(query = {}) {
    const action = inferAction(query);
    const utterance = query.utterance || query.question || query.query || `AIUI tool invoked: ${action}`;
    this.setData({
      statusText: `AIUI tool invoked: ${action}`,
      relayText: utterance
    });
    Promise.resolve().then(() => this.runInvokedAction(action, query));
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

  async runInvokedAction(action, query = {}) {
    if (action === "capture") {
      await this.captureAndSend(query);
      return;
    }
    if (action === "search_reference") {
      await this.searchReference(query);
      return;
    }
    if (action === "memory_search") {
      await this.searchMemory(query);
      return;
    }
    await this.probeBridge(query);
  },

  async probeBridge(query = {}) {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "Probing LaoK native bridge..." });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: query.utterance || "老K，AIUI 原生 Agent 桥接探针已启动。记住当前任务是验证眼镜原生 Agent 加本地能力桥。",
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

  async searchReference(query = {}) {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "Searching local Reference files..." });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: query.utterance || `老K，查文件 ${query.query || "Reference"}。`,
        capability: "file.search",
        args: { query: query.query || "Reference", limit: 8 }
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

  async searchMemory(query = {}) {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "Searching OpenClaw memory..." });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: query.utterance || `老K，查记忆 ${query.query || "Rokid 老K"}。`,
        capability: "memory.search",
        args: { query: query.query || query.utterance || "Rokid 老K", top: 5 }
      });
      const ok = body.capability_result && body.capability_result.ok;
      this.setData({
        statusText: ok ? "OpenClaw memory search returned" : "OpenClaw memory search failed",
        relayText: body.answer_brief || "memory.search"
      });
    } catch (error) {
      this.setData({
        statusText: `Memory failed: ${error && error.message ? error.message : String(error)}`
      });
    } finally {
      this.setData({ busy: false });
    }
  },

  async captureAndSend(query = {}) {
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
        question: query.question || query.utterance || "老K，基于这张眼镜当前视野照片，简短说明眼前是什么。"
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
