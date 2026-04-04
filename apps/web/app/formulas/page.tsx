import { ButtonLink, HeroCard, Pill, SectionCard } from "@/components/chrome";
import { formatNumber, formatStageLabel } from "@/lib/format";
import { listFormulas } from "@/lib/server-api";

export default async function FormulasPage() {
  const formulas = await listFormulas();

  return (
    <main>
      <HeroCard
        eyebrow="Formula 목록"
        title="기본 TMR 저장과 분석 진입점"
        description="내부 저장 모델은 formula를 유지하고, 화면 문구에서는 기본 TMR로 안내합니다. 저장 후 분석 버튼을 통해 대표 분석을 바로 생성할 수 있습니다."
        actions={<ButtonLink href="/formulas/new" primary>새 기본 TMR 만들기</ButtonLink>}
      />

      <section className="section-grid" style={{ marginTop: 20 }}>
        {formulas.map((formula) => (
          <SectionCard key={formula.formula_id} title={formula.formula_name} note={`${formatStageLabel(formula.stage)} 기준으로 저장된 formula`}>
            <div className="pill-row">
              <Pill>체중 {formatNumber(formula.average_weight_kg)}kg</Pill>
              <Pill>두수 {formatNumber(formula.animal_count)}</Pill>
              <Pill>목표 ADG {formula.target_adg.toFixed(2)}kg</Pill>
              <Pill>원료 {formula.items.length}종</Pill>
            </div>
            <p className="section-note" style={{ marginTop: 14 }}>{formula.notes}</p>
            <div className="form-actions">
              <ButtonLink href={`/formulas/${formula.formula_id}`} primary>편집</ButtonLink>
            </div>
          </SectionCard>
        ))}
      </section>
    </main>
  );
}
