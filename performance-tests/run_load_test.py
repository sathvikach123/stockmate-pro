"""
=============================================================================
StockMate Pro - High-Concurrency Baseline & Load Testing Engine
Simulates 100 Concurrent Virtual Users continuously for 1 Minute (60 Seconds)
Measures: RPS (Requests/Sec), Min, Max, Avg, p50, p90, p95, p99 Response Times
=============================================================================
"""

import sys
import os
import time
import asyncio
import random
import json
import math
from datetime import datetime
from typing import List, Dict, Any

# Add backend directory to path so we can test against FastAPI app directly
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

import httpx

# Load testing configuration
CONFIG = {
    "CONCURRENT_USERS": 100,
    "DURATION_SECONDS": 60,
    "WARMUP_SECONDS": 3,
    "TARGET_URL": os.getenv("API_URL", "http://localhost:8000"),
    "ENDPOINTS": [
        {"name": "Health Check (GET /)", "method": "GET", "url": "/", "weight": 15},
        {"name": "User Login (POST /login)", "method": "POST", "url": "/login", "json": {"email": "satvikachvakula@gmail.com", "password": "Password123!"}, "weight": 20},
        {"name": "Product List (GET /products/1)", "method": "GET", "url": "/products/1", "weight": 25},
        {"name": "Product Search (GET /products/search/1)", "method": "GET", "url": "/products/search/1?q=salt", "weight": 15},
        {"name": "Dashboard KPI (GET /dashboard/1)", "method": "GET", "url": "/dashboard/1", "weight": 15},
        {"name": "Alerts (GET /products/alerts/1)", "method": "GET", "url": "/products/alerts/1", "weight": 5},
        {"name": "Sales Ledger (GET /sales/1)", "method": "GET", "url": "/sales/1", "weight": 5},
    ]
}

class LoadTestMetricsCollector:
    def __init__(self):
        self.latencies_ms: List[float] = []
        self.endpoint_stats: Dict[str, Dict[str, Any]] = {}
        self.status_codes: Dict[int, int] = {}
        self.second_buckets: Dict[int, int] = {}
        self.errors_count = 0
        self.total_requests = 0
        self.start_time = 0.0
        self.end_time = 0.0

        for ep in CONFIG["ENDPOINTS"]:
            self.endpoint_stats[ep["name"]] = {
                "count": 0,
                "latencies_ms": [],
                "errors": 0,
                "min_ms": float('inf'),
                "max_ms": 0.0,
                "total_ms": 0.0
            }

    def record_request(self, endpoint_name: str, status_code: int, latency_ms: float, timestamp: float):
        self.total_requests += 1
        self.latencies_ms.append(latency_ms)
        self.status_codes[status_code] = self.status_codes.get(status_code, 0) + 1

        sec = int(timestamp - self.start_time)
        self.second_buckets[sec] = self.second_buckets.get(sec, 0) + 1

        ep = self.endpoint_stats[endpoint_name]
        ep["count"] += 1
        ep["latencies_ms"].append(latency_ms)
        ep["total_ms"] += latency_ms
        if latency_ms < ep["min_ms"]:
            ep["min_ms"] = latency_ms
        if latency_ms > ep["max_ms"]:
            ep["max_ms"] = latency_ms

        if status_code >= 400 and status_code != 401: # 401 might be expected for invalid test users
            ep["errors"] += 1
            self.errors_count += 1

    def calculate_percentile(self, values: List[float], percentile: float) -> float:
        if not values:
            return 0.0
        sorted_vals = sorted(values)
        k = (len(sorted_vals) - 1) * (percentile / 100.0)
        f = math.floor(k)
        c = math.ceil(k)
        if f == c:
            return sorted_vals[int(k)]
        d0 = sorted_vals[int(f)] * (c - k)
        d1 = sorted_vals[int(c)] * (k - f)
        return d0 + d1

    def generate_summary(self) -> Dict[str, Any]:
        duration = max(1.0, self.end_time - self.start_time)
        rps = self.total_requests / duration
        avg_latency = sum(self.latencies_ms) / len(self.latencies_ms) if self.latencies_ms else 0.0
        min_latency = min(self.latencies_ms) if self.latencies_ms else 0.0
        max_latency = max(self.latencies_ms) if self.latencies_ms else 0.0

        p50 = self.calculate_percentile(self.latencies_ms, 50)
        p90 = self.calculate_percentile(self.latencies_ms, 90)
        p95 = self.calculate_percentile(self.latencies_ms, 95)
        p99 = self.calculate_percentile(self.latencies_ms, 99)

        ep_summary = {}
        for name, stats in self.endpoint_stats.items():
            count = stats["count"]
            if count > 0:
                ep_summary[name] = {
                    "requests": count,
                    "rps": round(count / duration, 2),
                    "min_ms": round(stats["min_ms"], 2),
                    "avg_ms": round(stats["total_ms"] / count, 2),
                    "p50_ms": round(self.calculate_percentile(stats["latencies_ms"], 50), 2),
                    "p95_ms": round(self.calculate_percentile(stats["latencies_ms"], 95), 2),
                    "p99_ms": round(self.calculate_percentile(stats["latencies_ms"], 99), 2),
                    "max_ms": round(stats["max_ms"], 2),
                    "errors": stats["errors"],
                    "error_rate_pct": round((stats["errors"] / count) * 100, 2)
                }

        return {
            "test_config": {
                "concurrent_users": CONFIG["CONCURRENT_USERS"],
                "duration_seconds": CONFIG["DURATION_SECONDS"],
                "target_url": CONFIG["TARGET_URL"],
                "timestamp": datetime.now().isoformat()
            },
            "overall_metrics": {
                "total_requests": self.total_requests,
                "duration_seconds": round(duration, 2),
                "rps": round(rps, 2),
                "success_count": self.total_requests - self.errors_count,
                "error_count": self.errors_count,
                "error_rate_pct": round((self.errors_count / max(1, self.total_requests)) * 100, 2),
                "latency_ms": {
                    "min": round(min_latency, 2),
                    "avg": round(avg_latency, 2),
                    "p50_median": round(p50, 2),
                    "p90": round(p90, 2),
                    "p95": round(p95, 2),
                    "p99": round(p99, 2),
                    "max": round(max_latency, 2)
                }
            },
            "status_code_distribution": self.status_codes,
            "throughput_per_second": [
                {"second": s, "requests": self.second_buckets.get(s, 0)}
                for s in range(int(duration))
            ],
            "endpoints": ep_summary
        }

