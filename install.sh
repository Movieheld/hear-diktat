#!/bin/zsh
# hear-diktat — Installation auf macOS.
#
#   ./install.sh                 # nach ~/.local, Kurzbefehl F19
#   ./install.sh --key F13       # andere Taste
#   ./install.sh --no-key        # ohne Kurzbefehl, nur die Befehle
#   PREFIX=/opt/foo ./install.sh # anderer Zielort
#
# Was hier NICHT passiert: Berechtigungen vergeben. Mikrofon und
# Bedienungshilfen muss macOS erfragen, das kann kein Skript abnehmen.

set -e

QUELLE="${0:A:h}"
PREFIX="${PREFIX:-$HOME/.local}"
PAKET="$PREFIX/share/hear-diktat"
TASTE="F19"
MIT_TASTE=1

while (( $# )); do
  case "$1" in
    --key)    TASTE="$2"; shift 2 ;;
    --no-key) MIT_TASTE=0; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'; exit 0 ;;
    *) print -u2 "Unbekannte Option: $1"; exit 2 ;;
  esac
done

melde() { print -- "\033[1m==>\033[0m $*"; }
fehler() { print -u2 -- "\033[31mFehler:\033[0m $*"; exit 1 }

# ---------------------------------------------------------------- Voraussetzungen
[[ "$(uname -s)" == "Darwin" ]] || fehler "Nur fuer macOS."

command -v swiftc >/dev/null || fehler \
  "swiftc fehlt. Einmalig installieren mit: xcode-select --install"

melde "Ziel: $PAKET"
mkdir -p "$PAKET/bin" "$PAKET/models" "$PREFIX/bin"

# ---------------------------------------------------------------- micrec bauen
melde "micrec uebersetzen"
swiftc -O -o "$PAKET/bin/micrec" "$QUELLE/src/micrec.swift" \
  || fehler "micrec liess sich nicht uebersetzen."
codesign -f -s - "$PAKET/bin/micrec" >/dev/null 2>&1 || true

# ---------------------------------------------------------------- Skripte
melde "Skripte kopieren"
for f in hear hear-start hear-stop hear-toggle hear-indicator whisper; do
  cp "$QUELLE/bin/$f" "$PAKET/bin/$f"
  chmod +x "$PAKET/bin/$f"
done

# Nur die Befehle verlinken, die man selbst aufruft. `whisper` bleibt im Paket,
# damit es kein anderes whisper im PATH verdeckt — die Skripte finden es ueber
# ihren eigenen Ordner.
for f in hear hear-start hear-stop hear-toggle; do
  ln -sfn "$PAKET/bin/$f" "$PREFIX/bin/$f"
done

# ---------------------------------------------------------------- whisper.cpp
if command -v whisper-cli >/dev/null; then
  melde "whisper-cli gefunden: $(command -v whisper-cli)"
elif [[ -x "$PAKET/whisper.cpp/build/bin/whisper-cli" ]]; then
  melde "whisper-cli im Paket gefunden"
elif command -v brew >/dev/null; then
  melde "whisper.cpp installieren (brew install whisper-cpp)"
  brew install whisper-cpp || fehler "brew install whisper-cpp fehlgeschlagen."
else
  fehler "whisper-cli fehlt und Homebrew ist nicht da.
  Entweder Homebrew installieren und 'brew install whisper-cpp',
  oder whisper.cpp selbst bauen und WHISPER_HOME setzen."
fi

# ---------------------------------------------------------------- Modelle
lade() {  # $1 = Dateiname, $2 = URL, $3 = Beschreibung
  if [[ -f "$PAKET/models/$1" ]]; then
    melde "$3 liegt schon da"
    return 0
  fi
  melde "$3 laden ($1)"
  # -C - setzt einen Abbruch fort, statt von vorn zu beginnen.
  curl -fL --retry 5 --retry-delay 3 --retry-all-errors -C - \
       -o "$PAKET/models/$1" "$2" || fehler "Download fehlgeschlagen: $1"
}

lade ggml-large-v3-turbo-q5_0.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin" \
  "Sprachmodell, rund 550 MB"

lade ggml-silero-v5.1.2.bin \
  "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin" \
  "Stille-Erkennung, rund 1 MB"

# ---------------------------------------------------------------- Dienst + Taste
if (( MIT_TASTE )); then
  DIENST="$HOME/Library/Services/Hear Diktat.workflow"
  melde "Dienst anlegen: $DIENST"
  mkdir -p "$DIENST/Contents"

  cat > "$DIENST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Hear Diktat</string>
  <key>CFBundleIdentifier</key><string>sh.heardiktat.service</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSServices</key><array><dict>
    <key>NSMenuItem</key><dict><key>default</key><string>Hear Diktat</string></dict>
    <key>NSMessage</key><string>runWorkflowAsService</string>
    <key>NSSendTypes</key><array/>
    <key>NSReturnTypes</key><array/>
  </dict></array>
