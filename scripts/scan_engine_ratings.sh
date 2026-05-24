#!/usr/bin/env bash
# Scan a representative sample of BLK vehicle files and compute engine ratings
# Engine Rating = ceil_to_5((tonnage * cruiseMP) - suspension_factor)

SAMPLE_FILES=(
  # Tracked examples
  "3085u/ONN/Demolisher II Heavy Tank (MML).blk"
  "3058Uu/Alacorn Heavy Tank Mk VII.blk"
  "3060u/Myrmidon Medium Tank.blk"
  "3075/Puma Assault Tank PAT-005b.blk"
  "Golden Century/Manticore Heavy Tank EC.blk"
  "3050U/Rhino Fire Support Tank.blk"
  "Hist LOT II/Weapon Carrier Tracked (AC20).blk"
  "3150/Devastator II Superheavy Tank .blk"
  "3075/DI Morgan Assault Tank.blk"
  "ProtoTypes/Vedette Medium Tank V7.blk"

  # Wheeled examples
  "3058Uu/Tokugawa Heavy Tank.blk"
  "3060u/Heavy Wheeled APC.blk"
  "3150/Bardiche Heavy Strike Tank C.blk"
  "HB HM/Hector Road Train Tractor.blk"
  "ProtoTypes/Sokar Urban Combat Unit.blk"

  # Hover examples
  "3085u/ONN/Savannah Master Hovercraft (Interdictor).blk"
  "3058Uu/Fulcrum Heavy Hovertank.blk"
  "3060u/Epona Pursuit Tank Prime.blk"
  "3075/JES I Tactical Missile Carrier.blk"
  "Golden Century/Zephyr Hovertank EC.blk"
  "ProtoTypes/Fulcrum Heavy Hover Tank Hybrid.blk"

  # VTOL examples
  "XTRs/Succession Wars/Kestrel VTOL Scout.blk"
  "3058Uu/Yellow Jacket Gunship.blk"
  "3060u/Donar Assault Helicopter.blk"
  "3075/Crow Scout Helicopter.blk"
  "HB HL/Apple-Churchill Surveillance VTOL.blk"
  "ProtoTypes/Garuda Heavy VTOL.blk"

  # WiGE examples
  "3075/Hiryo Armored Infantry Transport.blk"
  "3150/Fensalir Combat WiGE (3132 Upgrade).blk"
  "3150/Pandion Combat WiGE (3135 Upgrade).blk"
  "3150/Swallow Attack WiGE (Spotter).blk"

  # Naval examples
  "3075/Mauna Kea Command Vessel.blk"

  # Submarine examples
  "3085u/Supplemental/Moray Heavy Attack Submarine.blk"
  "XTRs/RetroTech/White Tip Submarine.blk"

  # Hydrofoil examples
  "ProtoTypes/Sea Skimmer Hydrofoil ELRM.blk"
)

DATADIR="/home/rie/Git/endofgreatness/data/units/vehicles"

get_suspension_factor() {
  local motion=$1
  local tonnage=$2
  case "$motion" in
    Tracked)  echo 0 ;;
    Wheeled)  echo 20 ;;
    Naval)    echo 30 ;;
    Submarine) echo 30 ;;
    VTOL)
      if   [ $tonnage -le 10 ]; then echo 95
      elif [ $tonnage -le 20 ]; then echo 140
      else echo 175
      fi ;;
    Hover)
      if   [ $tonnage -le 10 ]; then echo 40
      elif [ $tonnage -le 20 ]; then echo 85
      elif [ $tonnage -le 30 ]; then echo 130
      elif [ $tonnage -le 40 ]; then echo 175
      else echo 235
      fi ;;
    WiGE)
      if   [ $tonnage -le 15 ]; then echo 80
      elif [ $tonnage -le 30 ]; then echo 115
      elif [ $tonnage -le 45 ]; then echo 140
      else echo 165
      fi ;;
    Hydrofoil)
      if   [ $tonnage -le 10 ]; then echo 60
      elif [ $tonnage -le 20 ]; then echo 105
      elif [ $tonnage -le 30 ]; then echo 150
      elif [ $tonnage -le 40 ]; then echo 195
      elif [ $tonnage -le 50 ]; then echo 255
      elif [ $tonnage -le 60 ]; then echo 300
      elif [ $tonnage -le 70 ]; then echo 345
      elif [ $tonnage -le 80 ]; then echo 390
      elif [ $tonnage -le 90 ]; then echo 435
      else echo 480
      fi ;;
    *) echo 0 ;;
  esac
}

ceil_to_5() {
  local val=$1
  local r=$(( val % 5 ))
  [ $r -eq 0 ] && echo $val || echo $(( val + 5 - r ))
}

echo "=== Engine Rating Scan ==="
printf "%-75s %-12s %-8s %-8s %-8s\n" "File (relative)" "Motion" "Tonnage" "CruiseMP" "Engine"
echo "======================================================================================================================"

declare -A unusual

for relpath in "${SAMPLE_FILES[@]}"; do
  fp="$DATADIR/$relpath"
  [ ! -f "$fp" ] && { echo "MISSING: $relpath" >&2; continue; }

  motion=$(grep -A1 '<motion_type>' "$fp" | tail -1 | tr -d '\r' | xargs)
  tone=$(grep -A1 '<tonnage>' "$fp" | tail -1 | tr -d '\r' | xargs)
  cru=$(grep -A1 '<cruiseMP>' "$fp" | tail -1 | tr -d '\r' | xargs)

  ton_int=${tone%.*}
  [ -z "$ton_int" ] && ton_int=0

  sf=$(get_suspension_factor "$motion" "$ton_int")
  raw=$(( ton_int * cru - sf ))
  [ $raw -lt 0 ] && raw=0
  engine=$(ceil_to_5 $raw)

  flag=""
  if [ $(( engine % 10 )) -ne 0 ]; then
    flag=" <-- UNUSUAL"
    unusual["$engine"]="$engine: $relpath"
  fi

  printf "%-75s %-12s %-8d %-8d %-8d%s\n" "$relpath" "$motion" "$ton_int" "$cru" "$engine" "$flag"
done

echo ""
echo "=== RESULTS ==="
echo ""
if [ ${#unusual[@]} -eq 0 ]; then
  echo "No unusual (non-multiple-of-10) engine ratings found in this sample."
else
  echo "Unique engine ratings NOT multiples of 10:"
  for k in $(echo "${!unusual[@]}" | tr ' ' '\n' | sort -n); do
    echo "  $k"
  done
fi
