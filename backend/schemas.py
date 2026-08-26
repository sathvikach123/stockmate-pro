from datetime import date, datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, EmailStr

# ── User Schemas ─────────────────────────────────────────────────────────────
class UserSignup(BaseModel):
    name: str
    email: EmailStr
    password: str
    store_name: Optional[str] = "My Store"

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserLogout(BaseModel):
    email: EmailStr

# ── Product Schemas ──────────────────────────────────────────────────────────
class ProductCreate(BaseModel):
    user_id: int
    name: str
    sku: Optional[str] = ""
    category: Optional[str] = "other"
    price: float
    cost_price: float
    quantity: int
    low_stock_threshold: Optional[int] = 10
    expiry_date: Optional[str] = None
    brand: Optional[str] = None
    unit: Optional[str] = "piece"

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    sku: Optional[str] = None
    category: Optional[str] = None
    price: Optional[float] = None
    cost_price: Optional[float] = None
    quantity: Optional[int] = None
    low_stock_threshold: Optional[int] = None
    expiry_date: Optional[str] = None
    brand: Optional[str] = None
    unit: Optional[str] = None

class ProductQuantityUpdate(BaseModel):
    quantity: int

# ── Sale Schemas ─────────────────────────────────────────────────────────────
class SaleCreate(BaseModel):
    user_id: int
    product_id: int
    product_name: Optional[str] = None
    quantity_sold: int
    sale_price: Optional[float] = None
    total_amount: Optional[float] = None
    note: Optional[str] = None
