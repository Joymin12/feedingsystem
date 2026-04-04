import { Body, Controller, Get, Param, Post, Put } from "@nestjs/common";
import {
  createAnalysisRunSchema,
  createFormulaSchema,
  updateFarmProfileSchema,
  updateFormulaSchema
} from "@hanwoo-tmr/contracts";
import { TmrService } from "./tmr.service";

@Controller()
export class TmrController {
  constructor(private readonly tmrService: TmrService) {}

  @Get("farm/profile")
  getFarmProfile() {
    return this.tmrService.getFarmProfile();
  }

  @Put("farm/profile")
  updateFarmProfile(@Body() body: unknown) {
    return this.tmrService.updateFarmProfile(updateFarmProfileSchema.parse(body));
  }

  @Post("formulas")
  createFormula(@Body() body: unknown) {
    return this.tmrService.createFormula(createFormulaSchema.parse(body));
  }

  @Get("formulas")
  listFormulas() {
    return this.tmrService.listFormulas();
  }

  @Get("formulas/:formulaId")
  getFormula(@Param("formulaId") formulaId: string) {
    return this.tmrService.getFormula(formulaId);
  }

  @Put("formulas/:formulaId")
  updateFormula(@Param("formulaId") formulaId: string, @Body() body: unknown) {
    return this.tmrService.updateFormula(formulaId, updateFormulaSchema.parse(body));
  }

  @Get("formulas/:formulaId/stage-comparison")
  getStageComparison(@Param("formulaId") formulaId: string) {
    return this.tmrService.getStageComparison(formulaId);
  }

  @Post("analysis-runs")
  createAnalysisRun(@Body() body: unknown) {
    return this.tmrService.createAnalysisRun(createAnalysisRunSchema.parse(body));
  }

  @Get("analysis-runs/:runId")
  getAnalysisRun(@Param("runId") runId: string) {
    return this.tmrService.getAnalysisRun(runId);
  }
}