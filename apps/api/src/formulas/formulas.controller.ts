import { Body, Controller, Get, Param, Post, Put, UseGuards } from "@nestjs/common";
import type { CurrentUser as CurrentUserType } from "@feedingsystem/contracts";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { CreateFormulaDto, UpdateFormulaDto } from "./formulas.dto.js";
import { FormulasService } from "./formulas.service.js";

@Controller("formulas")
@UseGuards(SessionAuthGuard)
export class FormulasController {
  constructor(private readonly formulasService: FormulasService) {}

  @Get()
  list(@CurrentUser() user: CurrentUserType) {
    return this.formulasService.list(user);
  }

  @Post()
  create(@CurrentUser() user: CurrentUserType, @Body() body: CreateFormulaDto) {
    return this.formulasService.create(user, body);
  }

  @Get(":formulaId")
  get(@CurrentUser() user: CurrentUserType, @Param("formulaId") formulaId: string) {
    return this.formulasService.get(user, formulaId);
  }

  @Put(":formulaId")
  update(
    @CurrentUser() user: CurrentUserType,
    @Param("formulaId") formulaId: string,
    @Body() body: UpdateFormulaDto,
  ) {
    return this.formulasService.update(user, formulaId, body);
  }
}
