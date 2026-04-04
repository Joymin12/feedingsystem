import { ButtonLink, HeroCard, MiniStat, Pill, SectionCard, StatusPill } from "@/components/chrome";
import { formatNumber, formatStageLabel, toneForStatus } from "@/lib/format";
import { getDashboardSnapshot } from "@/lib/server-api";

export default async function HomePage() {
  const snapshot = await getDashboardSnapshot();
  const representative = snapshot.workflow.analysis_run;
  const recommendation = snapshot.workflow.recommendation;

  return (
    <main>
      <div className="hero">
        <HeroCard
          eyebrow="운영 대시보드"
          title={`${snapshot.farmProfile.farm_name}의 기본 TMR 흐름`}
          description={`대표 분석은 ${formatStageLabel(snapshot.farmProfile.preferred_stage)} 기준으로 생성되고, 같은 formula를 다른 stage에 다시 계산한 비교 결과를 함께 보여 줍니다.`}
          actions={(
            <>
              <ButtonLink href="/farm" primary>농장 설정 보기</ButtonLink>
              <ButtonLink href={`/formulas/${snapshot.formula.formula_id}`}>기본 TMR 열기</ButtonLink>
            </>
          )}
        >
          <div className="pill-row" style={{ marginTop: 18 }}>
            <Pill>preferred_stage: {snapshot.farmProfile.preferred_stage}</Pill>
            <Pill>formula: {snapshot.formula.formula_name}</Pill>
            <Pill>두수 {formatNumber(snapshot.formula.animal_count)}</Pill>
            <Pill>목표 ADG {snapshot.formula.target_adg.toFixed(2)}kg</Pill>
          </div>
        </HeroCard>

        <aside className="hero-aside">
          <div className="stat-grid fade-in delay-1">
            <MiniStat label="대표 단계" value={formatStageLabel(representative.stage)} note="farm profile의 preferred_stage 기준입니다." />
            <MiniStat label="적정 항목" value={`${representative.adequate_count}개`} note="API가 계산한 adequate 개수를 그대로 표시합니다." />
            <MiniStat label="조정 필요" value={`${representative.deficient_count + representative.excess_count}개`} note="부족/과잉 합계를 빠르게 확인할 수 있습니다." />
            <MiniStat label="최근 실행" value={new Date(representative.created_at).toLocaleDateString("ko-KR")} note="대표 분석 결과가 stage comparison과 연결됩니다." />
          </div>
          <div className="quiet-panel fade-in delay-2">
            <div className="section-title">
              <div>
                <h3>운영 메모</h3>
                <p className="section-note">대표 결과와 비교 결과를 섞지 않고, 카드 단위로 분리해 읽게 했습니다.</p>
              </div>
            </div>
            <div className="pill-row">
              {snapshot.farmProfile.preferred_ingredients.map((item) => (
                <Pill key={item}>{item}</Pill>
              ))}
            </div>
          </div>
        </aside>
      </div>

      <section className="section-grid">
        <SectionCard title="농장 요약" note="preferred_stage와 운영 우선순위를 먼저 확인합니다." action={<StatusPill tone={snapshot.farmProfile.stability_priority >= snapshot.farmProfile.cost_priority ? "good" : "warn"}>안정성 {snapshot.farmProfile.stability_priority}</StatusPill>}>
          <div className="pill-row">
            <Pill>저장성 {snapshot.farmProfile.storage_level}</Pill>
            <Pill>습식 원료 정책 {snapshot.farmProfile.wet_feed_policy}</Pill>
            <Pill>비용 {snapshot.farmProfile.cost_priority}</Pill>
            <Pill>안정성 {snapshot.farmProfile.stability_priority}</Pill>
          </div>
          <p className="section-note" style={{ marginTop: 14 }}>{snapshot.farmProfile.notes}</p>
        </SectionCard>

        <SectionCard title="최근 대표 분석 결과" note="대표 단계 기준의 영양 상태와 자동 경고를 바로 봅니다.">
          <ul className="nutrient-list">
            {representative.nutrients.map((nutrient) => (
              <li key={nutrient.key} className="nutrient-row">
                <div className="row-label">
                  <strong>{nutrient.label}</strong>
                  <span>목표 {nutrient.min_target_value?.toFixed(1)} - {nutrient.max_target_value?.toFixed(1)}</span>
                </div>
                <div className="value-block">
                  <strong>{nutrient.current_value.toFixed(1)}</strong>
                  <span className={`status-pill ${toneForStatus(nutrient.status)}`}>{nutrient.status}</span>
                </div>
              </li>
            ))}
          </ul>
          <p className="helper" style={{ marginTop: 10 }}>{representative.summary}</p>
        </SectionCard>

        <SectionCard title="같은 formula 기준 단계 비교" note="preferred_stage를 중심으로 다른 단계의 부족/과잉 개수를 함께 비교합니다.">
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
                {snapshot.stageComparison.comparisons.map((row) => (
                  <tr key={row.stage} className={row.stage === snapshot.stageComparison.preferred_stage ? "table-row-strong" : undefined}>
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

        <SectionCard title="보유 원료 조정안" note="보유 원료 우선 원칙에 따라 1차 조정안을 분리해 보여 줍니다.">
          <ul className="adjustment-list">
            {recommendation.owned_ingredient_adjustments.map((item) => (
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

        <SectionCard title="외부 추천 원료" note="보유 원료만으로 부족을 메우기 어려울 때만 별도 후보를 제시합니다.">
          <ul className="issue-list">
            {recommendation.supplemental_suggestions.length ? recommendation.supplemental_suggestions.map((item) => (
              <li key={item.ingredient_id} className="issue-row">
                <div className="row-label">
                  <strong>{item.ingredient_name}</strong>
                  <span>{item.reason}</span>
                </div>
                {item.caution ? <span className="row-meta">{item.caution}</span> : null}
              </li>
            )) : <li className="row-meta">외부 원료가 필요한 수준의 부족은 없습니다.</li>}
          </ul>
        </SectionCard>
      </section>
    </main>
  );
}
