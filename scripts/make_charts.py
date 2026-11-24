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
SRC = "Olist Brazilian e-commerce public dataset (about 96,000 delivered orders, Jan 2017 to Aug 2018)"


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
r = r.sort_values(["scenarios_in_top5", "launch_rank"], ascending=[True, False]).reset_index(drop=True)
w1 = set(pd.read_csv(RES / "launch_waves.csv").query("launch_wave.str.startswith('Wave 1')", engine="python")["city"])
hi = r["city"].isin(w1)
fig, ax = plt.subplots(figsize=(8, 5.4), dpi=150)
ax.barh(r["city"].map(pretty), r["scenarios_in_top5"], height=0.62,
        color=[HIGHLIGHT if h else CONTEXT for h in hi])
for y, (n, h) in enumerate(zip(r["scenarios_in_top5"], hi)):
    ax.text(n + 0.07, y, f"{int(n)} of 5", va="center", fontsize=11,
            color=INK if h else INK2)
for lbl, h in zip(ax.get_yticklabels(), hi):
    lbl.set_color(INK if h else INK2)
ax.set_xlim(0, 5.6)
clean(ax)
titles(fig, "Five cities rank top 5 however the criteria are weighted",
       "Number of 5 weighting scenarios in which each city ranks in the top 5 (base case,\n"
       "demand first, growth first, experience first, equal weights). Top 10 cities shown.")
fig.subplots_adjust(left=0.2, right=0.97, top=0.78, bottom=0.09)
fig.savefig(OUT / "01_launch_ranking.png", dpi=150)
plt.close(fig)

# Chart 2: why they matter, customers there wait far longer
m = pd.read_csv(RES / "city_metrics.csv")
waves = pd.read_csv(RES / "launch_waves.csv")
w1 = waves.loc[waves["launch_wave"].str.startswith("Wave 1"), "city"].tolist()
sp = "sao paulo, SP"
d = m[m["city"].isin(w1 + [sp])].sort_values("avg_delivery_days").reset_index(drop=True)
is_sp = d["city"] == sp
fig, ax = plt.subplots(figsize=(8, 5.0), dpi=150)
ax.barh(d["city"].map(pretty), d["avg_delivery_days"], height=0.62,
        color=[BENCH if s else HIGHLIGHT for s in is_sp])
for y, (days, s) in enumerate(zip(d["avg_delivery_days"], is_sp)):
    ax.text(days + 0.3, y, f"{days:.1f} days", va="center", fontsize=11,
            color=INK2 if s else INK)
for lbl, s in zip(ax.get_yticklabels(), is_sp):
    lbl.set_color(INK2 if s else INK)
sp_days = d.loc[is_sp, "avg_delivery_days"].iloc[0]
ax.text(sp_days + 2.9, list(is_sp).index(True), "(benchmark)", va="center",
        fontsize=10, color=INK2)
ax.set_xlim(0, 25)
clean(ax)
titles(fig, "Customers in these five cities wait up to 2.5x longer than in São Paulo",
       "Average days from order to delivery, Jan 2017 to Aug 2018. These cities buy under 3%\n"
       "of items from in-state sellers, versus 77% in São Paulo.")
fig.subplots_adjust(left=0.2, right=0.97, top=0.76, bottom=0.09)
fig.savefig(OUT / "02_delivery_gap.png", dpi=150)
plt.close(fig)
# Chart 3: reviews collapse once delivery passes three weeks
rv = pd.read_csv(RES / "review_by_delivery_time.csv")
labels = [x.split(". ")[1] for x in rv["delivery_time"]]
vals = rv["bad_review_rate"] * 100
fig, ax = b.figure(8, 5)
cols = [HIGHLIGHT if l.startswith("22") else CONTEXT for l in labels]
bars = ax.bar(labels, vals, color=cols, width=0.6)
for bar, v, c in zip(bars, vals, cols):
    ax.text(bar.get_x() + bar.get_width() / 2, v + 0.8, f"{v:.0f}%", ha="center", fontsize=12,
            color=INK if c == HIGHLIGHT else INK2)
ax.set_yticks([])
ax.set_ylim(0, 46)
b.clean(ax, keep="x")
b.headline(fig, "Reviews collapse once delivery passes three weeks",
           "Share of orders rated 1 or 2 stars (out of 5), by days from order to delivery")
b.source(fig, SRC)
b.finish(fig, OUT / "03_reviews_by_delivery_time.png", top=0.83, bottom=0.12, left=0.04)
print("Charts saved to charts/")
