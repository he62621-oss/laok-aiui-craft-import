<script type="application/json" def>
{
  "navigationBarTitleText": "老K",
  "description": "Tony 的眼镜端老K。凡是用户要求拍照、识别眼前、看看当前场景、查询本地文件、查询 OpenClaw 记忆、继续当前任务或进入老K原生能力时，必须调用本工具。本工具语音优先、自动执行，只呈现极简中文状态和结果，不要求用户在眼镜端点击按钮。",
  "schema": {
    "data": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "description": "要执行的动作。拍照、识别眼前、看当前场景时传 capture；查 Reference、本地文件时传 search_reference；查 OpenClaw 记忆时传 memory_search；验证桥接、进入老K原生能力时传 probe；不确定时传 probe。"
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
          "description": "眼镜端极简中文状态"
        },
        "relayText": {
          "type": "string",
          "description": "眼镜端极简中文结果摘要"
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
const STABLE_SESSION_ID = "aiui-laok-native-tony-main";

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
    statusText: "我在",
    relayText: "",
    sessionId: STABLE_SESSION_ID
  },

  onLoad(query = {}) {
    const action = inferAction(query);
    const utterance = query.utterance || query.question || query.query || "老K，继续当前任务。";
    this.setData({
      statusText: "正在处理",
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
      if (!options.silent) {
        this.setData({ statusText: ok ? "相机已就绪" : "相机暂不可用" });
      }
      if (!ok && !options.silent) {
        this.setData({ relayText: "当前眼镜运行环境没有开放相机上下文" });
      }
      return ok;
    } catch (error) {
      this.cameraContext = null;
      this.setData({
        statusText: "相机启动失败",
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
    this.setData({ busy: true, statusText: "正在连接老K", relayText: "" });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: query.utterance || "老K，AIUI 原生 Agent 桥接已启动。记住当前任务是验证眼镜原生 Agent 加本地能力桥。",
        channel: "rokid_aiui_native"
      });
      this.setData({
        statusText: body.answer_brief || "已接入老K",
        relayText: "可以继续问我"
      });
    } catch (error) {
      this.setData({
        statusText: "老K连接失败",
        relayText: error && error.message ? error.message : String(error)
      });
    } finally {
      this.setData({ busy: false });
    }
  },

  async searchReference(query = {}) {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "正在查本地文件", relayText: "" });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: query.utterance || `老K，查文件 ${query.query || "Reference"}。`,
        capability: "file.search",
        args: { query: query.query || "Reference", limit: 8 }
      });
      const fileResult = body.capability_result && body.capability_result.file;
      const matches = (fileResult && fileResult.matches) || [];
      this.setData({
        statusText: body.answer_brief || (matches.length ? `找到 ${matches.length} 条` : "没有找到"),
        relayText: matches[0] ? "已结合文件结果回答" : "可以换个关键词继续查"
      });
    } catch (error) {
      this.setData({
        statusText: "本地文件查询失败",
        relayText: error && error.message ? error.message : String(error)
      });
    } finally {
      this.setData({ busy: false });
    }
  },

  async searchMemory(query = {}) {
    if (this.data.busy) return;
    this.setData({ busy: true, statusText: "正在查记忆", relayText: "" });
    try {
      const body = await postJson(TURN_URL, {
        session_id: this.data.sessionId,
        utterance: query.utterance || `老K，查记忆 ${query.query || "Rokid 老K"}。`,
        capability: "memory.search",
        args: { query: query.query || query.utterance || "Rokid 老K", top: 5 }
      });
      const memoryResult = body.capability_result && body.capability_result.memory;
      const ok = memoryResult && memoryResult.ok;
      this.setData({
        statusText: body.answer_brief || (ok ? "记忆已查到" : "记忆查询失败"),
        relayText: body.answer_brief || "可以继续补充关键词"
      });
    } catch (error) {
      this.setData({
        statusText: "记忆查询失败",
        relayText: error && error.message ? error.message : String(error)
      });
    } finally {
      this.setData({ busy: false });
    }
  },

  async captureAndSend(query = {}) {
    if (this.data.busy) return;
    if (!this.ensureCameraContext()) {
      this.setData({ statusText: "相机暂不可用", relayText: "请稍后再试" });
      return;
    }

    this.setData({ busy: true, statusText: "正在看", relayText: "" });
    try {
      const photo = await this.cameraContext.takePhoto({ quality: "high" });
      const imageBase64 = wx.arrayBufferToBase64(photo.data);
      if (!imageBase64) {
        throw new Error("照片数据为空");
      }
      this.setData({ statusText: "正在分析眼前画面" });
      const body = await postJson(TURN_URL, {
        image_base64: imageBase64,
        mime_type: photo.mimeType || "image/jpeg",
        session_id: this.data.sessionId,
        utterance: query.question || query.utterance || "老K，基于这张眼镜当前视野照片，简短说明眼前是什么。",
        question: query.question || query.utterance || "老K，基于这张眼镜当前视野照片，简短说明眼前是什么。",
        capability: "vision.photo",
        analyze: true,
        fast: true,
        vision_timeout: 8
      });
      this.setData({
        statusText: body.answer_brief || "已看到",
        relayText: "可以继续追问"
      });
    } catch (error) {
      this.setData({
        statusText: "识别失败",
        relayText: error && error.message ? error.message : String(error)
      });
    } finally {
      this.setData({ busy: false });
    }
  }
};
</script>

<page>
  <view class="page">
    <camera id="laokCamera" class="camera"></camera>

    <view class="status">
      <text class="title">老K</text>
      <text class="line">{{ statusText }}</text>
      <text class="line small">{{ relayText }}</text>
    </view>
  </view>
</page>

<style>
.page {
  min-height: 100vh;
  padding: 28rpx;
  background: transparent;
  color: #21f36b;
}

.status {
  position: absolute;
  left: 28rpx;
  right: 28rpx;
  bottom: 34rpx;
  padding: 12rpx 0;
}

.title {
  display: block;
  font-size: 28rpx;
  font-weight: 700;
  margin-bottom: 8rpx;
}

.line {
  display: block;
  font-size: 24rpx;
  line-height: 1.45;
  color: #21f36b;
}

.small {
  margin-top: 6rpx;
  font-size: 20rpx;
  color: #b8ffd0;
}

.camera {
  position: absolute;
  left: -20rpx;
  top: -20rpx;
  width: 1rpx;
  height: 1rpx;
  opacity: 0;
}
</style>
