/** Minimal Figma REST client — fetches a node subtree. Token from FIGMA_TOKEN. */

export interface FigmaPaint {
  type: string; visible?: boolean; opacity?: number;
  color?: { r: number; g: number; b: number; a: number };
}
export interface FigmaEffect {
  type: string;                          // DROP_SHADOW | INNER_SHADOW | LAYER_BLUR | …
  visible?: boolean;
  radius?: number;
  offset?: { x: number; y: number };
  color?: { r: number; g: number; b: number; a: number };
}
export interface FigmaNode {
  id: string; name: string; type: string;
  characters?: string;
  fills?: FigmaPaint[]; strokes?: FigmaPaint[];
  effects?: FigmaEffect[];
  cornerRadius?: number; rectangleCornerRadii?: number[];
  layoutMode?: "HORIZONTAL" | "VERTICAL" | "NONE";
  primaryAxisAlignItems?: "MIN" | "CENTER" | "MAX" | "SPACE_BETWEEN";
  counterAxisAlignItems?: "MIN" | "CENTER" | "MAX" | "BASELINE";
  itemSpacing?: number;
  paddingLeft?: number; paddingTop?: number; paddingRight?: number; paddingBottom?: number;
  componentId?: string;
  componentProperties?: Record<string, { type?: string; value: string | boolean }>;
  style?: { fontSize?: number; fontWeight?: number; lineHeightPx?: number };
  opacity?: number;
  visible?: boolean;
  absoluteBoundingBox?: { x: number; y: number; width: number; height: number } | null;
  children?: FigmaNode[];
}

/**
 * Parse a Figma file/design URL into { fileKey, nodeId }.
 * Accepts both `…/design/<key>/…` and `…/file/<key>/…` links, and normalises the
 * URL's dash-separated `node-id` (e.g. `25795-9030`) to the API/colon form
 * (`25795:9030`). Throws if either part can't be found.
 */
export function parseFigmaUrl(input: string): { fileKey: string; nodeId: string } {
  let url: URL;
  try { url = new URL(input.trim()); }
  catch { throw new Error(`not a valid Figma URL: "${input}"`); }

  const key = url.pathname.match(/\/(?:design|file)\/([^/]+)/)?.[1];
  if (!key) throw new Error(`could not find a fileKey in the URL (expected …/design/<key>/… or …/file/<key>/…)`);

  const raw = url.searchParams.get("node-id");
  if (!raw) throw new Error(`could not find a node-id in the URL (expected ?node-id=…). Use Figma's "Copy link to selection".`);
  const nodeId = decodeURIComponent(raw).replace(/-/g, ":");

  return { fileKey: decodeURIComponent(key), nodeId };
}

/**
 * Fetches temporary PNG export URLs for a set of node ids (Figma renders them
 * server-side). Used to hand icon/image assets to the user — the URLs expire
 * after ~14 days, so they belong in the report, never in generated code.
 */
export async function fetchFigmaImages(fileKey: string, nodeIds: string[], token: string, scale = 2): Promise<Record<string, string | null>> {
  const url = `https://api.figma.com/v1/images/${encodeURIComponent(fileKey)}?ids=${encodeURIComponent(nodeIds.join(","))}&format=png&scale=${scale}`;
  const res = await fetch(url, { headers: { "X-Figma-Token": token } });
  if (!res.ok) throw new Error(`Figma images API ${res.status}: ${await res.text().catch(() => res.statusText)}`);
  const json = (await res.json()) as { images?: Record<string, string | null> };
  return json.images ?? {};
}

export async function fetchFigmaNode(fileKey: string, nodeId: string, token: string): Promise<FigmaNode> {
  const url = `https://api.figma.com/v1/files/${encodeURIComponent(fileKey)}/nodes?ids=${encodeURIComponent(nodeId)}`;
  const res = await fetch(url, { headers: { "X-Figma-Token": token } });
  if (!res.ok) throw new Error(`Figma API ${res.status}: ${await res.text().catch(() => res.statusText)}`);
  const json = (await res.json()) as { nodes?: Record<string, { document?: FigmaNode }> };
  const doc = json.nodes?.[nodeId]?.document;
  if (!doc) throw new Error(`node "${nodeId}" not found in file "${fileKey}"`);
  return doc;
}
