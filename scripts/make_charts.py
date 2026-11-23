"""Build the two README charts from results/ (run run_all.py first).

Design rules: one message per chart, stated in the title; one highlight colour
(blue) for the cities we recommend, grey for context; direct labels instead of
legends, axes and gridlines.
"""
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
RES, OUT = ROOT / "results", ROOT / "charts"
OUT.mkdir(exist_ok=True)

SURFACE, INK, INK2 = "#ffffff", "#1a1a1a", "#6b6a66"
HIGHLIGHT, CONTEXT, BENCH = "#2a78d6", "#d9d8d3", "#8f8e89"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11, "text.color": INK,
                     "figure.facecolor": SURFACE, "axes.facecolor": SURFACE})


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
    fig.text(0.02, 0.97, title, fontsize=15, fontweight="bold", va="top")
    fig.text(0.02, 0.895, subtitle, fontsize=10.5, color=INK2, va="top")


# Chart 1: five cities stay on top however the criteria are weighted
sens = pd.read_csv(RES / "sensitivity_summary.csv")
top10 = pd.read_csv(RES / "city_ranking.csv").head(10)[["city", "launch_rank"]]
r = top10.merge(sens[["city", "scenarios_in_top5"]], on="city", how="left").fillna(0)
r = r.sort_values(["scenarios_in_top5", "launch_rank"], ascending=[True, False]).reset_index(drop=True)
w1 = set(pd.read_csv(RES / "launch_waves.csv").query("launch_wave.str.startswith('Wave 1')", engine="python")["city"])
hi = r["city"].isin(w1)
fig, ax = plt.subplots(figsize=(9, 5.4))
ax.barh(r["city"].map(pretty), r["scenarios_in_top5"], height=0.62,
        color=[HIGHLIGHT if h else CONTEXT for h in hi])
for y, (n, h) in enumerate(zip(r["scenarios_in_top5"], hi)):
    ax.text(n + 0.07, y, f"{int(n)} of 5", va="center", fontsize=11,
            color=INK if h else INK2, fontweight="bold" if h else "normal")
for lbl, h in zip(ax.get_yticklabels(), hi):
    lbl.set_color(INK if h else INK2)
    lbl.set_fontweight("bold" if h else "normal")
ax.set_xlim(0, 5.6)
clean(ax)
titles(fig, "Five cities rank top 5 however the criteria are weighted",
       "Number of 5 weighting scenarios in which each city ranks in the top 5 (base case,\n"
       "demand first, growth first, experience first, equal weights). Top 10 cities shown.")
fig.subplots_adjust(left=0.2, right=0.97, top=0.78, bottom=0.03)
fig.savefig(OUT / "01_launch_ranking.png", dpi=200)
plt.close(fig)

# Chart 2: why they matter, customers there wait far longer
m = pd.read_csv(RES / "city_metrics.csv")
waves = pd.read_csv(RES / "launch_waves.csv")
w1 = waves.loc[waves["launch_wave"].str.startswith("Wave 1"), "city"].tolist()
sp = "sao paulo, SP"
d = m[m["city"].isin(w1 + [sp])].sort_values("avg_delivery_days").reset_index(drop=True)
is_sp = d["city"] == sp
fig, ax = plt.subplots(figsize=(9, 5.0))
ax.barh(d["city"].map(pretty), d["avg_delivery_days"], height=0.62,
        color=[BENCH if s else HIGHLIGHT for s in is_sp])
for y, (days, s) in enumerate(zip(d["avg_delivery_days"], is_sp)):
    ax.text(days + 0.3, y, f"{days:.1f} days", va="center", fontsize=11,
            color=INK2 if s else INK, fontweight="normal" if s else "bold")
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
fig.subplots_adjust(left=0.2, right=0.97, top=0.76, bottom=0.03)
fig.savefig(OUT / "02_delivery_gap.png", dpi=200)
plt.close(fig)
print("Charts saved to charts/")
