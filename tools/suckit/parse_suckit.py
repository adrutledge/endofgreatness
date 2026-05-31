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

    NAME_RE = re.compile(r'^(.+?)\s+\[(.+?)\s+\((\d+)\+\)(?:\s*/\s*(.+?)\s+\((\d+)\+\))?\]$')

    def resolve_name(raw_name, current_year=3025):
        """Parse date-marked system names and return the correct name for the given year.
        Also returns rename_timeline entries for name changes."""
        m = NAME_RE.match(raw_name)
        if not m:
            return raw_name, []
        old_name = m.group(1)
        new_name1 = m.group(2)
        year1 = int(m.group(3))
        events = []
        if m.group(4):
            new_name2 = m.group(4)
            year2 = int(m.group(5))
            chosen = new_name2 if year2 <= current_year else (new_name1 if year1 <= current_year else old_name)
            if year1 <= current_year:
                events.append({"date": "%d-01-01" % year1, "type": "system_rename", "data": {"system": old_name, "new_name": new_name1}})
                if year2 <= current_year:
                    events.append({"date": "%d-01-01" % year2, "type": "system_rename", "data": {"system": new_name1, "new_name": new_name2}})
        else:
            chosen = new_name1 if year1 <= current_year else old_name
            if year1 <= current_year:
                events.append({"date": "%d-01-01" % year1, "type": "system_rename", "data": {"system": old_name, "new_name": new_name1}})
        return chosen, events

    for row in reader:
        sid = int(row["systemID"])
        raw_name = row["systemName"].strip()
        name, rename_events = resolve_name(raw_name, 3025)
        timeline_events.extend(rename_events)
        try:
            x = float(row["x"])
            y = float(row["y"])
        except (ValueError, KeyError):
            print(f"  Skipping {raw_name}: bad coordinates ({row.get('x', '?')}, {row.get('y', '?')})")
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

        # Resolve (H) hidden suffix: strip it and mark system as hidden/excluded
        is_hidden = "(H)" in current_owner
        if is_hidden:
            current_owner = current_owner.replace("(H)", "").strip()

        entry = {
            "name": name,
            "x": x,
            "y": y,
            "owner_faction": current_owner,
            "faction_history": ownership,
        }
        if is_hidden:
            entry["hide"] = True
            entry["pathfinding_exclude"] = True
        systems[sid] = entry

        # Generate timeline events for ownership changes
        sorted_years = sorted(ownership.keys(), key=lambda y: (int(y.rstrip("abcd")), y))
        prev_faction = None
        for yr in sorted_years:
            fac = first_faction(ownership[yr])
            if fac != prev_faction and prev_faction is not None:
                timeline_events.append({
                    "date": "%s-01-01" % yr,
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
    entry = {
        "name": s["name"],
        "coordinates": {"x": s["x"], "y": s["y"]},
        "spectral_class": "G",
        "owner_faction": s["owner_faction"],
        "planets": planets,
    }
    if s.get("hide"):
        entry["hide"] = True
    if s.get("pathfinding_exclude"):
        entry["pathfinding_exclude"] = True
    starmap.append(entry)

starmap_path = os.path.join(OUT_DIR, "starmap.json")
with open(starmap_path, "w", encoding="utf-8") as f:
    json.dump(starmap, f, indent=2)
print(f"Wrote {len(starmap)} systems to {starmap_path}")

# ---- Write timeline_events.json ----
# Deduplicate: keep only events where the owner actually changed
seen_events = set()
deduped = []
for ev in timeline_events:
    if ev["type"] == "ownership_change":
        key = (ev["date"], ev["data"]["system"], ev["data"]["to_faction"])
    else:
        key = (ev["date"], ev["data"]["system"], ev["type"])
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
