import logging
import uuid
from typing import List
from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.database import get_db
from app.models import Item
from app.schemas import HealthResponse, ItemCreate, ItemResponse

logger = logging.getLogger("api.routes")
router = APIRouter()


@router.get("/health", response_model=HealthResponse, status_code=status.HTTP_200_OK)
def health_check():
    """
    Lightweight health check endpoint for Load Balancers and ECS orchestration.
    Must return HTTP 200 OK with {"status": "healthy"}.
    """
    return {"status": "healthy"}


@router.post(
    "/items",
    response_model=ItemResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        201: {"description": "Item successfully created"},
        500: {"description": "Database connection or execution failure"}
    }
)
def create_item(item_in: ItemCreate, db: Session = Depends(get_db)):
    """
    Accepts JSON payload with name and optional description.
    Inserts a new record into the items table with a generated UUID primary key and timestamp.
    Returns HTTP 201 Created with the persisted item.
    """
    try:
        new_item = Item(
            id=uuid.uuid4(),
            name=item_in.name,
            description=item_in.description
        )
        db.add(new_item)
        db.commit()
        db.refresh(new_item)
        return new_item
    except SQLAlchemyError as err:
        db.rollback()
        logger.error("Failed to insert item into database: %s", err)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": "Database error", "message": "Failed to persist item due to a database error."}
        )
    except Exception as err:
        db.rollback()
        logger.error("Unexpected error during item creation: %s", err)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": "Internal Server Error", "message": "An unexpected error occurred."}
        )


@router.get(
    "/items",
    response_model=List[ItemResponse],
    status_code=status.HTTP_200_OK,
    responses={
        200: {"description": "List of items successfully retrieved"},
        500: {"description": "Database connection or execution failure"}
    }
)
def list_items(db: Session = Depends(get_db)):
    """
    Queries the database for all items.
    Returns HTTP 200 OK with a JSON array of serialized item objects.
    """
    try:
        items = db.query(Item).order_by(Item.created_at.desc()).all()
        return items
    except SQLAlchemyError as err:
        logger.error("Failed to retrieve items from database: %s", err)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": "Database error", "message": "Failed to retrieve items due to a database error."}
        )
    except Exception as err:
        logger.error("Unexpected error during item retrieval: %s", err)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"error": "Internal Server Error", "message": "An unexpected error occurred."}
        )
