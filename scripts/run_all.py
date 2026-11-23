"""Run the SQL pipeline in DuckDB and export results to results/.

Usage (from the repo root):
    bash scripts/get_data.sh
    python scripts/run_all.py
    python scripts/make_charts.py
"""
from pathlib import Path
import duckdb

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
OUT = ROOT / "results"
OUT.mkdir(exist_ok=True)

EXPORTS = [
    "dq_status_mix", "dq_monthly_volume", "dq_missing_delivery_dates",
    "city_metrics", "city_ranking", "sensitivity_summary", "launch_waves",
]

con = duckdb.connect(str(ROOT / "olist.duckdb"))
con.execute(f"SET file_search_path = '{ROOT}'")
for f in sorted(SQL_DIR.glob("*.sql")):
    print(f"Running {f.name}")
    con.execute(f.read_text())

for view in EXPORTS:
    con.sql(f"SELECT * FROM {view}").write_csv(str(OUT / f"{view}.csv"))
    print(f"Exported results/{view}.csv")

print("\nTop 10 cities by launch score:")
print(con.sql("SELECT launch_rank, city, launch_score, delivered_orders, yoy_growth, "
              "local_seller_share, avg_delivery_days, late_rate FROM city_ranking LIMIT 10"))
con.close()
