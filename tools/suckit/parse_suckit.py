#!/usr/bin/env python3
"""Parse SUCKIT CSV exports into starmap.json and timeline_events.json."""
import csv, json, os, re

DATA_DIR = os.path.dirname(os.path.abspath(__file__))
FACTIONS_CSV = os.path.join(DATA_DIR, "Sarna Unified Cartography Kit (Official) - Factions CSV Export.csv")
SYSTEMS_CSV = os.path.join(DATA_DIR, "Sarna Unified Cartography Kit (Official) - Systems CSV Export.csv")
OUT_DIR = os.path.join(DATA_DIR, "..", "..", "data")

START_YEAR = 3025

# ---- Load factions ----
factions = {}
with open(FACTIONS_CSV, newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        fid = row["factionID"].strip()
        color = row["factionColor"].strip()
        name = row["factionName"].strip()
        factions[fid] = {"code": fid, "name": name, "color": color}

# ---- Load systems ----
with open(SYSTEMS_CSV, newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    year_cols = [c for c in reader.fieldnames if c not in ("systemID", "systemName", "x", "y")]

    systems = {}
    timeline_events = []
    system_id_counter = 0

    for row in reader:
        sid = int(row["systemID"])
        name = row["systemName"].strip()
        try:
            x = float(row["x"])
            y = float(row["y"])
        except (ValueError, KeyError):
            print(f"  Skipping {name}: bad coordinates ({row.get('x', '?')}, {row.get('y', '?')})")
            continue

        # Read ownership for each year (pipe-separated = contested/overlapping claims)
        ownership = {}
        for yc in year_cols:
            raw = row.get(yc, "").strip()
            if raw and raw != "U":
                ownership[yc] = raw

        # Determine 3025 owner (take first faction if pipe-separated)
        def first_faction(val):
            if not val or val == "U":
                return ""
            return val.split("|")[0].strip()

        current_owner = first_faction(ownership.get("3025", ""))
        # Fallback: find nearest earlier year
        if not current_owner:
            years_avail = sorted(ownership.keys())
            if years_avail:
                nearest = min(years_avail, key=lambda y: abs(int(y.rstrip("abcd")) - 3025))
                current_owner = first_faction(ownership.get(nearest, ""))

        systems[sid] = {
            "name": name,
            "x": x,
            "y": y,
            "owner_faction": current_owner,
            "faction_history": ownership,
        }

        # Generate timeline events for ownership changes
        sorted_years = sorted(ownership.keys(), key=lambda y: (int(y.rstrip("abcd")), y))
        prev_faction = None
        for yr in sorted_years:
            fac = first_faction(ownership[yr])
            if fac != prev_faction and prev_faction is not None:
                timeline_events.append({
                    "date": str(yr),
                    "type": "ownership_change",
                    "data": {
                        "system": name,
                        "from_faction": prev_faction,
                        "to_faction": fac,
                    }
                })
            prev_faction = fac

# ---- Write starmap.json (list format, matching existing loader) ----
starmap = []
for sid, s in systems.items():
    planets = [{
        "name": s["name"] + " III",
        "gravity": 1.0,
        "atmosphere": "breathable",
        "temperature": 22,
        "population": 1000000,
        "industry_type": "multi",
        "usilr_code": {"tech_sophistication": "C", "industrial_development": "C",
                       "raw_material_dependence": "C", "industrial_output": "C",
                       "agricultural_dependence": "C"},
        "hpg_class": "C",
        "relay_station": False,
        "land_percent": 40,
    }]
    starmap.append({
        "name": s["name"],
        "coordinates": {"x": s["x"], "y": s["y"]},
        "spectral_class": "G",
        "owner_faction": s["owner_faction"],
        "planets": planets,
    })

starmap_path = os.path.join(OUT_DIR, "starmap.json")
with open(starmap_path, "w", encoding="utf-8") as f:
    json.dump(starmap, f, indent=2)
print(f"Wrote {len(starmap)} systems to {starmap_path}")

# ---- Write timeline_events.json ----
# Deduplicate: keep only events where the owner actually changed
seen_events = set()
deduped = []
for ev in timeline_events:
    key = (ev["date"], ev["data"]["system"], ev["data"]["to_faction"])
    if key not in seen_events:
        seen_events.add(key)
        deduped.append(ev)

timeline_path = os.path.join(OUT_DIR, "timeline_events.json")
with open(timeline_path, "w", encoding="utf-8") as f:
    json.dump(deduped, f, indent=2)
print(f"Wrote {len(deduped)} timeline events to {timeline_path}")

# ---- Write faction_colors.json helper ----
colors = {f["code"]: f["color"] for f in factions.values()}

# ---- Summary ----
faction_set = set()
for s in systems.values():
    if s["owner_faction"]:
        faction_set.add(s["owner_faction"])
print(f"Systems: {len(systems)}")
print(f"Factions referenced: {len(faction_set)}")
print(f"Timeline events: {len(deduped)}")
print("Done.")
