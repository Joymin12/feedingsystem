import type {
  AnalysisWorkflowResponse,
  CreateAnalysisRunRequest,
  CreateFormulaRequest,
  Formula,
  StageComparisonResponse,
  UpdateFarmProfileRequest,
  UpdateFormulaRequest
} from "@hanwoo-tmr/contracts";
import {
  analysisWorkflowResponseSchema,
  createAnalysisRunSchema,
  createFormulaSchema,
  stageComparisonResponseSchema,
  updateFarmProfileSchema,
  updateFormulaSchema
} from "@hanwoo-tmr/contracts";
import { compareFormulaAcrossStages, runAnalysisWorkflow } from "@hanwoo-tmr/domain";
import { Injectable, NotFoundException } from "@nestjs/common";
import { MockTmrStore } from "./store";

@Injectable()
export class TmrService {
  constructor(private readonly store: MockTmrStore) {}

  getFarmProfile() {
    return this.store.getFarmProfile();
  }

  updateFarmProfile(payload: UpdateFarmProfileRequest) {
    const parsed = updateFarmProfileSchema.parse(payload);
    return this.store.updateFarmProfile(parsed);
  }

  listFormulas() {
    return this.store.listFormulas();
  }

  getFormula(formulaId: string): Formula {
    const formula = this.store.getFormula(formulaId);
    if (!formula) {
      throw new NotFoundException(`Formula ${formulaId} not found`);
    }
    return formula;
  }

  createFormula(payload: CreateFormulaRequest): Formula {
    const parsed = createFormulaSchema.parse(payload);
    const now = new Date().toISOString();

    return this.store.createFormula({
      formula_id: "pending",
      farm_id: parsed.farm_id,
      formula_name: parsed.formula_name,
      stage: parsed.stage,
      average_weight_kg: parsed.average_weight_kg,
      animal_count: parsed.animal_count,
      target_adg: parsed.target_adg,
      items: parsed.items.map((item) => ({
        ingredient_id: item.ingredient_id,
        ingredient_name: item.ingredient_name,
        inclusion_percent: item.inclusion_percent,
        moisture_percent: item.moisture_percent,
        cp_percent: item.cp_percent,
        tdn_percent: item.tdn_percent,
        ndf_percent: item.ndf_percent,
        adf_percent: item.adf_percent,
        ca_percent: item.ca_percent,
        p_percent: item.p_percent
      })),
      notes: parsed.notes,
      created_at: now,
      updated_at: now
    });
  }

  updateFormula(formulaId: string, payload: UpdateFormulaRequest): Formula {
    const existing = this.getFormula(formulaId);
    const parsed = updateFormulaSchema.parse(payload);
    const now = new Date().toISOString();

    return this.store.saveFormula({
      ...existing,
      ...(parsed.farm_id ? { farm_id: parsed.farm_id } : {}),
      ...(parsed.formula_name ? { formula_name: parsed.formula_name } : {}),
      ...(parsed.stage ? { stage: parsed.stage } : {}),
      ...(parsed.average_weight_kg !== undefined ? { average_weight_kg: parsed.average_weight_kg } : {}),
      ...(parsed.animal_count !== undefined ? { animal_count: parsed.animal_count } : {}),
      ...(parsed.target_adg !== undefined ? { target_adg: parsed.target_adg } : {}),
      ...(parsed.items
        ? {
            items: parsed.items.map((item) => ({
              ingredient_id: item.ingredient_id,
              ingredient_name: item.ingredient_name,
              inclusion_percent: item.inclusion_percent,
              moisture_percent: item.moisture_percent,
              cp_percent: item.cp_percent,
              tdn_percent: item.tdn_percent,
              ndf_percent: item.ndf_percent,
              adf_percent: item.adf_percent,
              ca_percent: item.ca_percent,
              p_percent: item.p_percent
            }))
          }
        : {}),
      ...(parsed.notes !== undefined ? { notes: parsed.notes } : {}),
      updated_at: now
    });
  }

  createAnalysisRun(payload: CreateAnalysisRunRequest): AnalysisWorkflowResponse {
    const parsed = createAnalysisRunSchema.parse(payload);
    const formula = this.getFormula(parsed.formula_id);
    const preferredStage = this.store.getFarmProfile().preferred_stage;
    const runId = this.store.makeRunId();
    const createdAt = new Date().toISOString();
    const workflow = runAnalysisWorkflow(formula, preferredStage, runId, createdAt, {
      farmProfile: this.store.getFarmProfile(),
      farmIngredientSettings: this.store.getFarmIngredientSettings(),
      inventory: this.store.getInventory()
    });

    const bundle = analysisWorkflowResponseSchema.parse({
      analysis_run: workflow.analysisRun,
      recommendation: workflow.recommendation,
      stage_comparison: workflow.stageComparison
    });

    this.store.saveAnalysisBundle(runId, bundle, formula.formula_id);
    return bundle;
  }

  getAnalysisRun(runId: string): AnalysisWorkflowResponse {
    const bundle = this.store.getAnalysisBundle(runId);
    if (!bundle) {
      throw new NotFoundException(`Analysis run ${runId} not found`);
    }
    return bundle;
  }

  getStageComparison(formulaId: string): StageComparisonResponse {
    const formula = this.getFormula(formulaId);
    const preferredStage = this.store.getFarmProfile().preferred_stage;
    const representativeRunId = this.store.getLatestRunIdByFormulaId(formulaId);

    return stageComparisonResponseSchema.parse({
      ...compareFormulaAcrossStages(formula, preferredStage),
      representative_run_id: representativeRunId
    });
  }
}