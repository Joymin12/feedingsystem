"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import {
  stageLabelMap,
  stageValues,
  type FarmProfile,
  type UpdateFarmProfileRequest
} from "@hanwoo-tmr/contracts";
import { AccentButton, NeutralButton } from "@/components/chrome";
import { api } from "@/lib/api-client";

function toEditableProfile(profile: FarmProfile): UpdateFarmProfileRequest {
  return {
    farm_name: profile.farm_name,
    storage_level: profile.storage_level,
    wet_feed_policy: profile.wet_feed_policy,
    cost_priority: profile.cost_priority,
    stability_priority: profile.stability_priority,
    notes: profile.notes,
    preferred_ingredients: profile.preferred_ingredients,
    avoided_ingredients: profile.avoided_ingredients,
    preferred_stage: profile.preferred_stage
  };
}

/**
 * 농장 설정은 preferred_stage를 포함한 운영 기준점이다.
 * 프런트는 문자열 배열을 콤마 입력으로만 다루고,
 * 저장 직전에 contracts 형태로 정규화해서 API로 넘긴다.
 */
export function FarmProfileForm({ initialValue }: { initialValue: FarmProfile }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [form, setForm] = useState<UpdateFarmProfileRequest>(() => toEditableProfile(initialValue));
  const [preferredIngredientsText, setPreferredIngredientsText] = useState(form.preferred_ingredients?.join(", ") ?? "");
  const [avoidedIngredientsText, setAvoidedIngredientsText] = useState(form.avoided_ingredients?.join(", ") ?? "");

  function updateField<K extends keyof UpdateFarmProfileRequest>(
    key: K,
    value: UpdateFarmProfileRequest[K]
  ) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  function reset() {
    const nextValue = toEditableProfile(initialValue);
    setForm(nextValue);
    setPreferredIngredientsText(nextValue.preferred_ingredients?.join(", ") ?? "");
    setAvoidedIngredientsText(nextValue.avoided_ingredients?.join(", ") ?? "");
  }

  function submit() {
    startTransition(async () => {
      await api.updateFarmProfile({
        ...form,
        preferred_ingredients: preferredIngredientsText
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean),
        avoided_ingredients: avoidedIngredientsText
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean)
      });
      router.refresh();
    });
  }

  return (
    <div className="form-panel">
      <div className="form-grid">
        <label className="field full">
          <span>농장명</span>
          <input value={form.farm_name ?? ""} onChange={(event) => updateField("farm_name", event.target.value)} />
        </label>
        <label className="field">
          <span>저장성 수준</span>
          <select value={form.storage_level ?? "medium"} onChange={(event) => updateField("storage_level", event.target.value as NonNullable<UpdateFarmProfileRequest["storage_level"]>)}>
            <option value="low">낮음</option>
            <option value="medium">중간</option>
            <option value="high">높음</option>
          </select>
        </label>
        <label className="field">
          <span>습식 원료 정책</span>
          <select value={form.wet_feed_policy ?? "limited"} onChange={(event) => updateField("wet_feed_policy", event.target.value as NonNullable<UpdateFarmProfileRequest["wet_feed_policy"]>)}>
            <option value="avoid">회피</option>
            <option value="limited">제한</option>
            <option value="preferred">선호</option>
          </select>
        </label>
        <label className="field">
          <span>비용 우선도</span>
          <input type="number" min={0} max={100} value={form.cost_priority ?? 0} onChange={(event) => updateField("cost_priority", Number(event.target.value))} />
        </label>
        <label className="field">
          <span>안정성 우선도</span>
          <input type="number" min={0} max={100} value={form.stability_priority ?? 0} onChange={(event) => updateField("stability_priority", Number(event.target.value))} />
        </label>
        <label className="field">
          <span>preferred_stage</span>
          <select value={form.preferred_stage ?? "fattening_mid"} onChange={(event) => updateField("preferred_stage", event.target.value as NonNullable<UpdateFarmProfileRequest["preferred_stage"]>)}>
            {stageValues.map((stage) => (
              <option key={stage} value={stage}>
                {stageLabelMap[stage]}
              </option>
            ))}
          </select>
        </label>
        <label className="field full">
          <span>선호 원료</span>
          <input value={preferredIngredientsText} onChange={(event) => setPreferredIngredientsText(event.target.value)} placeholder="예: corn_silage, soybean_meal" />
        </label>
        <label className="field full">
          <span>회피 원료</span>
          <input value={avoidedIngredientsText} onChange={(event) => setAvoidedIngredientsText(event.target.value)} placeholder="예: cottonseed_hull" />
        </label>
        <label className="field full">
          <span>메모</span>
          <textarea value={form.notes ?? ""} onChange={(event) => updateField("notes", event.target.value)} />
        </label>
      </div>
      <div className="form-actions">
        <AccentButton type="button" onClick={submit}>{isPending ? "저장 중..." : "농장 설정 저장"}</AccentButton>
        <NeutralButton type="button" onClick={reset}>초기값으로 되돌리기</NeutralButton>
      </div>
    </div>
  );
}