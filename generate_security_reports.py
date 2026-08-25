"""
StockMate Pro - Security Assessment Excel Report & Inventory Generator
Generates:
1. Vulnerability Test Results/findings.xlsx (4 Sheets: Security Findings, Endpoint Inventory, Dependency Vulnerabilities, Risk Summary)
2. Vulnerability Test Results/endpoint-inventory.xlsx
"""

import os
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

OUT_DIR = os.path.join(os.path.dirname(__file__), "Vulnerability Test Results")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Color Palette & Styles ──
NAVY = "1A365D"
BLUE_HEADER = "2B6CB0"
WHITE = "FFFFFF"
BORDER_COLOR = "CBD5E0"
GREEN_PASS = "22543D"
GREEN_BG = "C6F6D5"
RED_CRIT = "742A2A"
RED_BG = "FED7D7"
ORANGE_HIGH = "7B341E"
ORANGE_BG = "FEEBC8"
YELLOW_MED = "744210"
YELLOW_BG = "FEFCBF"
BLUE_LOW = "2C5282"
BLUE_BG = "BEE3F8"

header_font = Font(name="Calibri", size=14, bold=True, color=WHITE)
tbl_hdr_font = Font(name="Calibri", size=11, bold=True, color=WHITE)
body_font = Font(name="Calibri", size=10, color="2D3748")
bold_body = Font(name="Calibri", size=10, bold=True, color="1A202C")
section_font = Font(name="Calibri", size=12, bold=True, color=NAVY)

thin_border = Border(
    left=Side(style='thin', color=BORDER_COLOR),
    right=Side(style='thin', color=BORDER_COLOR),
    top=Side(style='thin', color=BORDER_COLOR),
    bottom=Side(style='thin', color=BORDER_COLOR)
)

# ── Data Definitions ──
FINDINGS_DATA = [
    ("SEC-01", "CWE-798: Use of Hard-coded Credentials", "Critical", "backend/database.py:14-15 & backend/.env:1",
     "Database Connection / Motor Client", "Hardcoded live MongoDB Atlas credentials (user/password) committed in source code and .env.",
     "Direct connection to production database by unauthorized entities resulting in complete cluster control and data destruction.",
     "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H (9.8)", "Rotate Atlas password immediately; enforce runtime env var requirement; gitignore secrets."),
    
    ("SEC-02", "CWE-639: Broken Object-Level Auth (BOLA / IDOR)", "Critical", "backend/main.py:167-363",
     "GET /products/{user_id}, GET /dashboard/{user_id}, PUT /products/{id}, DELETE /products/{id}",
     "APIs accept arbitrary user_id / product_id in paths without validating requesting caller's token ownership.",
     "Cross-tenant data theft, financial metrics scraping, and deletion of competitor inventory records.",
     "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N (9.1)", "Implement JWT authentication; extract user_id strictly from verified JWT token context."),

    ("SEC-03", "CWE-306: Missing Token-Based Authentication", "High", "backend/main.py:139-163",
     "POST /login, GET /get_current_user, POST /logout",
     "/login does not issue signed JWT tokens; system relies on stateless client parameter trust.",
     "Authentication bypass allowing direct API invocation by unauthorized clients.",
     "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:L/A:N (8.2)", "Integrate PyJWT / python-jose to sign and verify HMAC-SHA256 bearer tokens."),

    ("SEC-04", "CWE-942: Overly Permissive Wildcard CORS", "Medium", "backend/main.py:33-40",
     "CORSMiddleware (allow_origins=['*'])",
     "Wildcard origin and header configuration allows arbitrary external web domains to invoke API endpoints.",
     "Cross-origin request abuse from malicious client browsers.",
     "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N (5.3)", "Restrict allow_origins to explicit production and staging frontend domains."),

    ("SEC-05", "CWE-307: Missing Rate Limiting & Anti-Brute-Force", "Medium", "backend/main.py:111, 139",
     "POST /login, POST /signup",
     "No request rate limiting or IP throttling on authentication and registration endpoints.",
     "Automated password credential stuffing, dictionary attacks, and resource exhaustion.",
     "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N (5.3)", "Integrate SlowAPI / Redis rate limiter (5 requests/minute per client IP)."),

    ("SEC-06", "CWE-1333 / CWE-943: Unescaped Regex Search Query (ReDoS)", "Medium", "backend/main.py:183-186",
     "GET /products/search/{user_id}?q=...",
     "Raw query parameter q injected directly into MongoDB $regex without sanitization or escaping.",
     "Regex catastrophic backtracking or unexpected regex matching causing performance degradation.",
     "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:L (4.3)", "Escape search queries using re.escape(q) or configure MongoDB Atlas Full-Text index."),

    ("SEC-07", "CWE-256: Insecure Plaintext Password Comparison Fallback", "Low", "backend/database.py:41",
     "verify_password()",
     "Fallback logic allows plain text comparison (plain_password == hashed_password) for legacy rows.",
     "Weakens password storage enforcement and exposes potential timing side-channel.",
     "CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N (3.7)", "Enforce strict bcrypt hash formatting across all user records without fallback."),

    ("SEC-08", "CWE-693: Missing HTTP Security Headers", "Low", "backend/main.py",
     "Global Application Response Headers",
     "Responses lack X-Content-Type-Options, X-Frame-Options, Content-Security-Policy, and HSTS headers.",
     "Increases client exposure to clickjacking, MIME-sniffing, and MITM downgrade attacks.",
     "CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:N/I:L/A:N (3.1)", "Add security middleware to inject defensive HTTP headers on all API responses.")
]

