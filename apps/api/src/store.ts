import type {
  AnalysisWorkflowResponse,
  FarmIngredientSetting,
  FarmProfile,
  Formula,
  InventoryItem,
  UpdateFarmProfileRequest
} from "@hanwoo-tmr/contracts";
import { runAnalysisWorkflow } from "@hanwoo-tmr/domain";

/**
 * MVP 단계에서는 실제 DB 대신 일관된 mock store를 사용한다.
 * 중요한 점은 엔드포인트와 contracts가 이후 DB/Android 확장 시에도 그대로 재사용될 수 있게
 * 저장 모델 이름과 응답 구조를 유지하는 것이다.
 */
export class MockTmrStore {
  private readonly farmProfile: FarmProfile;
  private readonly farmIngredientSettings: FarmIngredientSetting[];
  private readonly inventory: InventoryItem[];
  private readonly formulas = new Map<string, Formula>();
  private readonly analysisBundles = new Map<string, AnalysisWorkflowResponse>();
  private readonly latestRunIdByFormulaId = new Map<string, string>();
  private nextSequence = 1;

  constructor() {
    this.farmProfile = {
      farm_id: "farm_001",
      farm_name: "청솔 한우목장",
      storage_level: "medium",
      wet_feed_policy: "limited",
      cost_priority: 58,
      stability_priority: 82,
      notes: "보유 원료를 우선 사용하되 비육 중기 이후에는 반추 안정성을 함께 본다.",
      preferred_ingredients: ["corn_silage", "steam_flaked_corn", "soybean_meal"],
      avoided_ingredients: ["cottonseed_hull"],
      preferred_stage: "fattening_mid"
    };

    this.farmIngredientSettings = [
      {
        ingredient_id: "corn_silage",
        ingredient_name: "옥수수 사일리지",
        is_enabled: true,
        is_banned: false,
        is_preferred: true,
        max_inclusion_percent: 35,
        notes: "기본 조사료 축으로 유지"
      },
      {
        ingredient_id: "ryegrass_hay",
        ingredient_name: "이탈리안라이그라스 건초",
        is_enabled: true,
        is_banned: false,
        is_preferred: false,
        max_inclusion_percent: 18,
        notes: "섬유 보강용으로 제한적으로 사용"
      },
      {
        ingredient_id: "steam_flaked_corn",
        ingredient_name: "스팀플레이크 옥수수",
        is_enabled: true,
        is_banned: false,
        is_preferred: true,
        max_inclusion_percent: 32,
        notes: "에너지 보강용 선호 원료"
      },
      {
        ingredient_id: "wheat_bran",
        ingredient_name: "밀기울",
        is_enabled: true,
        is_banned: false,
        is_preferred: false,
        max_inclusion_percent: 15,
        notes: "가격 변동성이 있어 과다 사용은 지양"
      },
      {
        ingredient_id: "soybean_meal",
        ingredient_name: "대두박",
        is_enabled: true,
        is_banned: false,
        is_preferred: true,
        max_inclusion_percent: 14,
        notes: "단백질 보강용 핵심 원료"
      },
      {
        ingredient_id: "mineral_premix",
        ingredient_name: "미네랄 프리믹스",
        is_enabled: true,
        is_banned: false,
        is_preferred: false,
        max_inclusion_percent: 5,
        notes: "무기질 균형 유지용"
      },
      {
        ingredient_id: "cottonseed_hull",
        ingredient_name: "면실박 껍질",
        is_enabled: false,
        is_banned: true,
        is_preferred: false,
        notes: "농장 정책상 회피"
      }
    ];

    this.inventory = [
      { ingredient_id: "corn_silage", ingredient_name: "옥수수 사일리지", inventory_kg: 2400 },
      { ingredient_id: "ryegrass_hay", ingredient_name: "이탈리안라이그라스 건초", inventory_kg: 860 },
      { ingredient_id: "steam_flaked_corn", ingredient_name: "스팀플레이크 옥수수", inventory_kg: 1100 },
      { ingredient_id: "wheat_bran", ingredient_name: "밀기울", inventory_kg: 420 },
      { ingredient_id: "soybean_meal", ingredient_name: "대두박", inventory_kg: 310 },
      { ingredient_id: "mineral_premix", ingredient_name: "미네랄 프리믹스", inventory_kg: 120 }
    ];

    const now = new Date().toISOString();
    const seedFormula: Formula = {
      formula_id: "formula_001",
      farm_id: this.farmProfile.farm_id,
      formula_name: "기본 TMR 1호",
      stage: "fattening_mid",
      average_weight_kg: 540,
      animal_count: 80,
      target_adg: 1,
      items: [
        {
          ingredient_id: "corn_silage",
          ingredient_name: "옥수수 사일리지",
          inclusion_percent: 30,
          moisture_percent: 68,
          cp_percent: 8,
          tdn_percent: 60,
          ndf_percent: 42,
          adf_percent: 27,
          ca_percent: 0.28,
          p_percent: 0.18
        },
        {
          ingredient_id: "ryegrass_hay",
          ingredient_name: "이탈리안라이그라스 건초",
          inclusion_percent: 14,
          moisture_percent: 14,
          cp_percent: 11,
          tdn_percent: 57,
          ndf_percent: 61,
          adf_percent: 34,
          ca_percent: 0.41,
          p_percent: 0.22
        },
        {
          ingredient_id: "steam_flaked_corn",
          ingredient_name: "스팀플레이크 옥수수",
          inclusion_percent: 29,
          moisture_percent: 12,
          cp_percent: 9,
          tdn_percent: 88,
          ndf_percent: 10,
          adf_percent: 4,
          ca_percent: 0.03,
          p_percent: 0.29
        },
        {
          ingredient_id: "wheat_bran",
          ingredient_name: "밀기울",
          inclusion_percent: 11,
          moisture_percent: 12,
          cp_percent: 16,
          tdn_percent: 73,
          ndf_percent: 34,
          adf_percent: 11,
          ca_percent: 0.13,
          p_percent: 1.05
        },
        {
          ingredient_id: "soybean_meal",
          ingredient_name: "대두박",
          inclusion_percent: 11,
          moisture_percent: 12,
          cp_percent: 46,
          tdn_percent: 82,
          ndf_percent: 7,
          adf_percent: 4,
          ca_percent: 0.29,
          p_percent: 0.65
        },
        {
          ingredient_id: "mineral_premix",
          ingredient_name: "미네랄 프리믹스",
          inclusion_percent: 5,
          moisture_percent: 8,
          cp_percent: 0,
          tdn_percent: 0,
          ndf_percent: 0,
          adf_percent: 0,
          ca_percent: 12,
          p_percent: 8
        }
      ],
      notes: "대표 분석과 stage comparison 데모를 위한 초기 formula",
      created_at: now,
      updated_at: now
    };

    this.formulas.set(seedFormula.formula_id, seedFormula);

    const initialRunId = this.makeRunId();
    const workflow = runAnalysisWorkflow(seedFormula, this.farmProfile.preferred_stage, initialRunId, now, {
      farmProfile: this.farmProfile,
      farmIngredientSettings: this.farmIngredientSettings,
      inventory: this.inventory
    });

    this.saveAnalysisBundle(
      initialRunId,
      {
        analysis_run: workflow.analysisRun,
        recommendation: workflow.recommendation,
        stage_comparison: workflow.stageComparison
      },
      seedFormula.formula_id
    );
  }

