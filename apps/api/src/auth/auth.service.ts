import { Injectable } from "@nestjs/common";
import type { CurrentUser } from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";

@Injectable()
export class AuthService {
  constructor(private readonly db: MockDatabaseService) {}

  login(email: string, password: string): { sessionToken: string; user: CurrentUser } {
    const user = this.db.authenticate(email, password);
    const sessionToken = this.db.createSession(user.user_id);
    return { sessionToken, user };
  }

  logout(sessionToken?: string): void {
    this.db.deleteSession(sessionToken);
  }

  getCurrentUserBySession(token: string): CurrentUser | undefined {
    return this.db.getCurrentUserBySession(token);
  }
}
