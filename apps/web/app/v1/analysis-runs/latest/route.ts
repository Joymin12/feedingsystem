import { NextResponse } from "next/server";
import { buildApiUrl } from "@/lib/config";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const formulaId = url.searchParams.get("formula_id");

  if (!formulaId) {
    return NextResponse.json({ message: "formula_id가 필요합니다." }, { status: 400 });
  }

  const comparisonResponse = await fetch(buildApiUrl(`/v1/formulas/${formulaId}/stage-comparison`), {
    cache: "no-store"
  });

  if (!comparisonResponse.ok) {
    return new NextResponse(await comparisonResponse.text(), {
      status: comparisonResponse.status,
      headers: {
        "content-type": comparisonResponse.headers.get("content-type") ?? "application/json"
      }
    });
  }

  const comparison = (await comparisonResponse.json()) as { representative_run_id?: string };

  if (!comparison.representative_run_id) {
    return NextResponse.json({ message: "대표 분석 실행이 아직 없습니다." }, { status: 404 });
  }

  const analysisResponse = await fetch(buildApiUrl(`/v1/analysis-runs/${comparison.representative_run_id}`), {
    cache: "no-store"
  });

  return new NextResponse(await analysisResponse.text(), {
    status: analysisResponse.status,
    headers: {
      "content-type": analysisResponse.headers.get("content-type") ?? "application/json"
    }
  });
}
