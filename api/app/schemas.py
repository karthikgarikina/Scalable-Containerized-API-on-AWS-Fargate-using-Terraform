from uuid import UUID
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    status: str = "healthy"


class ItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Item name")
    description: Optional[str] = Field(default=None, description="Item description")


class ItemResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
