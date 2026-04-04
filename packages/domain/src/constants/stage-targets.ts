import type { Stage } from "@hanwoo-tmr/contracts";

export type StageTarget = {
  stage: Stage;
  nutrientTargets: Record<"dm" | "cp" | "tdn" | "ndf" | "adf" | "ca" | "p" | "moisture", { min: number; max: number; target: number }>;
};

/**
 * 목표치는 수치형 계산의 기준점만 제공한다.
 * 설명 문구나 태그는 API나 UI에서 생성하지 않고, 추천 해석 레이어에서만 다룬다.
 */
export const STAGE_TARGETS: Record<Stage, StageTarget> = {
  growing_early: {
    stage: "growing_early",
    nutrientTargets: {
      dm: { min: 54, max: 60, target: 57 },
      cp: { min: 13, max: 15, target: 14 },
      tdn: { min: 64, max: 68, target: 66 },
      ndf: { min: 34, max: 40, target: 37 },
      adf: { min: 18, max: 24, target: 21 },
      ca: { min: 0.7, max: 1.0, target: 0.85 },
      p: { min: 0.35, max: 0.5, target: 0.42 },
      moisture: { min: 40, max: 46, target: 43 }
    }
  },
  growing_late: {
    stage: "growing_late",
    nutrientTargets: {
      dm: { min: 55, max: 61, target: 58 },
      cp: { min: 12.5, max: 14.5, target: 13.5 },
      tdn: { min: 66, max: 70, target: 68 },
      ndf: { min: 33, max: 39, target: 36 },
      adf: { min: 19, max: 25, target: 22 },
      ca: { min: 0.65, max: 0.95, target: 0.8 },
      p: { min: 0.35, max: 0.48, target: 0.4 },
      moisture: { min: 39, max: 45, target: 42 }
    }
  },
  fattening_early: {
    stage: "fattening_early",
    nutrientTargets: {
      dm: { min: 57, max: 63, target: 60 },
      cp: { min: 11.5, max: 13.2, target: 12.3 },
      tdn: { min: 68, max: 72, target: 70 },
      ndf: { min: 30, max: 36, target: 33 },
      adf: { min: 18, max: 24, target: 21 },
      ca: { min: 0.65, max: 0.9, target: 0.78 },
      p: { min: 0.32, max: 0.45, target: 0.38 },
      moisture: { min: 37, max: 43, target: 40 }
    }
  },
  fattening_mid: {
    stage: "fattening_mid",
    nutrientTargets: {
      dm: { min: 58, max: 64, target: 61 },
      cp: { min: 10.8, max: 12.5, target: 11.6 },
      tdn: { min: 70, max: 75, target: 72.5 },
      ndf: { min: 28, max: 34, target: 31 },
      adf: { min: 17, max: 23, target: 20 },
      ca: { min: 0.6, max: 0.85, target: 0.72 },
      p: { min: 0.3, max: 0.42, target: 0.36 },
      moisture: { min: 36, max: 42, target: 39 }
    }
  },
  fattening_late: {
    stage: "fattening_late",
    nutrientTargets: {
      dm: { min: 59, max: 65, target: 62 },
      cp: { min: 10.0, max: 11.8, target: 10.9 },
      tdn: { min: 72, max: 77, target: 74.5 },
      ndf: { min: 26, max: 32, target: 29 },
      adf: { min: 16, max: 22, target: 19 },
      ca: { min: 0.55, max: 0.8, target: 0.68 },
      p: { min: 0.28, max: 0.4, target: 0.34 },
      moisture: { min: 35, max: 41, target: 38 }
    }
  },
  breeding: {
    stage: "breeding",
    nutrientTargets: {
      dm: { min: 52, max: 58, target: 55 },
      cp: { min: 12, max: 14, target: 13 },
      tdn: { min: 60, max: 66, target: 63 },
      ndf: { min: 38, max: 44, target: 41 },
      adf: { min: 21, max: 27, target: 24 },
      ca: { min: 0.7, max: 1.1, target: 0.9 },
      p: { min: 0.35, max: 0.5, target: 0.42 },
      moisture: { min: 42, max: 48, target: 45 }
    }
  }
};
