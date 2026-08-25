import os
from datetime import datetime, date, timedelta
from typing import Optional, List
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pymongo import ReturnDocument
from database import (
    users_collection,
    products_collection,
    sales_collection,
    counters_collection,
    get_next_sequence,
    init_db,
    hash_password,
    verify_password,
)
from contextlib import asynccontextmanager
import schemas

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(
    title="StockMate Pro API (MongoDB)",
    description="FastAPI + MongoDB backend for StockMate Pro Inventory and Sales Management",
    version="1.0.0",
    lifespan=lifespan,
)

# ── Enable CORS for all origins (eliminates Flutter Web CORS preflight blocks) ──
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["*"],
)


# â”€â”€ Product computed flags & profit margin helper â”€â”€
def enrich_product(p: dict) -> dict:
    today = date.today()
    exp_str = p.get("expiry_date")
    days_left = None

    if exp_str:
        try:
            exp_date = datetime.fromisoformat(str(exp_str).split("T")[0]).date()
            days_left = (exp_date - today).days
        except Exception:
            days_left = None

    qty = int(p.get("quantity", 0))
    low_thresh = int(p.get("low_stock_threshold", 10))

    is_expired = days_left is not None and days_left < 0
    is_expiring_soon = days_left is not None and 0 <= days_left <= 7
    is_low_stock = 0 < qty <= low_thresh
    is_out_of_stock = qty <= 0

    price = float(p.get("price", 0.0))
    cost_price = float(p.get("cost_price", 0.0))
    profit_margin = 0.0
    if price > 0:
        profit_margin = round(((price - cost_price) / price) * 100, 2)

    created_at = p.get("created_at")
    if isinstance(created_at, datetime):
        created_at = created_at.isoformat()

    updated_at = p.get("updated_at")
    if isinstance(updated_at, datetime):
        updated_at = updated_at.isoformat()

    return {
        "id": int(p.get("id", p.get("_id", 0))),
        "user_id": int(p.get("user_id", 0)),
        "name": p.get("name", ""),
        "sku": p.get("sku", ""),
        "category": p.get("category", "other"),
        "price": price,
        "cost_price": cost_price,
        "quantity": qty,
        "low_stock_threshold": low_thresh,
        "expiry_date": exp_str,
        "brand": p.get("brand"),
        "unit": p.get("unit", "piece"),
        "is_expired": is_expired,
        "is_expiring_soon": is_expiring_soon,
        "is_low_stock": is_low_stock,
        "is_out_of_stock": is_out_of_stock,
        "days_until_expiry": days_left,
        "profit_margin": profit_margin,
        "created_at": created_at,
        "updated_at": updated_at,
    }


# â”€â”€â”€ Health / Root â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@app.get("/")
async def root():
    return {"status": "ok", "app": "StockMate Pro MongoDB API"}


