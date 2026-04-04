import type {
  AnalysisWorkflowResponse,
  CreateFormulaRequest,
  FarmProfile,
  Formula,
  StageComparisonResponse,
  UpdateFarmProfileRequest,
  UpdateFormulaRequest
} from "@hanwoo-tmr/contracts";

type ApiErrorPayload = {
  message: string;
  status: number;
  url: string;
};

export class ApiError extends Error {
  status: number;
  url: string;

  constructor(payload: ApiErrorPayload) {
    super(payload.message);
    this.name = "ApiError";
    this.status = payload.status;
    this.url = payload.url;
  }
}

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    cache: "no-store",
    headers: {
      "content-type": "application/json",
      ...(init?.headers ?? {})
    },
    ...init
  });

  if (!response.ok) {
    throw new ApiError({
      message: `Request failed: ${response.status}`,
      status: response.status,
      url: path
    });
  }

  return (await response.json()) as T;
}

export const api = {
  getFarmProfile: () => requestJson<FarmProfile>("/v1/farm/profile"),
  updateFarmProfile: (payload: UpdateFarmProfileRequest) =>
    requestJson<FarmProfile>("/v1/farm/profile", {
      method: "PUT",
      body: JSON.stringify(payload)
    }),
  listFormulas: () => requestJson<Formula[]>("/v1/formulas"),
  getFormula: (formulaId: string) => requestJson<Formula>(`/v1/formulas/${formulaId}`),
  saveFormula: (formulaId: string | undefined, payload: CreateFormulaRequest | UpdateFormulaRequest) =>
    requestJson<Formula>(formulaId ? `/v1/formulas/${formulaId}` : "/v1/formulas", {
      method: formulaId ? "PUT" : "POST",
      body: JSON.stringify(payload)
    }),
  getStageComparison: (formulaId: string) =>
    requestJson<StageComparisonResponse>(`/v1/formulas/${formulaId}/stage-comparison`),
  getAnalysisWorkflow: (runId: string) => requestJson<AnalysisWorkflowResponse>(`/v1/analysis-runs/${runId}`),
  createAnalysisRun: (formulaId: string) =>
    requestJson<AnalysisWorkflowResponse>("/v1/analysis-runs", {
      method: "POST",
      body: JSON.stringify({ formula_id: formulaId })
    })
};