import { proxyApiRequest } from "@/lib/api-proxy";

export const runtime = "nodejs";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ runId: string }> }
) {
  const { runId } = await params;
  return proxyApiRequest(request, `/v1/analysis-runs/${runId}`);
}
