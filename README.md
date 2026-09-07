# hear-diktat

Diktieren auf dem Mac, mit Whisper statt Apples Spracherkennung. Eine Taste
drücken, sprechen, nochmal drücken — der Text steht da, wo der Cursor ist.

Alles läuft auf dem Rechner. Keine Anmeldung, kein Konto, keine Cloud, nichts
verlässt das Gerät.

## Warum nicht einfach Apples Diktat

Apples Diktat ist bequemer: der Text erscheint schon beim Sprechen. Bei
Fachbegriffen, Eigennamen und Ortsnamen liegt es aber öfter daneben.
`hear-diktat` nutzt `large-v3-turbo`, dasselbe Modell, mit dem auch
professionelle Transkriptionen gemacht werden.

Ein gemessenes Beispiel aus der Praxis, gesprochen über Lautsprecher:

```
Gesagt:    Dies ist ein Test der Spracherkennung.
           Movieheld produziert Imagefilme in Chemnitz.
Erkannt:   Dies ist ein Test der Spracherkennung.
           Movieheld produziert Imagefilme in Chemnitz.
```

Wort für Wort, Firmenname und Stadt eingeschlossen.

## Installation

Vorausgesetzt werden macOS, die Xcode-Befehlszeilenwerkzeuge
(`xcode-select --install`) und Homebrew.

```bash
git clone https://github.com/<dein-name>/hear-diktat.git
cd hear-diktat
./install.sh
```

Das Skript übersetzt `micrec`, legt die Befehle nach `~/.local/bin`, holt
`whisper-cpp` über Homebrew, lädt das Sprachmodell (rund 550 MB) und richtet
den Kurzbefehl **F19** ein.

Andere Taste, oder gar keine:

```bash
./install.sh --key F13     # F13 bis F19 möglich
./install.sh --no-key      # nur die Befehle, kein Kurzbefehl
```

**Zwei Schritte bleiben von Hand**, weil macOS sie selbst erfragen muss:
beim ersten Aufruf das Mikrofon erlauben, und für das automatische Einfügen
unter *Systemeinstellungen › Datenschutz & Sicherheit › Bedienungshilfen*
freigeben. Ohne das Zweite landet der Text trotzdem in der Zwischenablage.

## Bedienung

F19 drücken. Oben erscheint ein Feld mit laufender Zeit, dazu ein Klang.
Sprechen. F19 nochmal drücken. Der Text wird eingefügt und liegt zusätzlich
in der Zwischenablage.

Vier Klänge unterscheiden die Fälle: Tink beim Start, Pop beim Stoppen,
Glass wenn der Text da ist, Basso wenn nichts erkannt wurde.

Ohne Kurzbefehl geht es auch im Terminal:

```bash
hear              # aufnehmen, ENTER stoppt, Text in die Zwischenablage
hear -l en        # andere Sprache
hear -k           # WAV behalten
hear-toggle       # dasselbe wie F19
hear-toggle -n    # nicht einfügen, nur kopieren
```

## Was drin steckt

| Datei | Aufgabe |
|---|---|
| `src/micrec.swift` | Mikrofonaufnahme, 16 kHz mono, genau was Whisper will |
| `bin/hear` | aufnehmen, ENTER stoppt, transkribieren |
| `bin/hear-start`, `bin/hear-stop` | dasselbe getrennt, für Tastenkürzel |
| `bin/hear-toggle` | die Umschaltlogik hinter F19 |
| `bin/hear-indicator` | die Anzeige während der Aufnahme |
| `bin/whisper` | Wrapper um `whisper-cli`, auch einzeln nutzbar |

Zusammen rund 15 KB eigener Code. Die Arbeit macht
[whisper.cpp](https://github.com/ggml-org/whisper.cpp), das nicht mitgeliefert,
sondern bei der Installation über Homebrew geholt wird.

## Vier Fallstricke, die hier schon gelöst sind

Wer so etwas selbst baut, läuft der Reihe nach hier hinein:

**`pbcopy` verstümmelt Umlaute.** Es richtet sich nach der Zeichensatz-Variable
der Umgebung, und ein macOS-Dienst startet ohne. Aus „Grüße über Ärger" wird
dann „Gr√º√üe √ºber √Ñrger". Im Terminal fällt es nie auf.

**`whisper-cli` gibt bei unlesbarer Audiodatei 0 zurück** und schreibt
`error: failed to read audio file` nur nach stderr. Wer den Rückgabewert prüft,
hält einen Fehlschlag für Erfolg.

**`overrideredirect(True)` macht ein Tk-Fenster unsichtbar.** Apples
System-Python bringt Tk 8.5 mit; damit erscheint auf aktuellem macOS gar
nichts. Die Anzeige ist deshalb ein normales Fenster, dessen Titelzeile die
Information trägt — die malt macOS selbst.

**Funktionstasten sind private Unicode-Zeichen.** F13 bis F19 liegen ab
`U+F710`. Der Text `"F19"` funktioniert als Tastenzuordnung nicht.

Dazu eine Falle in der Dienst-Definition: ein `NSRequiredContext` mit leerer
Programmkennung lässt den Dienst für kein einziges Programm gelten. Die Taste
tut dann gar nichts, ohne jede Fehlermeldung.

## Grenzen

macOS only, getestet auf Apple Silicon. Keine Sprechertrennung — bei mehreren
Stimmen kommt ein durchgehender Text heraus. Die erste Transkription nach dem
Start dauert länger, weil das Modell geladen wird.

Meldungen und Dokumentation sind auf Deutsch. Die Erkennung selbst kann jede
Sprache, die Whisper kann: `hear -l en`, `-l fr`, `-l pl` und so weiter.

## Entfernen

```bash
./uninstall.sh          # Programme und Kurzbefehl, Modelle bleiben
./uninstall.sh --all    # auch die Modelle
```

`whisper-cpp` aus Homebrew wird dabei nicht angefasst.

## Lizenz

MIT, siehe [LICENSE](LICENSE). whisper.cpp und die Whisper-Modelle stehen
ebenfalls unter MIT, gehören aber nicht zu diesem Projekt.
