#!/bin/bash
#
# Test della logica dell'app, eseguibili senza Xcode.
#
# Il progetto non ha un target di test (aggiungerlo significa toccare il
# .pbxproj), quindi i file che contengono logica pura — formato di backup,
# calcolo del budget calorico, inserimento rapido — vengono compilati a parte
# insieme ai loro test e lanciati come normali eseguibili.
#
# I tipi di supporto (MealType, RoutePoint, HRPoint) sono estratti da
# Models.swift a ogni esecuzione: se cambiano nell'app, cambiano anche nei test,
# senza copie da tenere allineate a mano.
#
# Uso:  ./Scripts/test.sh

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

echo "Estrazione dei tipi geografici da Models.swift…"
python3 - "$ROOT" "$BUILD" <<'PY'
import re, sys, pathlib

root, build = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
src = (root / "FitnessApp/Models.swift").read_text()

def grab(pattern, name):
    m = re.search(pattern, src, re.S)
    if not m:
        sys.exit(f"Tipo '{name}' non trovato in Models.swift — aggiorna Scripts/test.sh")
    return m.group(0)

geo = [grab(r"struct %s: Codable \{.*?\n\}" % n, n) for n in ("RoutePoint", "HRPoint")]
(build / "GeoStubs.swift").write_text("import Foundation\n\n" + "\n\n".join(geo) + "\n")
PY

fail=0

run_suite() {
  local name="$1"; shift
  echo ""
  echo "══════ $name ══════"
  if swiftc -O -o "$BUILD/$name" "$@" 2>"$BUILD/$name.log"; then
    if "$BUILD/$name"; then :; else fail=1; fi
  else
    echo "Compilazione fallita:"
    head -30 "$BUILD/$name.log"
    fail=1
  fi
}

run_suite "formato-backup" \
  "$ROOT/FitnessApp/BackupModels.swift" \
  "$BUILD/GeoStubs.swift" \
  "$ROOT/Tests/BackupFormat/main.swift"

run_suite "logica-calorie" \
  "$ROOT/FitnessApp/CalorieLogic.swift" \
  "$ROOT/Tests/CalorieLogic/main.swift"

run_suite "logica-palestra" \
  "$ROOT/FitnessApp/CalorieLogic.swift" \
  "$ROOT/FitnessApp/GymLogic.swift" \
  "$ROOT/Tests/GymLogic/main.swift"

echo ""
if [ "$fail" -eq 0 ]; then
  echo "✓ Tutte le suite superate"
else
  echo "✗ Almeno una suite ha fallito"
  exit 1
fi
