import type { FarmProfile, Ingredient, Recommendation } from "@feedingsystem/contracts";

export function buildReasonText(
  ingredient: Ingredient,
  nutrientFocus: string[],
  farmProfile: FarmProfile,
): string {
  const focusText = nutrientFocus.join(", ");
  const storageBias =
    farmProfile.storage_level === "high" ? "저장성 우선 조건을 함께 고려했고" : "현재 배합 균형을 우선 고려했고";

  return `${ingredient.name_ko}는 ${focusText} 보강에 유리하며, ${storageBias} ${ingredient.ai_profile.benefits[0] ?? "현장 적용성이 좋은 후보"}로 판단했습니다.`;
}

export function buildCautionText(ingredient: Ingredient): string {
  return ingredient.ai_profile.cautions[0] ?? "급격한 배합 변경은 피하고 현장 상태를 함께 확인해야 합니다.";
}

export function buildAlternativeText(
  recommendation: Recommendation,
  alternatives: Ingredient[],
): string {
  const alternative = alternatives.find(
    (ingredient) => ingredient.ingredient_id !== recommendation.ingredient_id,
  );

  return alternative
    ? `대체안으로 ${alternative.name_ko}를 검토할 수 있습니다.`
    : "대체안은 같은 원료군 내 저단가 또는 보유 재고 원료를 우선 검토하세요.";
}
