import type { Formula } from "@hanwoo-tmr/contracts";
import { ButtonLink, HeroCard, Pill, SectionCard } from "@/components/chrome";
import { FormulaForm } from "@/components/formula-form";
import { formatStageLabel } from "@/lib/format";
import { getFarmProfile, getFormula, getStageComparison } from "@/lib/server-api";

function createEmptyFormula(farmId: string): Formula {
  const now = new Date().toISOString();

  return {
    formula_id: "new",
    farm_id: farmId,
    formula_name: "새 기본 TMR",
    stage: "fattening_mid",
    average_weight_kg: 540,
    animal_count: 80,
    target_adg: 1,
    items: [],
    notes: "",
    created_at: now,
    updated_at: now
  };
}

export default async function FormulaDetailPage({ params }: { params: Promise<{ formulaId: string }> }) {
  const { formulaId } = await params;
  const farmProfile = await getFarmProfile();
  const formula = formulaId === "new" ? createEmptyFormula(farmProfile.farm_id) : await getFormula(formulaId);
  const stageComparison = formulaId === "new" ? null : await getStageComparison(formula.formula_id);

  return (
    <main>
      <HeroCard
        eyebrow="기본 TMR 편집"
        title={formula.formula_name}
        description="formula를 저장한 뒤 대표 분석을 생성하면 preferred_stage 기준 결과와 단계 비교를 함께 확인할 수 있습니다."
        actions={formulaId !== "new" && stageComparison?.representative_run_id ? <ButtonLink href={`/results/${stageComparison.representative_run_id}`}>최근 결과 보기</ButtonLink> : undefined}
      >
        <div className="pill-row" style={{ marginTop: 18 }}>
          <Pill>단계 {formatStageLabel(formula.stage)}</Pill>
          <Pill>preferred_stage {formatStageLabel(farmProfile.preferred_stage)}</Pill>
          <Pill>원료 {formula.items.length}종</Pill>
        </div>
      </HeroCard>

      <section className="section-grid" style={{ marginTop: 20 }}>
        <SectionCard title="formula 편집" note="저장 모델 이름은 formula를 유지하고, 화면에서는 기본 TMR로 안내합니다." wide>
          <FormulaForm initialValue={formula} />
        </SectionCard>

        {stageComparison ? (
          <SectionCard title="현재 stage comparison" note="저장된 formula를 전 stage 기준으로 다시 계산한 비교 요약입니다." wide>
            <div className="comparison-table">
              <table>
                <thead>
                  <tr>
                    <th>단계</th>
                    <th>부족</th>
                    <th>적정</th>
                    <th>과잉</th>
                  </tr>
                </thead>
                <tbody>
                  {stageComparison.comparisons.map((row) => (
                    <tr key={row.stage} className={row.stage === stageComparison.preferred_stage ? "table-row-strong" : undefined}>
                      <td>{formatStageLabel(row.stage)}</td>
                      <td>{row.deficient_count}</td>
                      <td>{row.adequate_count}</td>
                      <td>{row.excess_count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </SectionCard>
        ) : null}
      </section>
    </main>
  );
}
