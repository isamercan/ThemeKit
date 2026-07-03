// Verifies the themekit server can act as an MCP *client* of a Figma MCP server
// (spawned over stdio) — proving "our MCP calls the Figma MCP" end-to-end.
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { getDesignContextViaMcp, figmaMcpConfigured } from "../dist/figma/figmaMcpClient.js";

const mock = fileURLToPath(new URL("./fixtures/mock-figma-mcp.mjs", import.meta.url));
const cmd = `node ${mock}`;

test("figmaMcpConfigured reflects FIGMA_MCP_URL / FIGMA_MCP_CMD", () => {
  assert.equal(figmaMcpConfigured({}), false);
  assert.equal(figmaMcpConfigured({ url: "http://127.0.0.1:3845/mcp" }), true);
  assert.equal(figmaMcpConfigured({ cmd: "node x.mjs" }), true);
});

test("calls a Figma MCP over stdio and returns its get_design_context reference", async () => {
  delete process.env.MOCK_TOOL; // default → get_design_context
  const { tool, text, serverName } = await getDesignContextViaMcp("FILEKEY", "25795:9030", { cmd });
  assert.equal(tool, "get_design_context");
  assert.equal(serverName, "mock-figma-mcp");
  assert.match(text, /ref for FILEKEY:25795:9030/);
  assert.match(text, /E-posta adresi/); // the real override surfaces, unlike our REST path
});

test("auto-discovers the tool: falls back to get_metadata when that's all the server offers", async () => {
  process.env.MOCK_TOOL = "get_metadata";
  try {
    const { tool, text } = await getDesignContextViaMcp("FK", "1:2", { cmd });
    assert.equal(tool, "get_metadata");
    assert.match(text, /<get_metadata>/);
  } finally {
    delete process.env.MOCK_TOOL;
  }
});

test("a Figma MCP exposing none of the read tools errors clearly", async () => {
  process.env.MOCK_TOOL = "some_unrelated_tool";
  try {
    await assert.rejects(
      () => getDesignContextViaMcp("FK", "1:2", { cmd }),
      /exposes none of get_design_context/,
    );
  } finally {
    delete process.env.MOCK_TOOL;
  }
});
