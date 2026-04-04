import { proxyApiRequest } from "@/lib/api-proxy";

export const runtime = "nodejs";

export async function POST(request: Request) {
  return proxyApiRequest(request, "/v1/analysis-runs");
}
