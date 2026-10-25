import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.config import settings
from app.database import init_db_with_retry
from app.routes import router

logger = logging.getLogger("api.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application starting up: initializing database connection...")
    init_db_with_retry()
    yield
    logger.info("Application shutting down.")


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="Scalable Containerized RESTful API backend deployed on AWS Fargate",
    lifespan=lifespan
)


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    logger.error("Unhandled SQLAlchemyError on %s: %s", request.url.path, exc)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "Database error", "message": "A database error occurred while processing the request."}
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error("Unhandled exception on %s: %s", request.url.path, exc, exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "Internal Server Error", "message": "An unexpected error occurred."}
    )


app.include_router(router)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=settings.port, reload=False)
