import { nutrientLabelMap, stageLabelMap, type NutrientStatus, type Stage } from "@hanwoo-tmr/contracts";

export function formatStageLabel(stage: Stage) {
  return stageLabelMap[stage];
}

export function formatNutrientLabel(key: keyof typeof nutrientLabelMap) {
  return nutrientLabelMap[key];
}

export function formatPercent(value: number, digits = 1) {
  return `${value.toFixed(digits)}%`;
}

export function formatNumber(value: number, digits = 0) {
  return new Intl.NumberFormat("ko-KR", {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits
  }).format(value);
}

export function toneForStatus(status: NutrientStatus) {
  if (status === "deficient") return "bad" as const;
  if (status === "excess") return "warn" as const;
  return "good" as const;
}