async def virtual_user_worker(user_id: int, client: httpx.AsyncClient, collector: LoadTestMetricsCollector, stop_event: asyncio.Event):
    """Simulates a continuous active user navigating the system with thinking intervals."""
    # Stagger user start times to avoid artificial burst
    await asyncio.sleep(random.uniform(0.05, 0.5))

    weighted_endpoints = []
    for ep in CONFIG["ENDPOINTS"]:
        weighted_endpoints.extend([ep] * ep["weight"])

    while not stop_event.is_set():
        ep = random.choice(weighted_endpoints)
        t_start = time.perf_counter()
        status_code = 500

        try:
            if ep["method"] == "GET":
                resp = await client.get(ep["url"], timeout=10.0)
            elif ep["method"] == "POST":
                resp = await client.post(ep["url"], json=ep.get("json", {}), timeout=10.0)
            status_code = resp.status_code
        except httpx.HTTPError:
            status_code = 599 # Network/timeout error
        except Exception:
            status_code = 500

        t_end = time.perf_counter()
        latency_ms = (t_end - t_start) * 1000.0

        collector.record_request(ep["name"], status_code, latency_ms, time.time())

        # Micro think-time between clicks (10ms - 50ms) to simulate realistic concurrent browser activity
        await asyncio.sleep(random.uniform(0.01, 0.05))

