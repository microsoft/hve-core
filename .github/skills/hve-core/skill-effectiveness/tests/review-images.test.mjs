// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import fs from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { decodeImage, LIMITS, preflightReview, reviewImages } from "../scripts/review-images.mjs";

const runtime = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const png = Buffer.from("89504e470d0a1a0a", "hex");
const jpeg = Buffer.from("ffd8ff", "hex");
const decode = async () => ({ width: 1, height: 1 });
const never = () => new Promise(() => {});

function fixture(t) {
  const root = fs.mkdtempSync(join(runtime, ".native-package-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.writeFileSync(join(root, "request.md"), "Assess visible labels.");
  fs.writeFileSync(join(root, "source.png"), png);
  const input = {
    model: "mock", artifactRoot: root, promptPath: "request.md",
    destination: join(root, "review"), imagePaths: ["source.png"],
  };
  return { root, input, record: () => JSON.parse(fs.readFileSync(join(input.destination, "record.json"), "utf8")) };
}

function sdk(stage = "") {
  const calls = [], handlers = {};
  const session = {
    sessionId: "observed-session",
    on: (name, handler) => { handlers[name] = handler; },
    abort: async () => {
      calls.push("abort");
      if (stage === "abort-hang") return never();
    },
    sendAndWait: async message => {
      calls.push(message);
      handlers["assistant.usage"]({ data: { model: "observed-model", inputTokens: 12, outputTokens: 6 } });
      if (stage === "response-hang") return never();
      if (["request-error", "abort-hang", "stop-hang", "combined"].includes(stage)) throw new Error("request failed");
      if (stage === "session-error") handlers["session.error"]({ data: { message: "session error" } });
      return { data: { content: stage === "empty" ? "" : "Image 1: synthetic review." } };
    },
  };
  const client = {
    start: async () => { calls.push("start"); if (stage === "start-hang") return never(); },
    listModels: async () => {
      calls.push("models");
      if (stage === "models-hang") return never();
      return [{ id: "mock", capabilities: { supports: { vision: stage !== "no-vision" } } }];
    },
    createSession: async config => {
      calls.push("session");
      assert.deepEqual(config.availableTools, []);
      assert.equal(config.onPermissionRequest().kind, "reject");
      assert.equal(config.infiniteSessions.enabled, false);
      if (stage === "session-hang") return never();
      return session;
    },
    stop: async () => {
      calls.push("stop");
      if (stage === "stop-hang") return never();
      return ["cleanup-error", "combined"].includes(stage) ? [new Error("cleanup failed")] : [];
    },
  };
  return { client, calls };
}

test("image review attaches only preflight bytes and records identity, usage and cleanup", async t => {
  const f = fixture(t), mock = sdk();
  const record = await reviewImages(f.input, { decode, createClient: () => mock.client });
  assert.equal(record.status, "completed");
  assert.equal(record.sessionId, "observed-session");
  assert.equal(record.usage[0].model, "observed-model");
  assert.equal(record.cleanup.shutdownConfirmed, true);
  assert.equal(record.startupTimeoutMs, 30000);
  assert.equal(record.lifecycleTimeoutMs, 10000);
  assert.equal(record.timeoutMs, 120000);
  const message = mock.calls.find(call => typeof call === "object");
  assert.deepEqual(Buffer.from(message.attachments[0].data, "base64"), png);
  assert.equal(message.attachments[0].displayName, "image-1.png");
  assert.equal(record.images[0].sha256, createHash("sha256").update(png).digest("hex"));
  assert.deepEqual(fs.readFileSync(join(f.input.destination, "image-1.png")), png);
});

test("image count, prompt and individual image bytes enforce exact and one-over boundaries", async t => {
  const f = fixture(t);
  const preflight = () => preflightReview(f.input, decode);
  fs.writeFileSync(join(f.root, "request.md"), "x".repeat(LIMITS.promptBytes));
  await preflight();
  fs.appendFileSync(join(f.root, "request.md"), "x");
  await assert.rejects(preflight(), /byte limit/);
  fs.writeFileSync(join(f.root, "request.md"), "request");
  f.input.imagePaths = Array(LIMITS.images).fill("source.png");
  await preflight();
  f.input.imagePaths.push("source.png");
  await assert.rejects(preflight(), /Image count/);
  f.input.imagePaths = ["source.png"];
  const fd = fs.openSync(join(f.root, "source.png"), "r+");
  fs.ftruncateSync(fd, LIMITS.imageBytes);
  fs.closeSync(fd);
  await preflight();
  const sparse = fs.openSync(join(f.root, "source.png"), "r+");
  fs.ftruncateSync(sparse, LIMITS.imageBytes + 1);
  fs.closeSync(sparse);
  await assert.rejects(preflight(), /byte limit/);
});

test("aggregate bytes and base64 amplification enforce exact and one-over limits", async t => {
  const f = fixture(t);
  const image = Buffer.alloc(LIMITS.totalBytes / LIMITS.images);
  png.copy(image);
  fs.writeFileSync(join(f.root, "source.png"), image);
  f.input.imagePaths = Array(LIMITS.images).fill("source.png");
  const accepted = await preflightReview(f.input, decode);
  assert.equal(accepted.images.reduce((n, item) => n + item.bytes.length, 0), LIMITS.totalBytes);
  assert.equal(accepted.images.reduce((n, item) => n + 4 * Math.ceil(item.bytes.length / 3), 0), LIMITS.base64Bytes);
  fs.writeFileSync(join(f.root, "larger.png"), Buffer.concat([image, Buffer.from([0])]));
  f.input.imagePaths[0] = "larger.png";
  await assert.rejects(preflightReview(f.input, decode), /Aggregate\/base64/);
  fs.writeFileSync(join(f.root, "smaller.png"), image.subarray(0, image.length - 1));
  f.input.imagePaths[1] = "smaller.png";
  assert.equal((image.length + 1) + (image.length - 1) + 6 * image.length, LIMITS.totalBytes);
  await assert.rejects(preflightReview(f.input, decode), /Aggregate\/base64/);
});

test("dimensions, individual and aggregate decoded pixels are bounded before SDK contact", async t => {
  const f = fixture(t);
  for (const size of [{ width: 8192, height: 2048 }, { width: 2048, height: 8192 }, { width: 4096, height: 4096 }]) {
    await preflightReview(f.input, async () => size);
  }
  for (const size of [{ width: 8193, height: 1 }, { width: 1, height: 8193 }, { width: 4096, height: 4097 }]) {
    await assert.rejects(preflightReview(f.input, async () => size), /dimension\/pixel/);
  }
  f.input.imagePaths = ["source.png", "source.png"];
  await preflightReview(f.input, async () => ({ width: 4096, height: 4096 }));
  f.input.imagePaths.push("source.png");
  let count = 0;
  await assert.rejects(preflightReview(f.input, async () => ++count < 3
    ? { width: 4096, height: 4096 } : { width: 1, height: 1 }), /Aggregate decoded pixels/);
});

test("invalid signatures, decoder failures and outside-root inputs persist minimal failures without SDK contact", async t => {
  for (const scenario of ["signature", "decode", "outside", "directory", "empty", "utf8"]) {
    const f = fixture(t);
    let contacted = false;
    if (scenario === "signature") fs.writeFileSync(join(f.root, "source.png"), "not an image");
    if (scenario === "outside") f.input.imagePaths = ["../outside.png"];
    if (scenario === "directory") f.input.imagePaths = ["."];
    if (scenario === "empty") fs.writeFileSync(join(f.root, "source.png"), "");
    if (scenario === "utf8") fs.writeFileSync(join(f.root, "request.md"), Buffer.from([255]));
    await assert.rejects(reviewImages(f.input, {
      decode: scenario === "decode" ? async () => { throw new Error("truncated image"); } : decode,
      createClient: () => { contacted = true; throw new Error("must not start"); },
    }));
    assert.equal(contacted, false);
    assert.equal(f.record().status, "error");
    assert.equal(f.record().promptSha256, null);
    assert.deepEqual(fs.readdirSync(f.input.destination), ["record.json"]);
  }
});

test("directory links/junctions and input replacement races reject before disclosure", async t => {
  const f = fixture(t);
  fs.mkdirSync(join(f.root, "actual"));
  fs.writeFileSync(join(f.root, "actual", "image.png"), png);
  fs.symlinkSync(join(f.root, "actual"), join(f.root, "linked"), process.platform === "win32" ? "junction" : "dir");
  f.input.imagePaths = ["linked/image.png"];
  await assert.rejects(preflightReview(f.input, decode), /Links and junctions/);
  f.input.imagePaths = ["source.png"];
  const replacement = join(f.root, "replacement.png");
  fs.writeFileSync(replacement, png);
  const open = fs.openSync;
  const read = fs.readSync;
  let descriptor, reads = 0;
  t.mock.method(fs, "openSync", (file, ...args) => {
    const handle = open(file, ...args);
    if (file === join(f.root, "source.png") && descriptor === undefined) {
      descriptor = handle;
      fs.renameSync(file, join(f.root, "original.png"));
      fs.copyFileSync(replacement, file, fs.constants.COPYFILE_EXCL);
    }
    return handle;
  });
  t.mock.method(fs, "readSync", (...args) => {
    if (args[0] === descriptor) reads++;
    return read(...args);
  });
  await assert.rejects(preflightReview(f.input, decode), /changed before reading/);
  assert.equal(reads, 0);
  assert.throws(() => fs.fstatSync(descriptor), /EBADF/);
});

test("reading detects content mutation without treating change-time-only updates as replacement", async t => {
  const f = fixture(t), fstat = fs.fstatSync, read = fs.readSync;
  t.mock.method(fs, "fstatSync", (...args) => {
    const stat = fstat(...args);
    stat.ctimeNs += 1n;
    return stat;
  });
  await preflightReview(f.input, decode);
  let mutated = false;
  t.mock.method(fs, "readSync", (...args) => {
    const count = read(...args);
    if (!mutated) {
      mutated = true;
      fs.appendFileSync(join(f.root, "request.md"), "changed");
    }
    return count;
  });
  await assert.rejects(preflightReview(f.input, decode), /changed during reading/);
});

test("file links and unavailable file identities never silently fall back", async t => {
  const f = fixture(t);
  await t.test("file symlink", async child => {
    try { fs.symlinkSync(join(f.root, "source.png"), join(f.root, "link.png")); } catch (error) {
      if (process.platform === "win32" && error.code === "EPERM") return child.skip("Windows file-symlink privilege unavailable");
      throw error;
    }
    await assert.rejects(preflightReview({ ...f.input, imagePaths: ["link.png"] }, decode), /Links and junctions|ELOOP/);
  });
  const lstat = fs.lstatSync;
  const missingPathIdentity = t.mock.method(fs, "lstatSync", (file, options) => {
    const result = lstat(file, options);
    if (options?.bigint && file === join(f.root, "source.png")) result.ino = 0n;
    return result;
  });
  await assert.rejects(preflightReview(f.input, decode), /supported identity/);
  missingPathIdentity.mock.restore();
  const fstat = fs.fstatSync;
  t.mock.method(fs, "fstatSync", (...args) => {
    const result = fstat(...args);
    result.ino = 0n;
    return result;
  });
  await assert.rejects(preflightReview(f.input, decode), /supported identity/);
});

test("startup has a separate bounded deadline without extending other lifecycle waits", async t => {
  const f = fixture(t), mock = sdk();
  mock.client.start = async () => {
    mock.calls.push("start");
    await new Promise(resolve => setTimeout(resolve, 100));
  };
  const record = await reviewImages(f.input, {
    decode, createClient: () => mock.client, timeoutMs: 50, startupTimeoutMs: 500,
  });
  assert.equal(record.status, "completed");
  assert.equal(record.startupTimeoutMs, 500);
  assert.equal(record.lifecycleTimeoutMs, 50);
  assert.equal(record.cleanup.shutdownConfirmed, true);
  for (const startupTimeoutMs of [0, -1, NaN, Infinity, 30001]) {
    await assert.rejects(reviewImages(f.input, { decode, startupTimeoutMs }), /Invalid review startup timeout/);
  }
  const inventory = fixture(t), hanging = sdk("models-hang");
  await assert.rejects(reviewImages(inventory.input, {
    decode, createClient: () => hanging.client, timeoutMs: 15, startupTimeoutMs: 500,
  }), /model inventory timed out/);
  assert.equal(inventory.record().lifecycleTimeoutMs, 15);
  assert.equal(inventory.record().cleanup.shutdownConfirmed, false);
});

test("hung lifecycle operations remain bounded; request, cleanup and persistence failures remain together", { timeout: 15000 }, async t => {
  const hung = fixture(t);
  await assert.rejects(reviewImages(hung.input, { decode, createClient: never, timeoutMs: 15 }), /client creation timed out/);
  assert.equal(hung.record().cleanup.shutdownConfirmed, false);
  for (const stage of ["start-hang", "models-hang", "session-hang", "response-hang", "abort-hang", "stop-hang",
    "request-error", "session-error", "empty", "cleanup-error", "no-vision"]) {
    const f = fixture(t), mock = sdk(stage);
    await assert.rejects(reviewImages(f.input, {
      decode, createClient: () => mock.client, timeoutMs: 15, startupTimeoutMs: 15, responseTimeoutMs: 15,
    }), AggregateError);
    const record = f.record();
    assert.equal(record.status, "error");
    assert.ok(mock.calls.includes("stop"));
    if (stage.endsWith("-hang")) assert.equal(record.cleanup.shutdownConfirmed, false);
    if (stage === "start-hang") {
      assert.ok(record.errors.some(error => /startup timed out/.test(error)));
      assert.equal(mock.calls.includes("session"), false);
    }
  }
  const f = fixture(t), mock = sdk("combined"), rename = fs.renameSync;
  let writes = 0;
  t.mock.method(fs, "renameSync", (...args) => {
    if (++writes === 3) throw new Error("terminal persistence failed");
    return rename(...args);
  });
  await assert.rejects(reviewImages(f.input, { decode, createClient: () => mock.client }), error => {
    for (const message of ["request failed", "cleanup failed", "terminal persistence failed"]) {
      assert.ok(error.errors.some(failure => failure.message === message));
      assert.ok(error.message.includes(message));
    }
    return true;
  });
  assert.equal(f.record().status, "started");
  assert.equal(fs.readdirSync(f.input.destination).some(name => name.endsWith(".tmp")), false);
});

test("existing output is never overwritten and JPEG uses its original bytes", async t => {
  const f = fixture(t);
  fs.mkdirSync(f.input.destination);
  fs.writeFileSync(join(f.input.destination, "keep"), "original");
  await assert.rejects(reviewImages(f.input, { decode }), /EEXIST/);
  assert.equal(fs.readFileSync(join(f.input.destination, "keep"), "utf8"), "original");
  fs.writeFileSync(join(f.root, "source.jpg"), jpeg);
  let received;
  const result = await preflightReview({ ...f.input, imagePaths: ["source.jpg"] }, async (bytes, format) => {
    received = { bytes, format };
    return { width: 1, height: 1 };
  });
  assert.equal(received.format, "jpeg");
  assert.deepEqual(received.bytes, jpeg);
  assert.equal(result.images[0].mimeType, "image/jpeg");
});

test("installed Sharp fully decodes PNG/JPEG and rejects truncated media", async t => {
  let sharp;
  try { ({ default: sharp } = await import("sharp")); } catch (error) {
    if (error.code === "ERR_MODULE_NOT_FOUND") return t.skip("Decoder restore and actual codec validation deferred to P04-T02");
    throw error;
  }
  for (const format of ["png", "jpeg"]) {
    const bytes = await sharp({ create: { width: 2, height: 3, channels: 3, background: "white" } })[format]().toBuffer();
    assert.deepEqual(await decodeImage(bytes, format), { width: 2, height: 3 });
    await assert.rejects(decodeImage(bytes.subarray(0, Math.floor(bytes.length / 2)), format));
  }
});
