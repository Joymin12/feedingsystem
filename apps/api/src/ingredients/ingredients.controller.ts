import { Body, Controller, Get, Param, Put, Query, UseGuards } from "@nestjs/common";
import type { CurrentUser as CurrentUserType, IngredientCategory } from "@feedingsystem/contracts";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { IngredientsService } from "./ingredients.service.js";
import { UpdateFarmIngredientSettingDto } from "./ingredients.dto.js";

@Controller()
@UseGuards(SessionAuthGuard)
export class IngredientsController {
  constructor(private readonly ingredientsService: IngredientsService) {}

  @Get("ingredients")
  listIngredients(
    @Query("page") page?: string,
    @Query("limit") limit?: string,
    @Query("category") category?: IngredientCategory,
  ) {
    return this.ingredientsService.listIngredients(
      page ? Number(page) : 1,
      limit ? Number(limit) : 20,
      category,
    );
  }

  @Get("ingredients/:ingredientId")
  getIngredient(@Param("ingredientId") ingredientId: string) {
    return this.ingredientsService.getIngredient(ingredientId);
  }

  @Get("farm/ingredient-settings")
  listFarmSettings(@CurrentUser() user: CurrentUserType) {
    return this.ingredientsService.listFarmSettings(user);
  }

  @Put("farm/ingredient-settings/:ingredientId")
  updateFarmSetting(
    @CurrentUser() user: CurrentUserType,
    @Param("ingredientId") ingredientId: string,
    @Body() body: UpdateFarmIngredientSettingDto,
  ) {
    return this.ingredientsService.updateFarmSetting(user, ingredientId, body);
  }
}
