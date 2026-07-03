#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import initAix, { AixReaderWasm } from "@yodaos-pkg/aix/pkg/aix_web.js";

const __filename = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(__filename), "..");
const errors = [];
const warnings = [];

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function assertOk(condition, message) {
  if (!condition) errors.push(message);
}

function warnIf(condition, message) {
  if (condition) warnings.push(message);
}

function parseJson(relativePath) {
  try {
    return JSON.parse(readText(relativePath));
  } catch (error) {
    errors.push(`${relativePath} is not valid JSON: ${error.message}`);
    return null;
  }
}

function extractBlock(source, tagName, requiredAttribute = "") {
  const pattern = new RegExp(`<${tagName}\\b([^>]*)>([\\s\\S]*?)<\\/${tagName}>`, "gi");
  const matches = [];
  let match;
  while ((match = pattern.exec(source))) {
    const attrs = match[1] || "";
    if (!requiredAttribute || attrs.includes(requiredAttribute)) {
      matches.push({ attrs, body: match[2] });
    }
  }
  return matches;
}

const pkg = parseJson("package.json");
if (pkg) {
  assertOk(pkg.main === "app.js", "package.json main must be app.js like the official scaffold");
  assertOk(typeof pkg.name === "string" && pkg.name.length > 0, "package.json name is required");
}

const app = parseJson("app.json");
if (app) {
  assertOk(Array.isArray(app.pages), "app.json pages must be an array");
  assertOk(app.pages?.[0] === "pages/index/index", "first app.json page must be pages/index/index");
  assertOk(app.window && typeof app.window === "object", "app.json window config is required");
  assertOk(app.window?.viewport?.width === "device-width", "app.json window.viewport.width should be device-width");
}

assertOk(fs.existsSync(path.join(root, "AGENTS.md")), "AGENTS.md is required by the official scaffold");
assertOk(fs.existsSync(path.join(root, "app.js")), "app.js is required by the official scaffold");
assertOk(fs.existsSync(path.join(root, "pages/index/index.ink")), "pages/index/index.ink is required");

const ink = readText("pages/index/index.ink");
const defBlocks = extractBlock(ink, "script", "def");
const setupBlocks = extractBlock(ink, "script", "setup");
const pageBlocks = extractBlock(ink, "page");
const styleBlocks = extractBlock(ink, "style");

assertOk(defBlocks.length === 1, "index.ink must contain exactly one <script def> block");
assertOk(setupBlocks.length === 1, "index.ink must contain exactly one <script setup> block");
assertOk(pageBlocks.length === 1, "index.ink must contain exactly one <page> block");
assertOk(styleBlocks.length === 1, "index.ink must contain exactly one <style> block");

if (defBlocks[0]) {
  try {
    const def = JSON.parse(defBlocks[0].body);
    assertOk(typeof def.description === "string" && def.description.length > 20, "page def.description should describe the UI");
    assertOk(def.description.includes("任何一句话都必须调用本工具"), "page def.description must force all LaoK turns through the AIUI tool");
    assertOk(def.description.includes("不得让平台默认模型直接回答"), "page def.description must reject platform default-model answers");
    assertOk(def.schema?.data?.type === "object", "page def.schema.data.type must be object");
    assertOk(Array.isArray(def.schema?.data?.required) && def.schema.data.required.includes("utterance"), "schema.data.required must include utterance");
    assertOk(Array.isArray(def.schema?.data?.properties?.action?.enum), "schema.data.properties.action.enum is required");
    assertOk(def.schema.data.properties.action.enum.includes("connect"), "action enum must include connect for ordinary dialogue");
    assertOk(def.schema?.data?.properties?.statusText, "schema.data.properties.statusText is required");
    assertOk(def.schema?.data?.properties?.relayText, "schema.data.properties.relayText is required");
  } catch (error) {
    errors.push(`index.ink <script def> must be JSON: ${error.message}`);
  }
}

