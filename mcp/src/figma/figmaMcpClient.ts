/**
 * A thin MCP *client* so this server can call a **Figma MCP** server (Figma's
 * Dev Mode MCP, or any MCP that exposes get_design_context/get_code/get_metadata).
 *
 * MCP is hub-and-spoke — a server can't call a sibling server the agent connected.
 * So we open our OWN client connection to a Figma MCP endpoint:
 *   - FIGMA_MCP_URL  → Streamable HTTP (default http://127.0.0.1:3845/mcp, Figma Dev Mode)
 *   - FIGMA_MCP_CMD  → stdio (spawn a command; used for local/mock/testing)
 * The remote https://mcp.figma.com is OAuth-gated and NOT reachable this way — use
 * the desktop Dev Mode server (Figma ▸ Preferences ▸ Enable Dev Mode MCP server).
 */
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

export interface FigmaMcpConfig { url?: string; cmd?: string; }
export function figmaMcpConfig(): FigmaMcpConfig {
  return { url: process.env.FIGMA_MCP_URL, cmd: process.env.FIGMA_MCP_CMD };
}
export function figmaMcpConfigured(cfg = figmaMcpConfig()): boolean {
  return !!(cfg.url || cfg.cmd);
}

async function connect(cfg: FigmaMcpConfig): Promise<Client> {
  const client = new Client({ name: "themekit-mcp (as Figma MCP client)", version: "0.0.0" }, { capabilities: {} });
  if (cfg.cmd) {
    const [command, ...args] = cfg.cmd.split(" ").filter(Boolean);
    await client.connect(new StdioClientTransport({ command, args, env: { ...process.env } as Record<string, string> }));
  } else {
    const url = cfg.url || "http://127.0.0.1:3845/mcp";
    await client.connect(new StreamableHTTPClientTransport(new URL(url)));
  }
  return client;
}

const textOf = (res: any): string => (res?.content ?? []).map((c: any) => c?.text ?? "").filter(Boolean).join("\n");

/**
 * Ask the connected Figma MCP for a node's design context. Auto-discovers the
 * server's tool (get_design_context → get_code → get_metadata) and returns which
 * one answered plus its text. Throws a clear error if nothing is reachable.
 */
export async function getDesignContextViaMcp(
  fileKey: string,
  nodeId: string,
  cfg = figmaMcpConfig(),
): Promise<{ tool: string; text: string; serverName?: string }> {
  const client = await connect(cfg);
  try {
    const info = client.getServerVersion?.();
    const { tools } = await client.listTools();
    const names = tools.map((t) => t.name);
    const pick =
      ["get_design_context", "get_code", "get_metadata"].find((n) => names.includes(n)) ??
      names.find((n) => /design[_-]?context|get[_-]?code|metadata/i.test(n));
    if (!pick) throw new Error(`the Figma MCP exposes none of get_design_context/get_code/get_metadata (has: ${names.join(", ") || "no tools"})`);
    const res = await client.callTool({ name: pick, arguments: { fileKey, nodeId } });
    return { tool: pick, text: textOf(res), serverName: info?.name };
  } finally {
    await client.close().catch(() => {});
  }
}
