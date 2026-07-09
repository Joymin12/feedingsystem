import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from "@nestjs/common";
import type {
  AnalysisRun,
  AnalysisRunRequest,
  ApiListResponse,
  CreateFormulaRequest,
  CreateRecommendationMemoRequest,
  CurrentUser,
  FarmIngredientSetting,
  FarmMember,
  FarmProfile,
  Formula,
  Ingredient,
  IngredientCategory,
  InviteFarmMemberRequest,
  RecommendationMemo,
  SeedIngredientRecord,
  UpdateFarmIngredientSettingRequest,
  UpdateFarmProfileRequest,
  UpdateFormulaRequest,
  UserRole,
} from "@feedingsystem/contracts";
import { analyzeRun } from "@feedingsystem/domain";

interface DemoUser extends CurrentUser {
  password: string;
}

interface AuditLog {
  id: string;
  farm_id?: string;
  actor_user_id?: string;
  event_type: string;
  entity_type: string;
  entity_id?: string;
  payload: Record<string, unknown>;
  created_at: string;
}

function mergeDefined<T extends object>(base: T, patch: object): T {
  const next = { ...base };
  for (const [key, value] of Object.entries(patch as Record<string, unknown>)) {
    if (value !== undefined) {
      Object.assign(next, { [key]: value });
    }
  }
  return next;
}

function loadSeedIngredients(): SeedIngredientRecord[] {
  const currentDir = dirname(fileURLToPath(import.meta.url));
  const seedPath = resolve(currentDir, "../../../../docs/seeds/ingredients.seed.json");
  return JSON.parse(readFileSync(seedPath, "utf-8")) as SeedIngredientRecord[];
}

@Injectable()
export class MockDatabaseService {
  private readonly sessions = new Map<string, string>();
  private readonly users: DemoUser[] = [];
  private readonly farmProfiles = new Map<string, FarmProfile>();
  private readonly farmMembers = new Map<string, FarmMember[]>();
  private readonly farmIngredientSettings = new Map<string, FarmIngredientSetting[]>();
  private readonly formulas = new Map<string, Formula[]>();
  private readonly analysisRuns = new Map<string, AnalysisRun[]>();
  private readonly recommendationMemos = new Map<string, RecommendationMemo[]>();
  private readonly auditLogs: AuditLog[] = [];
  private readonly ingredients: Ingredient[];

  constructor() {
    this.ingredients = this.bootstrapIngredients(loadSeedIngredients());
    this.bootstrapFarm();
  }

  authenticate(email: string, password: string): CurrentUser {
    const user = this.users.find((candidate) => candidate.email === email);
    if (!user || user.password !== password) {
      throw new UnauthorizedException("invalid email or password");
    }

    return this.stripPassword(user);
  }

  createSession(userId: string): string {
    const token = randomUUID();
    this.sessions.set(token, userId);
    return token;
  }

  deleteSession(token?: string): void {
    if (token) {
      this.sessions.delete(token);
    }
  }

  getCurrentUserBySession(token: string): CurrentUser | undefined {
    const userId = this.sessions.get(token);
    if (!userId) {
      return undefined;
    }

    const user = this.users.find((candidate) => candidate.user_id === userId);
    return user ? this.stripPassword(user) : undefined;
  }

  getFarmProfile(user: CurrentUser): FarmProfile {
    const profile = this.farmProfiles.get(user.farm_id);
    if (!profile) {
      throw new NotFoundException("farm profile not found");
    }
    return profile;
  }