ENDPOINT_DATA = [
    ("GET /", "GET", "No", "Public", "backend/main.py:104", "Health Check / Ping"),
    ("POST /signup", "POST", "No", "Anonymous", "backend/main.py:111", "User Account Registration"),
    ("POST /login", "POST", "No", "Anonymous", "backend/main.py:139", "User Authentication"),
    ("POST /logout", "POST", "No", "Any", "backend/main.py:155", "Logout & Session Invalidation"),
    ("GET /get_current_user", "GET", "No (Mocked)", "Any", "backend/main.py:160", "Session Status Verification"),
    ("GET /products/{user_id}", "GET", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:167", "List Store Products"),
    ("GET /products/search/{user_id}", "GET", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:178", "Search Store Inventory"),
    ("GET /products/alerts/{user_id}", "GET", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:193", "Low Stock & Expiry Alerts"),
    ("POST /products", "POST", "No (Missing Auth)", "Store Owner", "backend/main.py:211", "Create New Product"),
    ("PUT /products/{product_id}", "PUT", "No (Vulnerable BOLA)", "Product Owner", "backend/main.py:235", "Update Product Details"),
    ("PATCH /products/{product_id}/quantity", "PATCH", "No (Vulnerable BOLA)", "Product Owner", "backend/main.py:254", "Quick Stock Quantity Update"),
    ("DELETE /products/{product_id}", "DELETE", "No (Vulnerable BOLA)", "Product Owner", "backend/main.py:267", "Delete Product"),
    ("GET /sales/{user_id}", "GET", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:277", "List Sales Transactions"),
    ("POST /sales", "POST", "No (Missing Auth)", "Cashier / Owner", "backend/main.py:297", "Record POS Sale & Deduct Stock"),
    ("DELETE /sales/{sale_id}", "DELETE", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:351", "Delete Sale Record"),
    ("GET /dashboard/{user_id}", "GET", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:361", "Financial & Inventory Dashboard"),
    ("GET /analytics/{user_id}", "GET", "No (Vulnerable BOLA)", "Store Owner", "backend/main.py:362", "Sales Analytics & Trend Charts")
]

DEPENDENCY_DATA = [
    ("fastapi", ">=0.110.0", "Python/PyPI", "Safe", "None", "None", "Core Web Framework"),
    ("uvicorn[standard]", ">=0.28.0", "Python/PyPI", "Safe", "None", "None", "ASGI Web Server"),
    ("motor", ">=3.3.2", "Python/PyPI", "Safe", "None", "None", "Async MongoDB Driver"),
    ("pymongo[srv]", ">=4.6.2", "Python/PyPI", "Safe", "None", "None", "MongoDB Core Client"),
    ("pydantic", ">=2.6.4", "Python/PyPI", "Safe", "None", "None", "Data Schema Validation"),
    ("pydantic[email]", ">=2.6.4", "Python/PyPI", "Safe", "None", "None", "Email Address Validator"),
    ("python-dotenv", ">=1.0.1", "Python/PyPI", "Safe", "None", "None", "Environment Configuration"),
    ("python-multipart", ">=0.0.9", "Python/PyPI", "Low", "CVE-2024-24762", "Patched in >=0.0.8", "Form Data Parser"),
    ("bcrypt", ">=4.0.0", "Python/PyPI", "Safe", "None", "None", "Password Hashing Algorithm")
]

def create_styled_sheet(ws, title, headers, col_widths):
    ws.title = title
    ws.views.sheetView[0].showGridLines = True
    
    # Title Banner
    max_col = len(headers)
    ws.merge_cells(start_row=1, start_column=1, end_row=2, end_column=max_col)
    t = ws.cell(row=1, column=1, value=f"StockMate Pro — {title}")
    t.font = header_font
    t.fill = PatternFill(start_color=NAVY, end_color=NAVY, fill_type="solid")
    t.alignment = Alignment(horizontal="center", vertical="center")
    
    # Header row
    for col_idx, h in enumerate(headers, 1):
        c = ws.cell(row=4, column=col_idx, value=h)
        c.font = tbl_hdr_font
        c.fill = PatternFill(start_color=BLUE_HEADER, end_color=BLUE_HEADER, fill_type="solid")
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = thin_border
        
    ws.row_dimensions[4].height = 28
    
    for idx, width in enumerate(col_widths, 1):
        ws.column_dimensions[get_column_letter(idx)].width = width

def build_findings_workbook():
    wb = openpyxl.Workbook()
    
    # ── SHEET 1: Security Findings ──
    ws1 = wb.active
    f_headers = ["Finding ID", "Vulnerability Type", "Severity", "File / Line Reference", "Affected Target", "Description", "Exploitation Impact", "CVSS v3.1 Score", "Remediation Action"]
    f_widths = [14, 30, 14, 28, 28, 38, 38, 20, 42]
    create_styled_sheet(ws1, "Security Findings", f_headers, f_widths)
    
    for r_idx, f in enumerate(FINDINGS_DATA, 5):
        ws1.cell(row=r_idx, column=1, value=f[0]).font = bold_body
        ws1.cell(row=r_idx, column=2, value=f[1]).font = bold_body
        
        sev_cell = ws1.cell(row=r_idx, column=3, value=f[2])
        sev_cell.font = bold_body
        sev_cell.alignment = Alignment(horizontal="center", vertical="center")
        if f[2] == "Critical":
            sev_cell.fill = PatternFill(start_color=RED_BG, end_color=RED_BG, fill_type="solid")
        elif f[2] == "High":
            sev_cell.fill = PatternFill(start_color=ORANGE_BG, end_color=ORANGE_BG, fill_type="solid")
        elif f[2] == "Medium":
            sev_cell.fill = PatternFill(start_color=YELLOW_BG, end_color=YELLOW_BG, fill_type="solid")
        else:
            sev_cell.fill = PatternFill(start_color=BLUE_BG, end_color=BLUE_BG, fill_type="solid")
            
        for c in range(4, 10):
            cell = ws1.cell(row=r_idx, column=c, value=f[c-1])
            cell.font = body_font
            cell.alignment = Alignment(wrap_text=True, vertical="top")
            
        for c in range(1, 10):
            ws1.cell(row=r_idx, column=c).border = thin_border
        ws1.row_dimensions[r_idx].height = 42

    # ── SHEET 2: Endpoint Inventory ──
    ws2 = wb.create_sheet(title="Endpoint Inventory")
    e_headers = ["Endpoint", "HTTP Method", "Authentication Required", "Expected Roles", "Controller / File Path", "Function Description"]
    e_widths = [32, 14, 26, 18, 28, 32]
    create_styled_sheet(ws2, "Endpoint Inventory", e_headers, e_widths)
    
    for r_idx, e in enumerate(ENDPOINT_DATA, 5):
        ws2.cell(row=r_idx, column=1, value=e[0]).font = bold_body
        ws2.cell(row=r_idx, column=2, value=e[1]).font = bold_body
        ws2.cell(row=r_idx, column=2).alignment = Alignment(horizontal="center", vertical="center")
        
        auth_cell = ws2.cell(row=r_idx, column=3, value=e[2])
        auth_cell.font = body_font
        if "Vulnerable" in e[2] or "Missing" in e[2]:
            auth_cell.fill = PatternFill(start_color=RED_BG, end_color=RED_BG, fill_type="solid")
            
        ws2.cell(row=r_idx, column=4, value=e[3]).font = body_font
        ws2.cell(row=r_idx, column=5, value=e[4]).font = body_font
        ws2.cell(row=r_idx, column=6, value=e[5]).font = body_font
        
        for c in range(1, 7):
            ws2.cell(row=r_idx, column=c).border = thin_border
        ws2.row_dimensions[r_idx].height = 24

    # ── SHEET 3: Dependency Vulnerabilities ──
    ws3 = wb.create_sheet(title="Dependency Vulnerabilities")
    d_headers = ["Package Name", "Version Specified", "Ecosystem", "Severity Status", "Advisory / CVE", "Resolution", "Component Role"]
    d_widths = [24, 18, 16, 18, 20, 24, 28]
    create_styled_sheet(ws3, "Dependency Vulnerabilities", d_headers, d_widths)
    
    for r_idx, d in enumerate(DEPENDENCY_DATA, 5):
        ws3.cell(row=r_idx, column=1, value=d[0]).font = bold_body
        ws3.cell(row=r_idx, column=2, value=d[1]).font = body_font
        ws3.cell(row=r_idx, column=3, value=d[2]).font = body_font
        
        s_cell = ws3.cell(row=r_idx, column=4, value=d[3])
        s_cell.font = bold_body
        s_cell.alignment = Alignment(horizontal="center", vertical="center")
        if d[3] == "Safe":
            s_cell.fill = PatternFill(start_color=GREEN_BG, end_color=GREEN_BG, fill_type="solid")
        else:
            s_cell.fill = PatternFill(start_color=BLUE_BG, end_color=BLUE_BG, fill_type="solid")
            
        ws3.cell(row=r_idx, column=5, value=d[4]).font = body_font
        ws3.cell(row=r_idx, column=6, value=d[5]).font = body_font
        ws3.cell(row=r_idx, column=7, value=d[6]).font = body_font
        
        for c in range(1, 8):
            ws3.cell(row=r_idx, column=c).border = thin_border
        ws3.row_dimensions[r_idx].height = 24

    # ── SHEET 4: Risk Summary ──
    ws4 = wb.create_sheet(title="Risk Summary")
    r_headers = ["Risk Dimension", "Metric / Count", "Severity Weight", "Current Security Status", "Target SLA"]
    r_widths = [32, 20, 20, 30, 24]
    create_styled_sheet(ws4, "Risk Summary", r_headers, r_widths)
    
    risks = [
        ("Critical Severity Vulnerabilities", 2, "Weight: 40%", "Action Required (Immediate)", "< 24 Hours"),
        ("High Severity Vulnerabilities", 1, "Weight: 25%", "Action Required (High)", "< 3 Days"),
        ("Medium Severity Vulnerabilities", 3, "Weight: 20%", "Review & Schedule", "< 7 Days"),
        ("Low / Informational Findings", 2, "Weight: 15%", "Hardening Best Practice", "< 30 Days"),
        ("Total Discovered Vulnerabilities", 8, "Overall Score: 48/100", "Grade: D (Needs Remediation)", "Target: 95/100 (Grade A)")
    ]
    
    for r_idx, r in enumerate(risks, 5):
        ws4.cell(row=r_idx, column=1, value=r[0]).font = bold_body
        ws4.cell(row=r_idx, column=2, value=r[1]).font = bold_body
        ws4.cell(row=r_idx, column=3, value=r[2]).font = body_font
        ws4.cell(row=r_idx, column=4, value=r[3]).font = bold_body
        ws4.cell(row=r_idx, column=5, value=r[4]).font = body_font
        
        for c in range(1, 6):
            cell = ws4.cell(row=r_idx, column=c)
            cell.border = thin_border
            if c in [2, 3, 5]:
                cell.alignment = Alignment(horizontal="center", vertical="center")
        if r_idx == 9:
            for c in range(1, 6):
                ws4.cell(row=r_idx, column=c).fill = PatternFill(start_color="EDF2F7", end_color="EDF2F7", fill_type="solid")
        ws4.row_dimensions[r_idx].height = 26

    # Save findings.xlsx
    f_path = os.path.join(OUT_DIR, "findings.xlsx")
    wb.save(f_path)
    print(f"Successfully generated: {f_path}")

    # ── Separate endpoint-inventory.xlsx ──
    wb_ep = openpyxl.Workbook()
    ws_ep = wb_ep.active
    create_styled_sheet(ws_ep, "Endpoint Inventory", e_headers, e_widths)
    for r_idx, e in enumerate(ENDPOINT_DATA, 5):
        ws_ep.cell(row=r_idx, column=1, value=e[0]).font = bold_body
        ws_ep.cell(row=r_idx, column=2, value=e[1]).font = bold_body
        ws_ep.cell(row=r_idx, column=2).alignment = Alignment(horizontal="center", vertical="center")
        auth_cell = ws_ep.cell(row=r_idx, column=3, value=e[2])
        auth_cell.font = body_font
        if "Vulnerable" in e[2] or "Missing" in e[2]:
            auth_cell.fill = PatternFill(start_color=RED_BG, end_color=RED_BG, fill_type="solid")
        ws_ep.cell(row=r_idx, column=4, value=e[3]).font = body_font
        ws_ep.cell(row=r_idx, column=5, value=e[4]).font = body_font
        ws_ep.cell(row=r_idx, column=6, value=e[5]).font = body_font
        for c in range(1, 7):
            ws_ep.cell(row=r_idx, column=c).border = thin_border
        ws_ep.row_dimensions[r_idx].height = 24
        
    ep_path = os.path.join(OUT_DIR, "endpoint-inventory.xlsx")
    wb_ep.save(ep_path)
    print(f"Successfully generated: {ep_path}")

if __name__ == "__main__":
    build_findings_workbook()
