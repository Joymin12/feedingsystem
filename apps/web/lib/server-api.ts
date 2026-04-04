import type {
  AnalysisWorkflowResponse,
  FarmProfile,
  Formula,
  StageComparisonResponse
} from "@hanwoo-tmr/contracts";
import { buildApiUrl } from "@/lib/config";

async function requestServerJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(buildApiUrl(path), {
    cache: "no-store",
    headers: {
      "content-type": "application/json",
      ...(init?.headers ?? {})
    },
    ...init
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.status} ${path}`);
  }

  return (await response.json()) as T;
}

export async function getFarmProfile(): Promise<FarmProfile> {
  return requestServerJson<FarmProfile>("/v1/farm/profile");
}

export async function listFormulas(): Promise<Formula[]> {
  return requestServerJson<Formula[]>("/v1/formulas");
}

export async function getFormula(formulaId: string): Promise<Formula> {
  return requestServerJson<Formula>(`/v1/formulas/${formulaId}`);
}

export async function getStageComparison(formulaId: string): Promise<StageComparisonResponse> {
  return requestServerJson<StageComparisonResponse>(`/v1/formulas/${formulaId}/stage-comparison`);
}

export async function getAnalysisWorkflow(runId: string): Promise<AnalysisWorkflowResponse> {
  return requestServerJson<AnalysisWorkflowResponse>(`/v1/analysis-runs/${runId}`);
}

export async function getDashboardSnapshot() {
  const [farmProfile, formulas] = await Promise.all([getFarmProfile(), listFormulas()]);
  const formula = formulas[0];

  if (!formula) {
    throw new Error("No formula available in the mock store.");
  }

  const stageComparison = await getStageComparison(formula.formula_id);
  const representativeRunId = stageComparison.representative_run_id;

  if (!representativeRunId) {
    throw new Error("No representative analysis run is available yet.");
  }

  const workflow = await getAnalysisWorkflow(representativeRunId);

  return {
    farmProfile,
    formulas,
    formula,
    workflow,
    stageComparison
  };
}
