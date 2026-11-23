"""Build the two README charts from results/ (run run_all.py first)."""
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
RES, OUT = ROOT / "results", ROOT / "charts"
OUT.mkdir(exist_ok=True)

SURFACE, INK, INK2, MUTED, GRID, AXIS = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9", "#c3c2b7"
SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]  # validated, fixed order
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "text.color": INK,
                     "axes.edgecolor": AXIS, "axes.labelcolor": INK2,
                     "xtick.color": MUTED, "ytick.color": INK2,
                     "figure.facecolor": SURFACE, "axes.facecolor": SURFACE})

def pretty(city):
    name, state = city.rsplit(", ", 1)
    return f"{name.title()}, {state}"

# Chart 1: what drives each top-10 city's launch score (weighted pillar contributions)
rank = pd.read_csv(RES / "city_ranking.csv").head(10).iloc[::-1]
pillars = [("s_demand", 25, "Demand scale"), ("s_growth", 20, "Demand growth"),
           ("s_supply_gap", 25, "Regional supply gap"), ("s_delivery_pain", 20, "Delivery pain"),
           ("s_value", 10, "Order value")]
fig, ax = plt.subplots(figsize=(9, 5.2))
left = pd.Series(0.0, index=rank.index)
for (col, w, label), color in zip(pillars, SERIES):
    vals = rank[col] * w
    ax.barh(rank["city"].map(pretty), vals, left=left, color=color, height=0.62,
            edgecolor=SURFACE, linewidth=2, label=f"{label} (max {w})")
    left += vals
for y, (score, total) in enumerate(zip(rank["launch_score"], left)):
    ax.text(total + 0.8, y, f"{score:.1f}", va="center", color=INK, fontsize=9.5)
ax.set_xlim(0, 100)
ax.set_xlabel("Launch score (0 to 100), split by weighted pillar contribution")
ax.grid(axis="x", color=GRID, linewidth=0.8); ax.set_axisbelow(True)
for s in ["top", "right", "left"]: ax.spines[s].set_visible(False)
ax.tick_params(axis="y", length=0)
ax.legend(ncol=3, loc="upper center", bbox_to_anchor=(0.42, -0.13), frameon=False, fontsize=9)
fig.suptitle("Top 10 launch candidates: what drives each score", x=0.02, ha="left",
             fontsize=13, fontweight="bold", y=0.99)
fig.tight_layout()
fig.savefig(OUT / "01_top10_score_drivers.png", dpi=200, bbox_inches="tight")
plt.close(fig)

# Chart 2: cities without regional supply wait longer for deliveries
m = pd.read_csv(RES / "city_metrics.csv")
waves = pd.read_csv(RES / "launch_waves.csv")
w1 = set(waves.loc[waves["launch_wave"].str.startswith("Wave 1"), "city"])
m["x"] = m["same_state_seller_share"] * 100
fig, ax = plt.subplots(figsize=(9, 5.2))
other, top = m[~m["city"].isin(w1)], m[m["city"].isin(w1)]
size = lambda d: 20 + d["delivered_orders"] ** 0.5 * 2.2
ax.scatter(other["x"], other["avg_delivery_days"], s=size(other), color=AXIS,
           edgecolor=SURFACE, linewidth=1.5, label="Other eligible cities", zorder=2)
ax.scatter(top["x"], top["avg_delivery_days"], s=size(top), color=SERIES[0],
           edgecolor=SURFACE, linewidth=2, label="Wave 1 launch cities", zorder=3)
for _, r in top.iterrows():
    ax.annotate(pretty(r["city"]), (r["x"], r["avg_delivery_days"]), xytext=(8, 2),
                textcoords="offset points", fontsize=9, color=INK)
ref = m[m["city"] == "sao paulo, SP"].iloc[0]
ax.annotate("Sao Paulo, SP (largest market)", (ref["x"], ref["avg_delivery_days"]), xytext=(-60, 45),
            textcoords="offset points", ha="right", fontsize=9, color=INK2,
            arrowprops=dict(arrowstyle="-", color=MUTED, linewidth=0.8))
ax.set_xlabel("Items bought from sellers in the same state (%)")
ax.set_ylabel("Average delivery time (days)")
ax.grid(color=GRID, linewidth=0.8); ax.set_axisbelow(True)
for s in ["top", "right"]: ax.spines[s].set_visible(False)
leg = ax.legend(frameon=False, loc="upper right", fontsize=9)
for h in leg.legend_handles: h.set_sizes([60])
fig.suptitle("Cities without nearby sellers wait longer for their orders", x=0.02, ha="left",
             fontsize=13, fontweight="bold")
ax.set_title("68 cities with 200+ delivered orders, Jan 2017 to Aug 2018. Dot size = order volume.",
             loc="left", fontsize=9, color=INK2)
fig.tight_layout()
fig.savefig(OUT / "02_supply_vs_delivery.png", dpi=200, bbox_inches="tight")
plt.close(fig)
print("Charts saved to charts/")
