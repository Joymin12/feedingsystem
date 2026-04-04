import { NextResponse } from "next/server";
import { buildApiUrl } from "@/lib/config";

/**
 * 웹 클라이언트는 항상 같은 오리진의 `/v1/*`만 호출하고,
 * 실제 백엔드 주소는 Next route handler가 숨긴다.
 * 덕분에 브라우저 CORS 설정을 단순하게 유지하면서 Android는 추후 API를 직접 재사용할 수 있다.
 */
export async function proxyApiRequest(request: Request, path: string): Promise<NextResponse> {
  const hasBody = request.method !== "GET" && request.method !== "HEAD";
  const body = hasBody ? await request.text() : undefined;
  const response = await fetch(buildApiUrl(path), {
    method: request.method,
    headers: {
      "content-type": "application/json"
    },
    body,
    cache: "no-store"
  });

  return new NextResponse(await response.text(), {
    status: response.status,
    headers: {
      "content-type": response.headers.get("content-type") ?? "application/json"
    }
  });
}
