import { BadRequestException, Injectable } from "@nestjs/common";
import type { AnalysisRunRequest, CurrentUser } from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";

@Injectable()
export class AnalysisRunsService {
  constructor(private readonly db: MockDatabaseService) {}

  create(user: CurrentUser, payload: AnalysisRunRequest) {
    if (payload.mode === "formula" && !payload.formula_id) {
      throw new BadRequestException("formula_id is required for formula mode");
    }

    if (payload.mode === "adhoc") {
      if (
        !payload.stage ||
        !payload.avg_weight_kg ||
        !payload.head_count ||
        !payload.objective ||
        !payload.items?.length
      ) {
        throw new BadRequestException("adhoc mode requires stage, avg_weight_kg, head_count, objective and items");
      }
    }

    return this.db.createAnalysisRun(user, payload);
  }

  get(user: CurrentUser, runId: string) {
    return this.db.getAnalysisRun(user, runId);
  }
}
