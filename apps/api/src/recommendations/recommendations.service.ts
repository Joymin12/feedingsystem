import { Injectable } from "@nestjs/common";
import type { CreateRecommendationMemoRequest, CurrentUser } from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";

@Injectable()
export class RecommendationsService {
  constructor(private readonly db: MockDatabaseService) {}

  createMemo(
    user: CurrentUser,
    recommendationId: string,
    payload: CreateRecommendationMemoRequest,
  ) {
    return this.db.createRecommendationMemo(user, recommendationId, payload);
  }

  listMemos(user: CurrentUser, analysisRunId?: string, latestOnly = true) {
    return {
      items: this.db.listRecommendationMemos(user, analysisRunId, latestOnly),
    };
  }
}
