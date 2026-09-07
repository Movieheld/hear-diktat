#!/bin/zsh
# hear-diktat entfernen.
#
#   ./uninstall.sh              # Programme und Dienst, Modelle bleiben
#   ./uninstall.sh --all        # zusaetzlich die Modelle (rund 550 MB)

set -e

PREFIX="${PREFIX:-$HOME/.local}"
PAKET="$PREFIX/share/hear-diktat"
ALLES=0
[[ "${1:-}" == "--all" ]] && ALLES=1

melde() { print -- "\033[1m==>\033[0m $*"; }

melde "Laufende Aufnahme beenden"
pkill -f 'hear-indicat[o]r' 2>/dev/null || true
rm -rf "${TMPDIR:-/tmp}/hear-session"

melde "Kurzbefehl austragen"
/usr/bin/python3 - <<'PYEOF' || true
import plistlib, subprocess
KEY = "sh.heardiktat.service - Hear Diktat - runWorkflowAsService"
raw = subprocess.run(["defaults", "export", "pbs", "-"],
                     capture_output=True).stdout
if raw.strip():
    data = plistlib.loads(raw)
    if data.get("NSServicesStatus", {}).pop(KEY, None) is not None:
        subprocess.run(["defaults", "import", "pbs", "-"],
                       input=plistlib.dumps(data), check=True)
PYEOF

melde "Dienst entfernen"
rm -rf "$HOME/Library/Services/Hear Diktat.workflow"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

melde "Befehle entfernen"
for f in hear hear-start hear-stop hear-toggle; do
  [[ -L "$PREFIX/bin/$f" ]] && rm -f "$PREFIX/bin/$f"
done

if (( ALLES )); then
  melde "Paket samt Modellen entfernen"
  rm -rf "$PAKET"
else
  melde "Programme entfernen, Modelle bleiben liegen"
  rm -rf "$PAKET/bin"
  print "   Modelle noch da: $PAKET/models"
  print "   Mit --all wird auch das geloescht."
fi

print ""
melde "Fertig. whisper.cpp aus Homebrew wurde nicht angefasst."
