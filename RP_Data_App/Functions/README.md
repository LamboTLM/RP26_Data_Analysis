# Datenanalyse-Tool – MATLAB-Grundgerüst

Backend-Skelett der Analyse-App. Der JavaScript-Teil (je Tab eine eigene
HTML-Datei) wird separat gebaut und über den unten beschriebenen
Dateivertrag versorgt.

## Dateien

| Datei | Aufgabe |
|---|---|
| `DatenanalyseApp.m` | Haupt-App: Oberfläche, Ladefluss, Payload-Dispatch, JSON-Export |
| `load_mf4.m` | `.mf4` gruppenweise in den Signal-Store laden (mit Health-Status) |
| `signal_holen.m` | Gültiges Vorkommen eines Signals holen (Dopplungsregel) |
| `berechne_x_achse.m` | Gemeinsame x-Achse: Zeit oder Distanz (Geschwindigkeits-Integral) |
| `payload_envelope.m` | Gemeinsamer Teil jedes Dateivertrags (Signals auf x + Health) |
| `payload_<tab>.m` | Je Tab eine eigene Payload-Function (9 Stück) |
| `fahrzeug_parameter.m` | Zentraler Parametersatz (Platzhalterwerte, zu füllen) |

## Starten

```matlab
app = DatenanalyseApp;      % Oberfläche öffnet sich
% "Datei laden…" -> .mf4 wählen
```

## HTML/JS offline testen

Jeder Tab bekommt seinen Dateivertrag über die `Data`-Eigenschaft seiner
`uihtml`. Zum Bauen der HTML-Dateien ohne laufende App:

```matlab
app.export_payloads_json('C:\pfad\zu\testdaten');
% schreibt uebersicht.json, fahrdynamik.json, ... je Tab
```

## Dateivertrag (Envelope)

Jede Payload teilt denselben Rumpf, plus tab-spezifische `panels`:

```jsonc
{
  "meta":    { "tab": "fahrdynamik", "x_modus": "distanz", "x_einheit": "m" },
  "x":       [ /* x-Achse */ ],
  "signals": [ { "name": "...", "unit": "...", "status": "gueltig", "y": [ ... ] } ],
  "health":  [ { "name": "...", "status": "gueltig|statisch|nan|fehlt" } ],
  "panels":  { /* tab-spezifisch */ }
}
```

- `status` speist die Datenhealth-Ampel: grün = gültig, gelb = statisch/NaN,
  rot = fehlt. Fehlende Signale liefern `y: []` statt stiller NaN-Werte.
- `y` ist bereits auf die gemeinsame x-Achse resampled (Booleans mit
  `previous`, sonst linear).

## Stand

Real umgesetzt: Laden, Signal-Store, Health, x-Achse (Zeit/Distanz),
Envelope, Übersichts-Kennzahlen, Flag-Zählung, Signalkatalog.
Als `TODO` markiert und mit Struktur vorgesehen: die eigentlichen
Berechnungen je Tab (Schlupf, Schräglauf, Fz, R²-Bremsdiagnose,
Dämpfergeschwindigkeit, R_i/Verlustleistung, SOC, Fingerprints).
