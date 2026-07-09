import { Injectable } from "@nestjs/common";
import type {
  CreateFormulaRequest,
  CurrentUser,
  UpdateFormulaRequest,
} from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";

@Injectable()
export class FormulasService {
  constructor(private readonly db: MockDatabaseService) {}

  list(user: CurrentUser) {
    return { items: this.db.listFormulas(user) };
  }

  get(user: CurrentUser, formulaId: string) {
    return this.db.getFormula(user, formulaId);
  }

  create(user: CurrentUser, payload: CreateFormulaRequest) {
    return this.db.createFormula(user, payload);
  }

  update(user: CurrentUser, formulaId: string, payload: UpdateFormulaRequest) {
    return this.db.updateFormula(user, formulaId, payload);
  }
}