assertOk(ink.includes("import wx from 'wx'") || ink.includes('import wx from "wx"'), "index.ink must import wx from wx");
assertOk(ink.includes("wx.request"), "index.ink must use wx.request for bridge calls");
assertOk(ink.includes("https://agent.debetter.com/rokid-laok-native"), "index.ink must include the public HTTPS LaoK bridge endpoint");
assertOk(ink.includes("Authorization"), "index.ink must send bridge authorization for protected native capabilities");
assertOk(ink.includes("BRIDGE_ENDPOINTS"), "index.ink must use endpoint failover instead of a single LAN-only bridge URL");
assertOk(ink.includes("NATIVE_CONTRACT_VERSION"), "index.ink must send a native contract version for real-device observability");
assertOk(ink.includes("laok-aiui-native-contract-20260704-v2"), "index.ink must use the current native contract version");
assertOk(ink.includes("source: \"rokid_aiui_tool\""), "index.ink must identify AIUI tool-originated bridge calls");
assertOk(ink.includes("wx.createCameraContext"), "index.ink must prefer the official wx.createCameraContext API");
assertOk(ink.includes("wx.media.createCameraContext"), "index.ink should keep wx.media.createCameraContext as a compatibility fallback");
assertOk(ink.includes(".takePhoto("), "index.ink must call CameraContext.takePhoto");
assertOk(ink.includes("<camera"), "index.ink must include a <camera> preview element");
assertOk(ink.includes("onKeyDown(event)"), "index.ink should support hardware key input like official scanner sample");
assertOk(ink.includes("event?.code === \"Enter\""), "Enter key should trigger capture for glasses operation");
assertOk(ink.includes("wx.exitMiniProgram"), "Backspace should exit the full-screen AIUI page");

warnIf(/<button[^>]*\sdisabled=/.test(ink), "button disabled attribute is not documented in the current AIUI button component");
warnIf(ink.includes("fetch("), "fetch is not the documented AIUI networking path; use wx.request");

for (const relativePath of [
  "pages/index/page.json",
  "pages/index/page.js",
  "pages/index/page.wxml",
  "pages/index/page.wxss",
  "pages/index/index.js",
  "pages/index/index.wxml",
  "pages/index/index.wxss"
]) {
  assertOk(!fs.existsSync(path.join(root, relativePath)), `${relativePath} must not coexist with index.ink`);
}

const aixPath = path.join(root, "dist", "laok-native-vision-agent.aix");
if (fs.existsSync(aixPath)) {
  const bytes = fs.readFileSync(aixPath);
  const wasmPath = path.join(root, "node_modules", "@yodaos-pkg", "aix", "pkg", "aix_web_bg.wasm");
  await initAix({ module_or_path: fs.readFileSync(wasmPath) });
  const aix = new AixReaderWasm(new Uint8Array(bytes));
  const files = aix.list().map((entry) => entry.name);
  const pages = aix.get_pages();
  const tools = aix.get_tools();
  assertOk(aix.get_title() === app?.window?.navigationBarTitleText, "AIX title should match app.json window.navigationBarTitleText");
  assertOk(files.includes("pages/index/index.ink"), "AIX must include pages/index/index.ink");
  assertOk(!files.some((name) => name === ".git/" || name.startsWith(".git/")), "AIX must not include .git");
  assertOk(!files.some((name) => name === "node_modules/" || name.startsWith("node_modules/")), "AIX must not include node_modules");
  assertOk(!files.includes("package-lock.json"), "AIX must not include package-lock.json");
  assertOk(!files.some((name) => name === "tools/" || name.startsWith("tools/")), "AIX must not include build tools");
  assertOk(!files.some((name) => name === "dist/" || name.startsWith("dist/")), "AIX must not include previous dist output");
  assertOk(pages.some((page) => page.name === "pages/index/index"), "AIX getPages must expose pages/index/index");
  assertOk(tools.some((tool) => tool.function?.name === "pages/index/index"), "AIX getTools must expose pages/index/index");
} else {
  warnings.push("dist/laok-native-vision-agent.aix not found; run npm run pack:aix before release validation");
}

const result = { ok: errors.length === 0, errors, warnings };
console.log(JSON.stringify(result, null, 2));
process.exit(result.ok ? 0 : 1);
