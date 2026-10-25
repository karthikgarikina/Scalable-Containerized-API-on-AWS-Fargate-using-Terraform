import uuid
from sqlalchemy import Column, String, Text, DateTime, func, Uuid
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class Item(Base):
    __tablename__ = "items"

    id = Column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4
    )
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=func.now(),
        nullable=False
    )
