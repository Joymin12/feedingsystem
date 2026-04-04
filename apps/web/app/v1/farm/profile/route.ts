import { proxyApiRequest } from "@/lib/api-proxy";

export const runtime = "nodejs";

export async function GET(request: Request) {
  return proxyApiRequest(request, "/v1/farm/profile");
}

export async function PUT(request: Request) {
  return proxyApiRequest(request, "/v1/farm/profile");
}
