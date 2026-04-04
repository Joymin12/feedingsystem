import { HeroCard, Pill, SectionCard } from "@/components/chrome";
import { FarmProfileForm } from "@/components/farm-profile-form";
import { formatStageLabel } from "@/lib/format";
import { getFarmProfile } from "@/lib/server-api";

export default async function FarmPage() {
  const profile = await getFarmProfile();

  return (
    <main>
      <HeroCard
        eyebrow="농장 설정"
        title="preferred_stage와 운영 기준"
        description="farm profile은 대표 분석 단계와 추천 해석의 기준점입니다. 여기서 바뀐 preferred_stage는 홈과 결과 화면 전반에 바로 반영됩니다."
      >
        <div className="pill-row" style={{ marginTop: 18 }}>
          <Pill>현재 단계 {formatStageLabel(profile.preferred_stage)}</Pill>
          <Pill>저장성 {profile.storage_level}</Pill>
          <Pill>습식 정책 {profile.wet_feed_policy}</Pill>
        </div>
      </HeroCard>

      <section className="section-grid" style={{ marginTop: 20 }}>
        <SectionCard title="농장 프로필 편집" note="preferred_stage는 필수값으로 유지합니다." wide>
          <FarmProfileForm initialValue={profile} />
        </SectionCard>
      </section>
    </main>
  );
}
