import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from "@nestjs/common";

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
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

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      code: "internal_error",
      message: "unexpected server error",
    });
  }
}