</dict></plist>
PLIST

  # NSRequiredContext mit leerer Programmkennung waere hier fatal: der Dienst
  # gaelte dann fuer kein einziges Programm und die Taste liefe ins Leere.

  cat > "$DIENST/Contents/document.wflow" <<WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>AMApplicationBuild</key><string>528</string>
  <key>AMApplicationVersion</key><string>2.10</string>
  <key>AMDocumentVersion</key><string>2</string>
  <key>actions</key><array><dict>
    <key>action</key><dict>
      <key>AMActionVersion</key><string>2.0.3</string>
      <key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
      <key>ActionName</key><string>Run Shell Script</string>
      <key>ActionParameters</key><dict>
        <key>COMMAND_STRING</key><string>exec "$PAKET/bin/hear-toggle"</string>
        <key>CheckedForUserDefaultShell</key><true/>
        <key>inputMethod</key><integer>0</integer>
        <key>shell</key><string>/bin/zsh</string>
        <key>source</key><string></string>
      </dict>
      <key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
      <key>CFBundleVersion</key><string>2.0.3</string>
      <key>Class Name</key><string>RunShellScriptAction</string>
      <key>UUID</key><string>7A1B2C3D-0001-4000-A000-00000000FEED</string>
      <key>isViewVisible</key><integer>1</integer>
    </dict>
    <key>isViewVisible</key><integer>1</integer>
  </dict></array>
  <key>connectors</key><dict/>
  <key>workflowMetaData</key><dict>
    <key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
    <key>serviceInputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
    <key>serviceApplicationBundleID</key><string></string>
    <key>serviceApplicationPath</key><string></string>
    <key>presentationMode</key><integer>0</integer>
    <key>processesInput</key><integer>0</integer>
  </dict>
</dict></plist>
WFLOW

  plutil -lint "$DIENST/Contents/Info.plist" >/dev/null || fehler "Info.plist ungueltig."
  plutil -lint "$DIENST/Contents/document.wflow" >/dev/null || fehler "document.wflow ungueltig."

  melde "Kurzbefehl $TASTE eintragen"
  /usr/bin/python3 - "$TASTE" <<'PYEOF'
import plistlib, subprocess, sys

# Funktionstasten werden als private Unicode-Zeichen hinterlegt: F13 = U+F710
# bis F19 = U+F716. Der Text "F19" funktioniert an dieser Stelle NICHT.
FKEYS = {"F%d" % (13 + i): chr(0xF710 + i) for i in range(7)}
want = sys.argv[1]
if want not in FKEYS:
    sys.exit("Nur F13 bis F19 moeglich, nicht: %s" % want)

KEY = "sh.heardiktat.service - Hear Diktat - runWorkflowAsService"
raw = subprocess.run(["defaults", "export", "pbs", "-"],
                     capture_output=True, check=True).stdout
data = plistlib.loads(raw) if raw.strip() else {}
data.setdefault("NSServicesStatus", {})[KEY] = {
    "key_equivalent": FKEYS[want],
    "enabled_context_menu": True,
    "enabled_services_menu": True,
    "presentation_modes": {"ContextMenu": True, "ServicesMenu": True},
}
subprocess.run(["defaults", "import", "pbs", "-"],
               input=plistlib.dumps(data), check=True)
print("   %s = U+%04X" % (want, ord(FKEYS[want])))
PYEOF

  /System/Library/CoreServices/pbs -flush 2>/dev/null || true
  /System/Library/CoreServices/pbs -update de >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------- Abschluss
print ""
melde "Fertig."
print ""

case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *) print "  ACHTUNG: $PREFIX/bin liegt nicht im PATH. In ~/.zshrc ergaenzen:"
     print "      export PATH=\"$PREFIX/bin:\$PATH\""
     print "" ;;
esac

print "  Noch von Hand, weil macOS danach fragen muss:"
print "    1. Beim ersten Aufruf Mikrofon erlauben."
print "    2. Fuer das automatische Einfuegen: Systemeinstellungen >"
print "       Datenschutz & Sicherheit > Bedienungshilfen freigeben."
if (( MIT_TASTE )); then
  print "    3. Reagiert $TASTE nicht, das Zielprogramm neu starten."
  print "       Dienste werden beim Programmstart eingelesen."
  print ""
  print "  Bedienung: $TASTE druecken, sprechen, $TASTE nochmal."
else
  print ""
  print "  Bedienung: 'hear' im Terminal, ENTER stoppt."
fi
print ""
