import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      const payload =
        typeof exceptionResponse === "string"
          ? {
              code: `http_${status}`,
              message: exceptionResponse,
            }
          : {
              code: `http_${status}`,
              ...(exceptionResponse as object),
            };

      response.status(status).json(payload);
      return;
    }

    // 예상 못 한 오류는 반드시 남긴다. 조용한 500은 원인 추적을 불가능하게 만든다.
    this.logger.error(
      exception instanceof Error ? exception.message : String(exception),
      exception instanceof Error ? exception.stack : undefined,
    );

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      code: "internal_error",
      message: "unexpected server error",
    });
  }
}
