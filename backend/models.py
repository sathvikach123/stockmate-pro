from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel, Field

class UserDocument(BaseModel):
    id: int
    name: str
    email: str
    password: str
    store_name: str = "My Store"
    created_at: datetime = Field(default_factory=datetime.utcnow)

class ProductDocument(BaseModel):
    id: int
    user_id: int
    name: str
    sku: str = ""
    category: str = "other"
    price: float
    cost_price: float
    quantity: int = 0
    low_stock_threshold: int = 10
    expiry_date: Optional[str] = None
    brand: Optional[str] = None
    unit: str = "piece"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class SaleDocument(BaseModel):
    id: int
    user_id: int
    product_id: int
    product_name: str
    quantity_sold: int
    sale_price: float
    total_amount: float
    sale_date: datetime = Field(default_factory=datetime.utcnow)
    note: Optional[str] = None
