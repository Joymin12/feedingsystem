const DEFAULT_API_ORIGIN = "http://localhost:4000";

export function getApiOrigin(): string {
  return process.env.API_BASE_URL ?? DEFAULT_API_ORIGIN;
}

export function buildApiUrl(path: string): string {
  const origin = getApiOrigin().replace(/\/$/, "");
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${origin}${normalizedPath}`;
}
