/** Minimal Figma REST client — fetches a node subtree. Token from FIGMA_TOKEN. */

export interface FigmaPaint {
  type: string; visible?: boolean; opacity?: number;
  color?: { r: number; g: number; b: number; a: number };
}
export interface FigmaNode {
  id: string; name: string; type: string;
  characters?: string;
  fills?: FigmaPaint[]; strokes?: FigmaPaint[];
  cornerRadius?: number; rectangleCornerRadii?: number[];
  layoutMode?: "HORIZONTAL" | "VERTICAL" | "NONE";
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

export async function fetchFigmaNode(fileKey: string, nodeId: string, token: string): Promise<FigmaNode> {
  const url = `https://api.figma.com/v1/files/${encodeURIComponent(fileKey)}/nodes?ids=${encodeURIComponent(nodeId)}`;
  const res = await fetch(url, { headers: { "X-Figma-Token": token } });
  if (!res.ok) throw new Error(`Figma API ${res.status}: ${await res.text().catch(() => res.statusText)}`);
  const json = (await res.json()) as { nodes?: Record<string, { document?: FigmaNode }> };
  const doc = json.nodes?.[nodeId]?.document;
  if (!doc) throw new Error(`node "${nodeId}" not found in file "${fileKey}"`);
  return doc;
}
