import os
import json
import asyncio
from datetime import datetime, date
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ReturnDocument
import bcrypt

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

MONGO_URI = os.getenv(
    "MONGO_URI",
    "mongodb+srv://sathvikach5134sse_db_user:sathwika2005@stockmate-pro.sfmqgwe.mongodb.net/?retryWrites=true&w=majority&appName=StockMate-Pro"
)
DB_NAME = os.getenv("DB_NAME", "stockmate_pro")

# Initialize Motor Client with 2-second timeout
try:
    client = AsyncIOMotorClient(
        MONGO_URI,
        serverSelectionTimeoutMS=2000,
        connectTimeoutMS=2000,
        socketTimeoutMS=2000,
    )
    db = client[DB_NAME]
    raw_users_collection = db["users"]
    raw_products_collection = db["products"]
    raw_sales_collection = db["sales"]
    raw_counters_collection = db["counters"]
except Exception:
    client = None
    db = None
    raw_users_collection = None
    raw_products_collection = None
    raw_sales_collection = None
    raw_counters_collection = None

# Online state cache
_mongo_online = None

async def is_mongo_online() -> bool:
    global _mongo_online
    if _mongo_online is False:
        return False
    if client is None:
        _mongo_online = False
        return False
    try:
        await asyncio.wait_for(client.admin.command('ping'), timeout=1.5)
        _mongo_online = True
        return True
    except Exception:
        _mongo_online = False
        return False

# Local JSON Store for fallback / offline execution
LOCAL_DB_FILE = os.path.join(os.path.dirname(__file__), "stockmate_local_db.json")

def load_local_data() -> dict:
    if os.path.exists(LOCAL_DB_FILE):
        try:
            with open(LOCAL_DB_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "users": [],
        "products": [],
        "sales": [],
        "counters": [{"id": "user_id", "seq": 1}, {"id": "product_id", "seq": 1}, {"id": "sale_id", "seq": 1}]
    }

def save_local_data(data: dict):
    try:
        def serialize_item(obj):
            if isinstance(obj, (datetime, date)):
                return obj.isoformat()
            if isinstance(obj, dict):
                return {k: serialize_item(v) for k, v in obj.items() if k != "_id"}
            if isinstance(obj, list):
                return [serialize_item(x) for x in obj]
            return obj
        clean = serialize_item(data)
        with open(LOCAL_DB_FILE, "w", encoding="utf-8") as f:
            json.dump(clean, f, indent=2)
    except Exception as e:
        print(f"[save_local_data error]: {e}")

_local_lock = asyncio.Lock()