async def execute_load_test():
    print("=" * 70)
    print("[*] StockMate Pro - Baseline & Concurrency Load Test Engine")
    print(f"[*] Virtual Concurrent Users: {CONFIG['CONCURRENT_USERS']}")
    print(f"[*] Duration:                {CONFIG['DURATION_SECONDS']} seconds (1 Minute)")
    print(f"[*] Target Architecture:      FastAPI + MongoDB Async Engine")
    print("=" * 70)

    # Initialize collector
    collector = LoadTestMetricsCollector()
    
    # Try connecting directly to app in-process or via HTTP
    try:
        from main import app
        transport = httpx.ASGITransport(app=app)
        async_client = httpx.AsyncClient(transport=transport, base_url="http://localhost:8000")
        print("[+] Direct High-Speed ASGI In-Memory Transport Initialized")
    except Exception as e:
        print(f"[!] Standard Async HTTP Transport Initialized ({e})")
        limits = httpx.Limits(max_connections=200, max_keepalive_connections=100)
        async_client = httpx.AsyncClient(base_url=CONFIG["TARGET_URL"], limits=limits)

    async with async_client as client:
        stop_event = asyncio.Event()
        collector.start_time = time.time()

        print(f"\n[00:00] Launching {CONFIG['CONCURRENT_USERS']} virtual user worker threads...")
        workers = [
            asyncio.create_task(virtual_user_worker(uid, client, collector, stop_event))
            for uid in range(CONFIG["CONCURRENT_USERS"])
        ]

        # Monitor loop for 60 seconds
        total_secs = CONFIG["DURATION_SECONDS"]
        for current_sec in range(1, total_secs + 1):
            await asyncio.sleep(1.0)
            cur_reqs = collector.total_requests
            cur_rps = cur_reqs / current_sec
            cur_avg = sum(collector.latencies_ms) / max(1, len(collector.latencies_ms)) if collector.latencies_ms else 0
            
            # Print live progress every 10 seconds
            if current_sec % 10 == 0 or current_sec == total_secs:
                print(f"[{str(current_sec).zfill(2)}s] Progress: {current_sec}/{total_secs}s | Total Requests: {cur_reqs:,} | Live RPS: {cur_rps:.1f} req/s | Avg Latency: {cur_avg:.1f}ms")

        # Stop workers
        collector.end_time = time.time()
        stop_event.set()
        await asyncio.gather(*workers, return_exceptions=True)

    # Compile Final Report
    results = collector.generate_summary()
    
    # Save results JSON
    out_dir = os.path.dirname(__file__)
    json_path = os.path.join(out_dir, "load_test_results.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    # Display Executive Summary in Terminal
    m = results["overall_metrics"]
    lat = m["latency_ms"]
    print("\n" + "=" * 70)
    print("BASELINE & LOAD TEST EXECUTION RESULTS (100 CONCURRENT USERS / 1 MIN)")
    print("=" * 70)
    print(f"Total Requests Executed:    {m['total_requests']:,} requests")
    print(f"Throughput (RPS):            {m['rps']} req/sec")
    print(f"Total Execution Duration:   {m['duration_seconds']} seconds")
    print(f"Success Rate:               {100 - m['error_rate_pct']:.2f}% ({m['success_count']:,} passed, {m['error_count']} errors)")
    print("-" * 70)
    print("RESPONSE TIME / LATENCY DISTRIBUTION:")
    print(f"   - Fastest (Min):            {lat['min']} ms")
    print(f"   - Average (Mean):           {lat['avg']} ms")
    print(f"   - 50th Percentile (Median): {lat['p50_median']} ms")
    print(f"   - 90th Percentile (p90):    {lat['p90']} ms")
    print(f"   - 95th Percentile (p95):    {lat['p95']} ms")
    print(f"   - 99th Percentile (p99):    {lat['p99']} ms")
    print(f"   - Slowest (Max):            {lat['max']} ms")
    print("-" * 70)
    print("ENDPOINT PERFORMANCE BREAKDOWN:")
    print(f"{'Endpoint':<35} | {'Requests':<8} | {'RPS':<8} | {'Avg (ms)':<9} | {'p95 (ms)':<9} | {'Max (ms)':<9}")
    print("-" * 88)
    for name, ep in results["endpoints"].items():
        print(f"{name:<35} | {ep['requests']:<8} | {ep['rps']:<8} | {ep['avg_ms']:<9} | {ep['p95_ms']:<9} | {ep['max_ms']:<9}")
    print("=" * 70)
    print(f"[+] Raw load metrics saved to: {json_path}")
    return results

if __name__ == "__main__":
    asyncio.run(execute_load_test())
