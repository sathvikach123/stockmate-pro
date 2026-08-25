import os
import json
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ReturnDocument
import bcrypt

load_dotenv()

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb+srv://sathvikach5134sse_db_user:sathwika2005@stockmate-pro.sfmqgwe.mongodb.net/?retryWrites=true&w=majority&appName=StockMate-Pro"
)
DB_NAME = os.getenv("DB_NAME", "stockmate_pro")

client = AsyncIOMotorClient(MONGO_URI)
db = client[DB_NAME]

users_collection = db["users"]
products_collection = db["products"]
sales_collection = db["sales"]
counters_collection = db["counters"]


def hash_password(password: str) -> str:
    """Hashes a password with a secure salt using bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifies a plain password against the stored bcrypt hash."""
    if not hashed_password or not plain_password:
        return False
    try:
        if hashed_password.startswith("$2b$") or hashed_password.startswith("$2a$"):
            return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
        # Fallback for plain-text legacy passwords before migration
        return plain_password == hashed_password
    except Exception:
        return False


async def get_next_sequence(sequence_name: str) -> int:
    doc = await counters_collection.find_one_and_update(
        {"id": sequence_name},
        {"$inc": {"seq": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER
    )
    if doc and "seq" in doc:
        return int(doc["seq"])
    return 1


async def init_db():
    """
    Initializes MongoDB collections and indexes, ensures all user passwords
    are securely hashed, and migrates local JSON data if MongoDB is fresh.
    """
    try:
        # Create indexes for optimal query speed and uniqueness
        await users_collection.create_index("email", unique=True)
        await users_collection.create_index("id", unique=True)
        await products_collection.create_index("id", unique=True)
        await products_collection.create_index("user_id")
        await sales_collection.create_index("id", unique=True)
        await sales_collection.create_index("user_id")
        await counters_collection.create_index("id", unique=True)

        # 1. Ensure all existing passwords in MongoDB are securely hashed (no plaintext)
        async for user in users_collection.find({}):
            pwd = user.get("password", "")
            if pwd and not (pwd.startswith("$2b$") or pwd.startswith("$2a$")):
                hashed = hash_password(pwd)
                await users_collection.update_one(
                    {"_id": user["_id"]},
                    {"$set": {"password": hashed}}
                )

        # 2. Migrate local JSON data if it exists and MongoDB users collection is empty
        db_file = os.path.join(os.path.dirname(__file__), "stockmate_local_db.json")
        if os.path.exists(db_file):
            try:
                with open(db_file, "r", encoding="utf-8") as f:
                    local_data = json.load(f)

                # Migrate Users
                user_count = await users_collection.count_documents({})
                if user_count == 0 and local_data.get("users"):
                    for u in local_data["users"]:
                        item = dict(u)
                        if isinstance(item.get("created_at"), str):
                            try:
                                item["created_at"] = datetime.fromisoformat(item["created_at"])
                            except Exception:
                                pass
                        if item.get("password") and not item["password"].startswith("$2b$"):
                            item["password"] = hash_password(item["password"])
                        await users_collection.update_one({"id": item["id"]}, {"$set": item}, upsert=True)

                # Migrate Products
                prod_count = await products_collection.count_documents({})
                if prod_count == 0 and local_data.get("products"):
                    for p in local_data["products"]:
                        item = dict(p)
                        for df in ["created_at", "updated_at"]:
                            if isinstance(item.get(df), str):
                                try:
                                    item[df] = datetime.fromisoformat(item[df])
                                except Exception:
                                    pass
                        await products_collection.update_one({"id": item["id"]}, {"$set": item}, upsert=True)

                # Migrate Sales
                sales_count = await sales_collection.count_documents({})
                if sales_count == 0 and local_data.get("sales"):
                    for s in local_data["sales"]:
                        item = dict(s)
                        if isinstance(item.get("sale_date"), str):
                            try:
                                item["sale_date"] = datetime.fromisoformat(item["sale_date"])
                            except Exception:
                                pass
                        await sales_collection.update_one({"id": item["id"]}, {"$set": item}, upsert=True)

                # Migrate Counters
                for c in local_data.get("counters", []):
                    await counters_collection.update_one(
                        {"id": c["id"]},
                        {"$set": {"seq": int(c["seq"])}},
                        upsert=True
                    )
            except Exception as e:
                print(f"[init_db] Notice during migration: {e}")
    except Exception as e:
        print(f"[init_db] Notice during initialization: {e}")