class ResilientCollection:
    def __init__(self, collection_name: str, mongo_col):
        self.name = collection_name
        self.mongo_col = mongo_col

    def _matches(self, doc: dict, query: dict) -> bool:
        for k, v in query.items():
            if k == "$or" and isinstance(v, list):
                if not any(self._matches(doc, cond) for cond in v):
                    return False
                continue
            if isinstance(v, dict):
                if "$gte" in v and doc.get(k, 0) < v["$gte"]:
                    return False
                if "$regex" in v:
                    import re
                    pattern = v["$regex"]
                    flags = re.I if "i" in v.get("$options", "") else 0
                    if not re.search(pattern, str(doc.get(k, "")), flags):
                        return False
            else:
                if doc.get(k) != v:
                    return False
        return True

    def find(self, query: dict = None):
        query = query or {}
        async def _run_find():
            online = await is_mongo_online()
            if online and self.mongo_col is not None:
                try:
                    cursor = self.mongo_col.find(query)
                    items = await cursor.to_list(length=1000)
                    return items
                except Exception:
                    pass
            # Fallback to local data
            async with _local_lock:
                data = load_local_data()
                coll = data.get(self.name, [])
                matched = [dict(d) for d in coll if self._matches(d, query)]
                return matched

        class AsyncCursorWrapper:
            def __init__(self, runner, query_dict, col_name, matches_fn):
                self._runner = runner
                self._sort_key = None
                self._sort_dir = 1
                self._query = query_dict
                self._col_name = col_name
                self._matches_fn = matches_fn

            def sort(self, key: str, direction: int = 1):
                self._sort_key = key
                self._sort_dir = direction
                return self

            async def to_list(self, length: int = 1000) -> list:
                items = await self._runner()
                if self._sort_key:
                    reverse = (self._sort_dir == -1)
                    items.sort(key=lambda x: str(x.get(self._sort_key, "")), reverse=reverse)
                return items[:length]

        return AsyncCursorWrapper(_run_find, query, self.name, self._matches)

    async def find_one(self, query: dict) -> dict:
        online = await is_mongo_online()
        if online and self.mongo_col is not None:
            try:
                res = await self.mongo_col.find_one(query)
                if res:
                    return res
            except Exception:
                pass
        async with _local_lock:
            data = load_local_data()
            coll = data.get(self.name, [])
            for d in coll:
                if self._matches(d, query):
                    return dict(d)
        return None

    async def insert_one(self, doc: dict):
        online = await is_mongo_online()
        if online and self.mongo_col is not None:
            try:
                await self.mongo_col.insert_one(dict(doc))
            except Exception:
                pass
        async with _local_lock:
            data = load_local_data()
            data.setdefault(self.name, []).append(dict(doc))
            save_local_data(data)

    async def update_one(self, filter_q: dict, update_q: dict, upsert: bool = False):
        online = await is_mongo_online()
        if online and self.mongo_col is not None:
            try:
                await self.mongo_col.update_one(filter_q, update_q, upsert=upsert)
            except Exception:
                pass
        async with _local_lock:
            data = load_local_data()
            coll = data.setdefault(self.name, [])
            found = False
            for idx, d in enumerate(coll):
                if self._matches(d, filter_q):
                    found = True
                    if "$set" in update_q:
                        d.update(update_q["$set"])
                    if "$inc" in update_q:
                        for ik, iv in update_q["$inc"].items():
                            d[ik] = d.get(ik, 0) + iv
                    coll[idx] = d
                    break
            if not found and upsert:
                new_doc = dict(filter_q)
                if "$set" in update_q:
                    new_doc.update(update_q["$set"])
                coll.append(new_doc)
            save_local_data(data)

    async def find_one_and_update(self, filter_q: dict, update_q: dict, upsert: bool = False, return_document=None):
        online = await is_mongo_online()
        if online and self.mongo_col is not None:
            try:
                res = await self.mongo_col.find_one_and_update(filter_q, update_q, upsert=upsert, return_document=return_document)
                if res:
                    return res
            except Exception:
                pass
        async with _local_lock:
            data = load_local_data()
            coll = data.setdefault(self.name, [])
            for idx, d in enumerate(coll):
                if self._matches(d, filter_q):
                    if "$inc" in update_q:
                        for ik, iv in update_q["$inc"].items():
                            d[ik] = d.get(ik, 0) + iv
                    if "$set" in update_q:
                        d.update(update_q["$set"])
                    coll[idx] = d
                    save_local_data(data)
                    return dict(d)
            if upsert:
                new_doc = dict(filter_q)
                if "$inc" in update_q:
                    for ik, iv in update_q["$inc"].items():
                        new_doc[ik] = iv
                if "$set" in update_q:
                    new_doc.update(update_q["$set"])
                coll.append(new_doc)
                save_local_data(data)
                return dict(new_doc)
        return None

    async def delete_one(self, filter_q: dict):
        deleted_count = 0
        online = await is_mongo_online()
        if online and self.mongo_col is not None:
            try:
                res = await self.mongo_col.delete_one(filter_q)
                deleted_count = res.deleted_count
            except Exception:
                pass
        async with _local_lock:
            data = load_local_data()
            coll = data.get(self.name, [])
            initial_len = len(coll)
            coll = [d for d in coll if not self._matches(d, filter_q)]
            if len(coll) < initial_len:
                deleted_count = 1
                data[self.name] = coll
                save_local_data(data)
        class DeleteResult:
            def __init__(self, count):
                self.deleted_count = count
        return DeleteResult(deleted_count)

    async def create_index(self, *args, **kwargs):
        online = await is_mongo_online()
        if online and self.mongo_col is not None:
            try:
                await self.mongo_col.create_index(*args, **kwargs)
            except Exception:
                pass

users_collection = ResilientCollection("users", raw_users_collection)
products_collection = ResilientCollection("products", raw_products_collection)
sales_collection = ResilientCollection("sales", raw_sales_collection)
counters_collection = ResilientCollection("counters", raw_counters_collection)


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password or not plain_password:
        return False
    try:
        if hashed_password.startswith("$2b$") or hashed_password.startswith("$2a$"):
            return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
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
    try:
        online = await is_mongo_online()
        if online and raw_users_collection is not None:
            await users_collection.create_index("email", unique=True)
            await users_collection.create_index("id", unique=True)
            await products_collection.create_index("id", unique=True)
            await products_collection.create_index("user_id")
            await sales_collection.create_index("id", unique=True)
            await sales_collection.create_index("user_id")
            await counters_collection.create_index("id", unique=True)
    except Exception as e:
        print(f"[init_db notice]: {e}")