  private nextId(prefix: string): string {
    const value = `${prefix}_${String(this.nextSequence).padStart(4, "0")}`;
    this.nextSequence += 1;
    return value;
  }

  getFarmProfile(): FarmProfile {
    return this.farmProfile;
  }

  updateFarmProfile(payload: UpdateFarmProfileRequest): FarmProfile {
    Object.assign(this.farmProfile, payload);
    return this.farmProfile;
  }

  getFarmIngredientSettings(): FarmIngredientSetting[] {
    return this.farmIngredientSettings;
  }

  getInventory(): InventoryItem[] {
    return this.inventory;
  }

  listFormulas(): Formula[] {
    return [...this.formulas.values()].sort((left, right) => right.updated_at.localeCompare(left.updated_at));
  }

  getFormula(formulaId: string): Formula | undefined {
    return this.formulas.get(formulaId);
  }

  saveFormula(formula: Formula): Formula {
    this.formulas.set(formula.formula_id, formula);
    return formula;
  }

  createFormula(formula: Formula): Formula {
    const stored = { ...formula, formula_id: this.nextId("formula") };
    this.formulas.set(stored.formula_id, stored);
    return stored;
  }

  getAnalysisBundle(runId: string): AnalysisWorkflowResponse | undefined {
    return this.analysisBundles.get(runId);
  }

  saveAnalysisBundle(
    runId: string,
    bundle: AnalysisWorkflowResponse,
    formulaId: string
  ): AnalysisWorkflowResponse {
    this.analysisBundles.set(runId, bundle);
    this.latestRunIdByFormulaId.set(formulaId, runId);
    return bundle;
  }

  getLatestRunIdByFormulaId(formulaId: string): string | undefined {
    return this.latestRunIdByFormulaId.get(formulaId);
  }

  makeRunId(): string {
    return this.nextId("run");
  }
}