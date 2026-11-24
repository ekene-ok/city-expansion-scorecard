"""Build the two README charts from results/ (run run_all.py first).

Design rules: one message per chart, stated in the title; one highlight colour
(blue) for the cities we recommend, grey for context; direct labels instead of
legends, axes and gridlines.
"""
from pathlib import Path
import pandas as pd
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
sys.path.insert(0, str(Path(__file__).parent))
import brand_style as b

ROOT = Path(__file__).resolve().parents[1]
RES, OUT = ROOT / "results", ROOT / "charts"
OUT.mkdir(exist_ok=True)

INK, INK2 = b.INK, b.MUTED
HIGHLIGHT, CONTEXT, BENCH = b.PROJECT["city-expansion-scorecard"], b.CONTEXT, b.CONTEXT
SRC = "Olist public e-commerce dataset, about 96,000 delivered orders, Jan 2017 to Aug 2018"


def pretty(city):
    name, state = city.rsplit(", ", 1)
    fixes = {"Goiania": "Goiânia", "Brasilia": "Brasília", "Belem": "Belém",
             "Niteroi": "Niterói", "Sao Paulo": "São Paulo"}
    name = name.title()
    return f"{fixes.get(name, name)}, {state}"


def clean(ax):
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_xticks([])
    ax.tick_params(axis="y", length=0, pad=8)


def titles(fig, title, subtitle):
    b.headline(fig, title, subtitle)
    b.source(fig, SRC)


# Chart 1: five cities stay on top however the criteria are weighted
sens = pd.read_csv(RES / "sensitivity_summary.csv")
top10 = pd.read_csv(RES / "city_ranking.csv").head(10)[["city", "launch_rank"]]
r = top10.merge(sens[["city", "scenarios_in_top5"]], on="city", how="left").fillna(0)
r = r.sort_values(["scenarios_in_top5", "launch_rank"], ascending=[False, True]).reset_index(drop=True)
w1 = set(pd.read_csv(RES / "launch_waves.csv").query("launch_wave.str.startswith('Wave 1')", engine="python")["city"])
fig, ax = b.chart(height=5.4, label_in=1.45)
b.hbar(ax, r.city.map(pretty).tolist(), r.scenarios_in_top5.tolist(), {i for i, c in enumerate(r.city) if c in w1},
       lambda v: f"{v:.0f} of 5", HIGHLIGHT, xmax=5)
b.titles(fig, "Five cities come out on top however the criteria are weighted",
         "Of 5 ways to weight demand, growth, delivery pain and order value: how many rank each city top 5")
b.credit(fig, SRC)
b.save(fig, OUT / "01_launch_ranking.png")

# Chart 2: customers in these cities wait far longer
m = pd.read_csv(RES / "city_metrics.csv")
waves = pd.read_csv(RES / "launch_waves.csv")
w1 = waves.loc[waves["launch_wave"].str.startswith("Wave 1"), "city"].tolist()
sp = "sao paulo, SP"
d = m[m["city"].isin(w1 + [sp])].sort_values("avg_delivery_days", ascending=False).reset_index(drop=True)
fig, ax = b.chart(height=4.4, label_in=1.45)
b.hbar(ax, d.city.map(pretty).tolist(), d.avg_delivery_days.tolist(), {i for i, c in enumerate(d.city) if c != sp},
       lambda v: f"{v:.1f}", HIGHLIGHT)
b.titles(fig, "Customers in these five cities wait up to 2.5x longer than in São Paulo",
         "Average days from order to delivery. Under 3% of their items come from in-state sellers")
b.credit(fig, SRC)
b.save(fig, OUT / "02_delivery_gap.png")

# Chart 3: reviews collapse once delivery passes three weeks
rv = pd.read_csv(RES / "review_by_delivery_time.csv")
labels = [x.split(". ")[1] for x in rv["delivery_time"]]
fig, ax = b.chart(height=4.2, label_in=0.0, xaxis="ticks", right_in=0.3)
b.vbar(ax, labels, (rv["bad_review_rate"] * 100).tolist(), {i for i, l in enumerate(labels) if l.startswith("22")},
       lambda v: f"{v:.0f}%", HIGHLIGHT)
b.titles(fig, "Reviews collapse once delivery passes three weeks",
         "Share of orders rated 1 or 2 stars out of 5, by days from order to delivery")
b.credit(fig, SRC)
b.save(fig, OUT / "03_reviews_by_delivery_time.png")
print("Charts saved to charts/")