# â”€â”€â”€ Auth Endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@app.post("/signup", status_code=status.HTTP_201_CREATED)
async def signup(data: schemas.UserSignup):
    existing = await users_collection.find_one({"email": data.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = await get_next_sequence("user_id")
    hashed_password = hash_password(data.password)
    user_doc = {
        "id": user_id,
        "name": data.name,
        "email": data.email,
        "password": hashed_password,
        "store_name": data.store_name or "My Store",
        "created_at": datetime.utcnow(),
    }
    await users_collection.insert_one(user_doc)

    return {
        "user": {
            "id": user_id,
            "name": user_doc["name"],
            "email": user_doc["email"],
            "store_name": user_doc["store_name"],
        }
    }


@app.post("/login")
async def login(data: schemas.UserLogin):
    user = await users_collection.find_one({"email": data.email})
    if not user or not verify_password(data.password, user.get("password", "")):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return {
        "user": {
            "id": int(user["id"]),
            "name": user["name"],
            "email": user["email"],
            "store_name": user.get("store_name", "My Store"),
        }
    }


@app.post("/logout")
async def logout(data: schemas.UserLogout):
    return {"message": "Logged out successfully"}


@app.get("/get_current_user")
async def get_current_user():
    return {"status": "authenticated"}


# â”€â”€â”€ Product Endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@app.get("/products/{user_id}")
async def get_products(user_id: int, category: Optional[str] = None):
    query = {"user_id": user_id}
    if category and category.lower() != "all":
        query["category"] = category.lower()

    cursor = products_collection.find(query).sort("id", -1)
    products = await cursor.to_list(length=1000)
    return [enrich_product(p) for p in products]


@app.get("/products/search/{user_id}")
async def search_products(user_id: int, q: str = ""):
    query = {"user_id": user_id}
    if q:
        query["$or"] = [
            {"name": {"$regex": q, "$options": "i"}},
            {"sku": {"$regex": q, "$options": "i"}},
            {"brand": {"$regex": q, "$options": "i"}},
        ]

    cursor = products_collection.find(query)
    products = await cursor.to_list(length=1000)
    return [enrich_product(p) for p in products]


@app.get("/products/alerts/{user_id}")
async def get_alerts(user_id: int):
    cursor = products_collection.find({"user_id": user_id})
    products = await cursor.to_list(length=1000)
    enriched = [enrich_product(p) for p in products]

    low_stock = [p for p in enriched if p["is_low_stock"] or p["is_out_of_stock"]]
    expired = [p for p in enriched if p["is_expired"]]
    expiring_soon = [p for p in enriched if p["is_expiring_soon"]]

    return {
        "low_stock": low_stock,
        "expired": expired,
        "expiring_soon": expiring_soon,
        "total_alerts": len(low_stock) + len(expired) + len(expiring_soon),
    }


@app.post("/products", status_code=status.HTTP_201_CREATED)
async def add_product(data: schemas.ProductCreate):
    prod_id = await get_next_sequence("product_id")
    now = datetime.utcnow()
    product_doc = {
        "id": prod_id,
        "user_id": data.user_id,
        "name": data.name,
        "sku": data.sku or "",
        "category": data.category or "other",
        "price": data.price,
        "cost_price": data.cost_price,
        "quantity": data.quantity,
        "low_stock_threshold": data.low_stock_threshold or 10,
        "expiry_date": data.expiry_date,
        "brand": data.brand,
        "unit": data.unit or "piece",
        "created_at": now,
        "updated_at": now,
    }
    await products_collection.insert_one(product_doc)
    return enrich_product(product_doc)


@app.put("/products/{product_id}")
async def update_product(product_id: int, data: schemas.ProductUpdate):
    update_data = {k: v for k, v in data.dict().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields provided to update")

    update_data["updated_at"] = datetime.utcnow()

    updated_doc = await products_collection.find_one_and_update(
        {"id": product_id},
        {"$set": update_data},
        return_document=ReturnDocument.AFTER,
    )
    if not updated_doc:
        raise HTTPException(status_code=404, detail="Product not found")

    return enrich_product(updated_doc)


@app.patch("/products/{product_id}/quantity")
async def update_quantity(product_id: int, data: schemas.ProductQuantityUpdate):
    updated_doc = await products_collection.find_one_and_update(
        {"id": product_id},
        {"$set": {"quantity": data.quantity, "updated_at": datetime.utcnow()}},
        return_document=ReturnDocument.AFTER,
    )
    if not updated_doc:
        raise HTTPException(status_code=404, detail="Product not found")

    return enrich_product(updated_doc)


@app.delete("/products/{product_id}")
async def delete_product(product_id: int):
    res = await products_collection.delete_one({"id": product_id})
    if res.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Product not found")
    return {"message": "Product deleted successfully"}


# ── Sales Endpoints ──────────────────────────────────────────────────────────

@app.get("/sales/{user_id}")
async def get_sales(user_id: int):
    cursor = sales_collection.find({"user_id": user_id}).sort("sale_date", -1)
    sales = await cursor.to_list(length=1000)
    return [
        {
            "id": int(s["id"]),
            "user_id": int(s["user_id"]),
            "product_id": int(s["product_id"]),
            "product_name": s.get("product_name", ""),
            "quantity_sold": int(s.get("quantity_sold", 0)),
            "sale_price": float(s.get("sale_price", 0.0)),
            "total_amount": float(s.get("total_amount", 0.0)),
            "sale_date": s["sale_date"].isoformat() if isinstance(s.get("sale_date"), datetime) else str(s.get("sale_date")),
            "note": s.get("note"),
        }
        for s in sales
    ]


@app.post("/sales", status_code=status.HTTP_201_CREATED)
async def record_sale(data: schemas.SaleCreate):
    # 1. Atomic decrement only if sufficient quantity exists in MongoDB
    product = await products_collection.find_one_and_update(
        {
            "id": data.product_id,
            "quantity": {"$gte": data.quantity_sold}
        },
        {
            "$inc": {"quantity": -data.quantity_sold},
            "$set": {"updated_at": datetime.utcnow()}
        },
        return_document=ReturnDocument.AFTER
    )

    if not product:
        # Check if product exists at all or just insufficient quantity
        prod_exists = await products_collection.find_one({"id": data.product_id})
        if not prod_exists:
            raise HTTPException(status_code=404, detail="Product not found")
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient stock (Only {prod_exists.get('quantity', 0)} left)"
        )

    # 2. Insert sale record
    sale_id = await get_next_sequence("sale_id")
    sale_date = datetime.utcnow()
    sale_doc = {
        "id": sale_id,
        "user_id": data.user_id,
        "product_id": data.product_id,
        "product_name": data.product_name,
        "quantity_sold": data.quantity_sold,
        "sale_price": data.sale_price,
        "total_amount": data.total_amount,
        "note": data.note,
        "sale_date": sale_date,
    }
    await sales_collection.insert_one(sale_doc)

    return {
        "id": sale_id,
        "user_id": sale_doc["user_id"],
        "product_id": sale_doc["product_id"],
        "product_name": sale_doc["product_name"],
        "quantity_sold": sale_doc["quantity_sold"],
        "sale_price": sale_doc["sale_price"],
        "total_amount": sale_doc["total_amount"],
        "sale_date": sale_date.isoformat(),
        "note": sale_doc["note"],
    }


@app.delete("/sales/{sale_id}")
async def delete_sale(sale_id: int):
    res = await sales_collection.delete_one({"id": sale_id})
    if res.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Sale not found")
    return {"message": "Sale deleted successfully"}


# â”€â”€â”€ Dashboard & Analytics â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@app.get("/dashboard/{user_id}")
@app.get("/analytics/{user_id}")
async def get_dashboard(user_id: int):
    now = datetime.utcnow()
    today_start = datetime(now.year, now.month, now.day)
    seven_days_ago = today_start - timedelta(days=6)

    # 1. Products metrics
    cursor = products_collection.find({"user_id": user_id})
    products = await cursor.to_list(length=1000)

    total_products = len(products)
    total_stock_value = sum(
        float(p.get("cost_price", 0.0)) * int(p.get("quantity", 0)) for p in products
    )

    # Category counts
    category_counts = {}
    for p in products:
        cat = p.get("category", "other")
        category_counts[cat] = category_counts.get(cat, 0) + 1

    # Alerts count
    enriched = [enrich_product(p) for p in products]
    low_stock_count = sum(1 for p in enriched if p["is_low_stock"])
    out_of_stock_count = sum(1 for p in enriched if p["is_out_of_stock"])
    expired_count = sum(1 for p in enriched if p["is_expired"])
    expiring_soon_count = sum(1 for p in enriched if p["is_expiring_soon"])

    alerts = {
        "low_stock": low_stock_count,
        "out_of_stock": out_of_stock_count,
        "expired": expired_count,
        "expiring_soon": expiring_soon_count,
        "total": low_stock_count + out_of_stock_count + expired_count + expiring_soon_count,
    }

    # 2. Sales metrics
    sales_cursor = sales_collection.find({"user_id": user_id}).sort("sale_date", -1)
    all_sales = await sales_cursor.to_list(length=2000)

    total_txns = len(all_sales)
    total_revenue = sum(float(s.get("total_amount", 0.0)) for s in all_sales)

    today_revenue = 0.0
    week_revenue = 0.0

    for s in all_sales:
        s_date = s.get("sale_date")
        if isinstance(s_date, datetime):
            if s_date >= today_start:
                today_revenue += float(s.get("total_amount", 0.0))
            if s_date >= seven_days_ago:
                week_revenue += float(s.get("total_amount", 0.0))

    # 7-day chart data
    chart_data = []
    for i in range(7):
        day_date = (seven_days_ago + timedelta(days=i)).date()
        day_sales = [
            s for s in all_sales
            if isinstance(s.get("sale_date"), datetime) and s["sale_date"].date() == day_date
        ]
        chart_data.append({
            "day": day_date.strftime("%a"),
            "date": day_date.isoformat(),
            "revenue": round(sum(float(s.get("total_amount", 0.0)) for s in day_sales), 2),
            "orders": len(day_sales),
        })

    # Top selling products
    product_sales_map = {}
    for s in all_sales:
        p_name = s.get("product_name", "Unknown")
        if p_name not in product_sales_map:
            product_sales_map[p_name] = {"name": p_name, "quantity": 0, "revenue": 0.0}
        product_sales_map[p_name]["quantity"] += int(s.get("quantity_sold", 0))
        product_sales_map[p_name]["revenue"] += float(s.get("total_amount", 0.0))

    top_products = sorted(
        product_sales_map.values(), key=lambda x: x["revenue"], reverse=True
    )[:5]

    recent_sales = [
        {
            "id": int(s["id"]),
            "user_id": int(s["user_id"]),
            "product_id": int(s["product_id"]),
            "product_name": s.get("product_name", ""),
            "quantity_sold": int(s.get("quantity_sold", 0)),
            "sale_price": float(s.get("sale_price", 0.0)),
            "total_amount": float(s.get("total_amount", 0.0)),
            "sale_date": s["sale_date"].isoformat() if isinstance(s.get("sale_date"), datetime) else str(s.get("sale_date")),
            "note": s.get("note"),
        }
        for s in all_sales[:10]
    ]

    return {
        "total_products": total_products,
        "total_stock_value": round(total_stock_value, 2),
        "today_revenue": round(today_revenue, 2),
        "week_revenue": round(week_revenue, 2),
        "total_revenue": round(total_revenue, 2),
        "total_transactions": total_txns,
        "alerts": alerts,
        "recent_sales": recent_sales,
        "chart_data": chart_data,
        "top_products": top_products,
        "category_counts": category_counts,
    }

