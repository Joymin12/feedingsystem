import { Injectable } from "@nestjs/common";
import type {
  CurrentUser,
  IngredientCategory,
  UpdateFarmIngredientSettingRequest,
} from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";

@Injectable()
export class IngredientsService {
  constructor(private readonly db: MockDatabaseService) {}

  listIngredients(page = 1, limit = 20, category?: IngredientCategory) {
    return this.db.listIngredients(page, limit, category);
  }

  getIngredient(ingredientId: string) {
    return this.db.getIngredient(ingredientId);
  }

  listFarmSettings(user: CurrentUser) {
    return { items: this.db.listFarmIngredientSettings(user) };
  }

  updateFarmSetting(
    user: CurrentUser,
    ingredientId: string,
    payload: UpdateFarmIngredientSettingRequest,
  ) {
    return this.db.updateFarmIngredientSetting(user, ingredientId, payload);
  }
}
