import { proxyApiRequest } from "@/lib/api-proxy";

export const runtime = "nodejs";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ formulaId: string }> }
) {
  const { formulaId } = await params;
  return proxyApiRequest(request, `/v1/formulas/${formulaId}`);
}

export async function PUT(
  request: Request,
  { params }: { params: Promise<{ formulaId: string }> }
) {
  const { formulaId } = await params;
  return proxyApiRequest(request, `/v1/formulas/${formulaId}`);
}