  updateFarmProfile(user: CurrentUser, payload: UpdateFarmProfileRequest): FarmProfile {
    this.ensureOwner(user);
    const current = this.getFarmProfile(user);
    const next: FarmProfile = {
      ...current,
      ...payload,
      farm_name: payload.farm_name ?? current.farm_name,
      preferred_ingredients:
        payload.preferred_ingredient_ids ?? current.preferred_ingredients,
      avoided_ingredients: payload.avoided_ingredient_ids ?? current.avoided_ingredients,
    };

    this.farmProfiles.set(user.farm_id, next);
    if (payload.farm_name) {
      this.users.forEach((candidate) => {
        if (candidate.farm_id === user.farm_id) {
          candidate.farm_name = payload.farm_name!;
        }
      });
    }
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: user.farm_id,
      entity_type: "farm_profile",
      event_type: "farm_profile_updated",
      farm_id: user.farm_id,
      payload: payload as unknown as Record<string, unknown>,
    });

    return next;
  }

  listFarmMembers(user: CurrentUser): FarmMember[] {
    return [...(this.farmMembers.get(user.farm_id) ?? [])];
  }

  inviteFarmMember(user: CurrentUser, payload: InviteFarmMemberRequest): FarmMember {
    this.ensureOwner(user);
    const existingFarmMember = this.listFarmMembers(user).find(
      (member) => member.email === payload.email,
    );
    if (existingFarmMember) {
      throw new ConflictException("farm member already exists");
    }
    const existingUser = this.users.find((candidate) => candidate.email === payload.email);
    if (existingUser) {
      throw new ConflictException("user already belongs to another farm");
    }

    const memberUser: DemoUser = {
      user_id: randomUUID(),
      email: payload.email,
      name: payload.name,
      farm_id: user.farm_id,
      farm_name: user.farm_name,
      role: payload.role,
      password: "password123",
    };
    const member: FarmMember = {
      user_id: memberUser.user_id,
      email: memberUser.email,
      name: memberUser.name,
      role: payload.role,
      status: "invited",
    };

    this.users.push(memberUser);
    this.farmMembers.set(user.farm_id, [...this.listFarmMembers(user), member]);
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: member.user_id,
      entity_type: "farm_member",
      event_type: "farm_member_invited",
      farm_id: user.farm_id,
      payload: payload as unknown as Record<string, unknown>,
    });

    return member;
  }

  listIngredients(page = 1, limit = 20, category?: IngredientCategory): ApiListResponse<Ingredient> {
    const filtered = category
      ? this.ingredients.filter((ingredient) => ingredient.category === category)
      : this.ingredients;
    const start = (page - 1) * limit;
    const items = filtered.slice(start, start + limit);

    return {
      items,
      page,
      limit,
      total: filtered.length,
    };
  }

  getIngredient(ingredientId: string): Ingredient {
    const ingredient = this.ingredients.find((candidate) => candidate.ingredient_id === ingredientId);
    if (!ingredient) {
      throw new NotFoundException("ingredient not found");
    }
    return ingredient;
  }

  listFarmIngredientSettings(user: CurrentUser): FarmIngredientSetting[] {
    return [...(this.farmIngredientSettings.get(user.farm_id) ?? [])];
  }

  updateFarmIngredientSetting(
    user: CurrentUser,
    ingredientId: string,
    payload: UpdateFarmIngredientSettingRequest,
  ): FarmIngredientSetting {
    const settings = this.listFarmIngredientSettings(user);
    const current = settings.find((candidate) => candidate.ingredient_id === ingredientId);
    if (!current) {
      throw new NotFoundException("ingredient setting not found");
    }

    const next = mergeDefined(current, payload);
    const updated = settings.map((candidate) =>
      candidate.ingredient_id === ingredientId ? next : candidate,
    );
    this.farmIngredientSettings.set(user.farm_id, updated);

    const profile = this.getFarmProfile(user);
    profile.preferred_ingredients = payload.preferred
      ? [...new Set([...profile.preferred_ingredients, ingredientId])]
      : profile.preferred_ingredients.filter((id) => id !== ingredientId);
    profile.avoided_ingredients = payload.avoided
      ? [...new Set([...profile.avoided_ingredients, ingredientId])]
      : profile.avoided_ingredients.filter((id) => id !== ingredientId);
    this.farmProfiles.set(user.farm_id, profile);

    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: ingredientId,
      entity_type: "farm_ingredient_setting",
      event_type: "farm_ingredient_setting_updated",
      farm_id: user.farm_id,
      payload: payload as unknown as Record<string, unknown>,
    });

    return next;
  }

  listFormulas(user: CurrentUser): Formula[] {
    return [...(this.formulas.get(user.farm_id) ?? [])];
  }

  getFormula(user: CurrentUser, formulaId: string): Formula {
    const formula = this.listFormulas(user).find((candidate) => candidate.formula_id === formulaId);
    if (!formula) {
      throw new NotFoundException("formula not found");
    }
    return formula;
  }

  createFormula(user: CurrentUser, payload: CreateFormulaRequest): Formula {
    const next: Formula = {
      formula_id: randomUUID(),
      name: payload.name,
      stage: payload.stage,
      avg_weight_kg: payload.avg_weight_kg,
      head_count: payload.head_count,
      objective: payload.objective,
      status: payload.status ?? "draft",
      items: payload.items,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      ...(payload.target_adg !== undefined ? { target_adg: payload.target_adg } : {}),
    };

    this.formulas.set(user.farm_id, [...this.listFormulas(user), next]);
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: next.formula_id,
      entity_type: "formula",
      event_type: "formula_created",
      farm_id: user.farm_id,
      payload: payload as unknown as Record<string, unknown>,
    });

    return next;
  }

  updateFormula(user: CurrentUser, formulaId: string, payload: UpdateFormulaRequest): Formula {
    const current = this.getFormula(user, formulaId);
    const next = mergeDefined(current, payload);
    next.items = payload.items;
    next.updated_at = new Date().toISOString();

    this.formulas.set(
      user.farm_id,
      this.listFormulas(user).map((formula) =>
        formula.formula_id === formulaId ? next : formula,
      ),
    );
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: formulaId,
      entity_type: "formula",
      event_type: "formula_updated",
      farm_id: user.farm_id,
      payload: payload as unknown as Record<string, unknown>,
    });

    return next;
  }

  createAnalysisRun(user: CurrentUser, request: AnalysisRunRequest): AnalysisRun {
    const run = analyzeRun({
      actorUserId: user.user_id,
      farmProfile: this.getFarmProfile(user),
      farmIngredientSettings: this.listFarmIngredientSettings(user),
      ingredients: this.ingredients,
      formulas: this.listFormulas(user),
      request,
    });

    this.analysisRuns.set(user.farm_id, [...(this.analysisRuns.get(user.farm_id) ?? []), run]);
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: run.run_id,
      entity_type: "analysis_run",
      event_type: "analysis_run_created",
      farm_id: user.farm_id,
      payload: { mode: request.mode },
    });

    return run;
  }

  getAnalysisRun(user: CurrentUser, runId: string): AnalysisRun {
    const run = (this.analysisRuns.get(user.farm_id) ?? []).find(
      (candidate) => candidate.run_id === runId,
    );
    if (!run) {
      throw new NotFoundException("analysis run not found");
    }
    return run;
  }

  createRecommendationMemo(
    user: CurrentUser,
    recommendationId: string,
    payload: CreateRecommendationMemoRequest,
  ): RecommendationMemo {
    const recommendation = this.findRecommendation(user, recommendationId);
    const memo: RecommendationMemo = {
      memo_id: randomUUID(),
      recommendation_id: recommendation.recommendation_id,
      applied: payload.applied,
      memo: payload.memo,
      created_by: user.user_id,
      created_at: new Date().toISOString(),
    };

    const current = this.recommendationMemos.get(user.farm_id) ?? [];
    this.recommendationMemos.set(user.farm_id, [...current, memo]);
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: memo.memo_id,
      entity_type: "recommendation_memo",
      event_type: "recommendation_memo_created",
      farm_id: user.farm_id,
      payload: payload as unknown as Record<string, unknown>,
    });

    return memo;
  }

  listRecommendationMemos(
    user: CurrentUser,
    analysisRunId?: string,
    latestOnly = true,
  ): RecommendationMemo[] {
    const allMemos = this.recommendationMemos.get(user.farm_id) ?? [];
    const filtered = analysisRunId
      ? allMemos.filter((memo) => {
          const recommendation = this.findRecommendation(user, memo.recommendation_id);
          const ownerRun = this.findAnalysisRunByRecommendation(user, recommendation.recommendation_id);
          return ownerRun.run_id === analysisRunId;
        })
      : allMemos;

    if (!latestOnly) {
      return filtered;
    }

    const latestByRecommendation = new Map<string, RecommendationMemo>();
    for (const memo of filtered) {
      const current = latestByRecommendation.get(memo.recommendation_id);
      if (!current || current.created_at < memo.created_at) {
        latestByRecommendation.set(memo.recommendation_id, memo);
      }
    }

    return [...latestByRecommendation.values()].sort((left, right) =>
      right.created_at.localeCompare(left.created_at),
    );
  }

  recordReportDownload(
    user: CurrentUser,
    runId: string,
    format: "pdf" | "xlsx",
  ): void {
    this.addAuditLog({
      actor_user_id: user.user_id,
      entity_id: runId,
      entity_type: "analysis_run_report",
      event_type: format === "pdf" ? "report_pdf_downloaded" : "report_xlsx_downloaded",
      farm_id: user.farm_id,
      payload: { format },
    });
  }

  private bootstrapIngredients(records: SeedIngredientRecord[]): Ingredient[] {
    return records.map((record) => ({
      ingredient_id: randomUUID(),
      code: record.code,
      name_ko: record.name_ko,
      category: record.category,
      default_price_krw_per_kg: record.default_price_krw_per_kg,
      description: record.description,
      current_nutrition: record.nutrition,
      ai_profile: record.ai_profile,
    }));
  }

  private bootstrapFarm(): void {
    const farmId = randomUUID();
    const farmName = "한우 시범농장";
    const owner: DemoUser = {
      user_id: randomUUID(),
      email: "owner@example.com",
      name: "시범농장 대표",
      farm_id: farmId,
      farm_name: farmName,
      role: "owner",
      password: "password123",
    };
    const member: DemoUser = {
      user_id: randomUUID(),
      email: "member@example.com",
      name: "시범농장 직원",
      farm_id: farmId,
      farm_name: farmName,
      role: "member",
      password: "password123",
    };

    this.users.push(owner, member);
    this.farmProfiles.set(farmId, {
      farm_id: farmId,
      farm_name: farmName,
      storage_level: "medium",
      wet_feed_policy: "allowed",
      cost_priority: 3,
      stability_priority: 4,
      notes: "초기 시범 데이터",
      preferred_ingredients: [],
      avoided_ingredients: [],
    });
    this.farmMembers.set(farmId, [
      {
        user_id: owner.user_id,
        email: owner.email,
        name: owner.name,
        role: owner.role,
        status: "active",
      },
      {
        user_id: member.user_id,
        email: member.email,
        name: member.name,
        role: member.role,
        status: "active",
      },
    ]);
    this.farmIngredientSettings.set(
      farmId,
      this.ingredients.map((ingredient) => ({
        ingredient_id: ingredient.ingredient_id,
        is_enabled: true,
        is_banned: false,
        preferred: ingredient.code === "SOYBEAN_MEAL",
        avoided: false,
        custom_price_krw_per_kg: undefined,
        inventory_kg: ingredient.category === "roughage" ? 400 : 120,
        price_source: "market_default",
        note: undefined,
      })),
    );

    const byCode = (code: string) =>
      this.ingredients.find((ingredient) => ingredient.code === code)?.ingredient_id ?? "";
    this.formulas.set(farmId, [
      {
        formula_id: randomUUID(),
        name: "비육중기 기본배합",
        stage: "fattening_mid",
        avg_weight_kg: 620,
        head_count: 20,
        objective: "growth",
        target_adg: 0.9,
        status: "active",
        items: [
          { ingredient_id: byCode("CORN_GRAIN"), as_fed_kg_per_head_day: 4.2, price_source: "market_default" },
          { ingredient_id: byCode("SOYBEAN_MEAL"), as_fed_kg_per_head_day: 0.8, price_source: "market_default" },
          { ingredient_id: byCode("CORN_SILAGE"), as_fed_kg_per_head_day: 6.0, price_source: "market_default" },
          { ingredient_id: byCode("RICE_STRAW"), as_fed_kg_per_head_day: 1.2, price_source: "market_default" },
          { ingredient_id: byCode("MINERAL_PREMIX"), as_fed_kg_per_head_day: 0.08, price_source: "market_default" },
        ],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
    ]);
  }

  private stripPassword(user: DemoUser): CurrentUser {
    return {
      user_id: user.user_id,
      email: user.email,
      name: user.name,
      farm_id: user.farm_id,
      farm_name: user.farm_name,
      role: user.role,
    };
  }

  private ensureOwner(user: CurrentUser): void {
    if (user.role !== "owner") {
      throw new ForbiddenException("owner role required");
    }
  }

  private findRecommendation(user: CurrentUser, recommendationId: string) {
    const recommendation = (this.analysisRuns.get(user.farm_id) ?? [])
      .flatMap((run) => run.recommendations)
      .find((candidate) => candidate.recommendation_id === recommendationId);
    if (!recommendation) {
      throw new NotFoundException("recommendation not found");
    }
    return recommendation;
  }

  private findAnalysisRunByRecommendation(user: CurrentUser, recommendationId: string): AnalysisRun {
    const run = (this.analysisRuns.get(user.farm_id) ?? []).find((candidate) =>
      candidate.recommendations.some(
        (recommendation) => recommendation.recommendation_id === recommendationId,
      ),
    );
    if (!run) {
      throw new NotFoundException("analysis run not found");
    }
    return run;
  }

  private addAuditLog(log: Omit<AuditLog, "id" | "created_at">): void {
    this.auditLogs.push({
      id: randomUUID(),
      created_at: new Date().toISOString(),
      ...log,
    });
  }
}
