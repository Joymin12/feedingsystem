import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";

import { AuthService } from "../../auth/auth.service.js";

@Injectable()
export class SessionAuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const cookieToken = request.cookies?.session;
    const headerToken = request.headers["x-session-token"];
    const sessionToken =
      (Array.isArray(cookieToken) ? cookieToken[0] : cookieToken) ??
      (Array.isArray(headerToken) ? headerToken[0] : headerToken);

    if (!sessionToken || typeof sessionToken !== "string") {
      throw new UnauthorizedException("authentication required");
    }

    const currentUser = this.authService.getCurrentUserBySession(sessionToken);
    if (!currentUser) {
      throw new UnauthorizedException("invalid session");
    }

    request.currentUser = currentUser;
    return true;
  }
}
