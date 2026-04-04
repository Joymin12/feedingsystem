import { ButtonLink, HeroCard, Pill, SectionCard, StatusPill } from "@/components/chrome";
import { formatStageLabel, toneForStatus } from "@/lib/format";
import { getAnalysisWorkflow } from "@/lib/server-api";

export default async function ResultPage({ params }: { params: Promise<{ runId: string }> }) {
  const { runId } = await params;
  const workflow = await getAnalysisWorkflow(runId);

  return (
    <main>
      <HeroCard
        eyebrow="대표 분석 결과"
        title={`${formatStageLabel(workflow.analysis_run.stage)} 기준 분석`}
        description="analysis_run은 preferred_stage 기준 대표 결과 1건을 유지하고, stage comparison은 같은 formula를 다른 단계로 다시 계산한 비교 응답으로 분리합니다."
        actions={<ButtonLink href={`/formulas/${workflow.analysis_run.formula_id}`}>formula로 돌아가기</ButtonLink>}
      >
        <div className="pill-row" style={{ marginTop: 18 }}>
          <Pill>run_id {workflow.analysis_run.run_id}</Pill>
          <Pill>preferred_stage {workflow.analysis_run.preferred_stage}</Pill>
          <Pill>부족 {workflow.analysis_run.deficient_count}</Pill>
          <Pill>과잉 {workflow.analysis_run.excess_count}</Pill>
        </div>
      </HeroCard>

      <section className="section-grid" style={{ marginTop: 20 }}>
        <SectionCard title="영양소 판정" note="프런트는 부족/적정/과잉을 다시 계산하지 않고 API 응답을 그대로 렌더링합니다." wide>
          <div className="comparison-table">
            <table>
              <thead>
                <tr>
                  <th>영양소</th>
                  <th>현재값</th>
                  <th>목표구간</th>
                  <th>상태</th>
                </tr>
              </thead>
              <tbody>
                {workflow.analysis_run.nutrients.map((nutrient) => (
                  <tr key={nutrient.key}>
                    <td>{nutrient.label}</td>
                    <td>{nutrient.current_value.toFixed(1)}</td>
                    <td>{nutrient.min_target_value?.toFixed(1)} - {nutrient.max_target_value?.toFixed(1)}</td>
                    <td><StatusPill tone={toneForStatus(nutrient.status)}>{nutrient.status}</StatusPill></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="helper" style={{ marginTop: 12 }}>{workflow.analysis_run.summary}</p>
        </SectionCard>

        <SectionCard title="자동 경고" note="계산 결과 해석 레이어에서만 경고 문구를 조합합니다.">
          <ul className="issue-list">
            {workflow.analysis_run.auto_warnings.length ? workflow.analysis_run.auto_warnings.map((warning) => (
              <li key={warning} className="issue-row">
                <div className="row-label">
                  <strong>주의</strong>
                  <span>{warning}</span>
                </div>
              </li>
            )) : <li className="row-meta">현재 자동 경고는 없습니다.</li>}
          </ul>
        </SectionCard>

        <SectionCard title="보유 원료 조정안" note="보유 원료 우선 원칙에 따라 1차 조정안을 별도 배열로 제공합니다.">
          <ul className="adjustment-list">
            {workflow.recommendation.owned_ingredient_adjustments.map((item) => (
              <li key={item.ingredient_id} className="adjustment-row">
                <div className="row-label">
                  <strong>{item.ingredient_name}</strong>
                  <span>{item.reason}</span>
                </div>
                <StatusPill tone={item.action === "increase" ? "good" : item.action === "decrease" ? "warn" : "good"}>{item.action}</StatusPill>
              </li>
            ))}
          </ul>
        </SectionCard>

        <SectionCard title="외부 추천 원료" note="보유 원료만으로 부족 대응이 어려운 경우에만 별도로 제시합니다.">
          <ul className="issue-list">
            {workflow.recommendation.supplemental_suggestions.length ? workflow.recommendation.supplemental_suggestions.map((item) => (
              <li key={item.ingredient_id} className="issue-row">
                <div className="row-label">
                  <strong>{item.ingredient_name}</strong>
                  <span>{item.reason}</span>
                </div>
                {item.caution ? <span className="row-meta">{item.caution}</span> : null}
              </li>
            )) : <li className="row-meta">외부 추천 원료는 없습니다.</li>}
          </ul>
        </SectionCard>

        <SectionCard title="단계별 비교" note="대표 결과와 비교 결과를 섞지 않고 stage summary만 따로 보여 줍니다." wide>
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
                {workflow.stage_comparison.comparisons.map((row) => (
                  <tr key={row.stage} className={row.stage === workflow.stage_comparison.preferred_stage ? "table-row-strong" : undefined}>
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
      </section>
    </main>
  );
}
