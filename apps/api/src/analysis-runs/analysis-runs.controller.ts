import { Body, Controller, Get, Param, Post, UseGuards } from "@nestjs/common";
import type {
  AnalysisRunRequest,
  CurrentUser as CurrentUserType,
} from "@feedingsystem/contracts";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { CreateAnalysisRunDto } from "./analysis-runs.dto.js";
import { AnalysisRunsService } from "./analysis-runs.service.js";

@Controller("analysis-runs")
@UseGuards(SessionAuthGuard)
export class AnalysisRunsController {
  constructor(private readonly analysisRunsService: AnalysisRunsService) {}

  @Post()
  create(@CurrentUser() user: CurrentUserType, @Body() body: CreateAnalysisRunDto) {
    return this.analysisRunsService.create(user, body as unknown as AnalysisRunRequest);
  }

  @Get(":runId")
  get(@CurrentUser() user: CurrentUserType, @Param("runId") runId: string) {
    return this.analysisRunsService.get(user, runId);
  }
}
