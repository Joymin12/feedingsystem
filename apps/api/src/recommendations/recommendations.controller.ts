import { Body, Controller, Get, Param, Post, Query, UseGuards } from "@nestjs/common";
import type { CurrentUser as CurrentUserType } from "@feedingsystem/contracts";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { CreateRecommendationMemoDto } from "./recommendations.dto.js";
import { RecommendationsService } from "./recommendations.service.js";

@Controller()
@UseGuards(SessionAuthGuard)
export class RecommendationsController {
  constructor(private readonly recommendationsService: RecommendationsService) {}

  @Post("recommendations/:recommendationId/memo")
  createMemo(
    @CurrentUser() user: CurrentUserType,
    @Param("recommendationId") recommendationId: string,
    @Body() body: CreateRecommendationMemoDto,
  ) {
    return this.recommendationsService.createMemo(user, recommendationId, body);
  }

  @Get("recommendation-memos")
  listMemos(
    @CurrentUser() user: CurrentUserType,
    @Query("analysis_run_id") analysisRunId?: string,
    @Query("latest_only") latestOnly?: string,
  ) {
    return this.recommendationsService.listMemos(
      user,
      analysisRunId,
      latestOnly !== "false",
    );
  }
}
