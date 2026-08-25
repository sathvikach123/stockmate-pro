# StockMate Pro — FastAPI + MongoDB Backend

FastAPI backend with CORS enabled, asynchronous MongoDB driver (`motor`), and auto-increment sequence support for the StockMate Pro Flutter application.

## 🚀 Features
- **MongoDB Atlas Integration**: Pre-configured with your MongoDB Atlas cluster.
- **Full CORS Support**: Solves Flutter Web (`http://localhost:*`) CORS preflight blocks.
- **Integer ID Compatibility**: Auto-increments numeric IDs (`id: int`, `user_id: int`) seamlessly matching Flutter models.
- **Inventory Management**: CRUD operations, fuzzy search, categories, and real-time stock/expiry alerts.
- **Atomic Sales Deduction**: Uses MongoDB's atomic `$inc` with quantity thresholds to prevent negative inventory / overselling.
- **Analytics & Dashboard**: Real-time aggregations (today's revenue, 7-day trend, top products, total valuation).

---

## 🛠 Local Setup & Running

1. Open your terminal in the backend directory:
   ```bash
   cd backend
   ```

2. (Optional) Create and activate a virtual environment:
   ```bash
   python -m venv venv
   # Windows:
   .\venv\Scripts\activate
   # Mac/Linux:
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Start the FastAPI server:
   ```bash
   uvicorn main:app --reload --port 8000
   ```

5. Open the interactive API documentation (Swagger UI):
   - **http://127.0.0.1:8000/docs**

---

## 🌐 Deploying to Railway / Render

1. Create a GitHub repository for your `backend` folder and push your code.
2. In **Railway** (or **Render**):
   - Create a **New Service** from your GitHub repo.
   - In Environment Variables, set:
     - `MONGO_URI`: `mongodb+srv://sathvikach5134sse_db_user:GCyiaPSxXGu5E01U@stockmate-pro.sfmqgwe.mongodb.net/?retryWrites=true&w=majority&appName=StockMate-Pro`
     - `DB_NAME`: `stockmate_pro`
3. Copy your deployed domain (e.g. `https://stockmate-api.up.railway.app`) and update `ApiUrl.base` in `lib/api_urls.dart`.
