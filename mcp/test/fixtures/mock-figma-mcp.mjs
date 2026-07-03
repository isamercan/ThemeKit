// A tiny mock "Figma MCP" server over stdio, used to verify that the themekit
// server can act as an MCP *client* and pull design context. Registers a single
// tool whose name comes from MOCK_TOOL (default get_design_context).
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const toolName = process.env.MOCK_TOOL || "get_design_context";
const server = new McpServer({ name: "mock-figma-mcp", version: "1.0.0" });

server.registerTool(
  toolName,
  { title: toolName, description: "mock design context", inputSchema: { fileKey: z.string(), nodeId: z.string() } },
  async ({ fileKey, nodeId }) => ({
    content: [{ type: "text", text: `<${toolName}> ref for ${fileKey}:${nodeId} — <p>E-posta adresi</p>` }],
  }),
);

await server.connect(new StdioServerTransport());
