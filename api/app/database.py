import logging
import time
from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.exc import OperationalError, SQLAlchemyError

from app.config import settings
from app.models import Base

logger = logging.getLogger("api.database")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

db_url = settings.get_database_url()

engine_kwargs = {}
if not db_url.startswith("sqlite"):
    engine_kwargs.update({
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "pool_size": 10,
        "max_overflow": 20,
    })
else:
    engine_kwargs.update({
        "connect_args": {"check_same_thread": False}
    })

engine = create_engine(db_url, **engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

CREATE_ITEMS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
"""


def init_db_with_retry() -> bool:
    """
    Attempts to connect to the database and initialize tables using exponential backoff.
    Gracefully handles database unavailability during startup without crashing the container.
    """
    if str(engine.url).startswith("sqlite"):
        logger.info("SQLite environment detected. Creating tables via metadata...")
        Base.metadata.create_all(bind=engine)
        return True

    max_retries = settings.db_connect_retries
    delay = settings.db_retry_delay
    
    logger.info("Initializing database connection...")
    for attempt in range(1, max_retries + 1):
        try:
            with engine.connect() as conn:
                logger.info("Testing database connection (attempt %d/%d)...", attempt, max_retries)
                conn.execute(text("SELECT 1"))
                logger.info("Database connection successful. Executing table initialization...")
                try:
                    conn.execute(text(CREATE_ITEMS_TABLE_SQL))
                    conn.commit()
                except Exception as ddl_err:
                    logger.warning("Direct DDL failed (%s), falling back to Base.metadata.create_all...", ddl_err)
                    Base.metadata.create_all(bind=engine)
                logger.info("Database initialized successfully.")
                return True
        except (OperationalError, SQLAlchemyError, Exception) as err:
            logger.warning(
                "Database connection attempt %d/%d failed: %s. Retrying in %.1f seconds...",
                attempt, max_retries, err, delay
            )
            if attempt < max_retries:
                time.sleep(delay)
                delay = min(delay * 2, 30.0)  # Exponential backoff capped at 30 seconds
            else:
                logger.error(
                    "Exhausted all %d database connection attempts during startup. "
                    "Container will continue running; subsequent requests will degrade gracefully.",
                    max_retries
                )
    return False


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency for database session management."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
