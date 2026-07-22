# HANDOFF — Formula-Student Datenanalyse-Tool (RP26e)

Dieses Dokument fasst den kompletten Stand des Projekts zusammen, damit eine
neue Claude-Session verlustfrei weiterentwickeln kann. Alle Dateien liegen im
selben Ordner wie dieses Dokument.

---

## 1. Kontext

- **Team / Auto:** Dynamics e.V. (Formula Student, Regensburg), Auto **RP26e**, Car No. 62.
- **Umgebung:** MATLAB **2026a**, Windows. Sprache durchgehend **Deutsch**.
- **Zweck:** Professionelles Offline-Analysetool für geloggte **CAN-Signale** (.mf4 / MDF4).
  Zielgruppe: die Ingenieure, die das Auto entwickeln.
- **Datenlage:** Mehrere hundert CAN-Signale (AMS-Zellen, Unitek-Inverter, TQV, INS,
  Fahrwerk/Rocker, Bremse, DV/AS, eFuse/PDU …). Das Auto ist in Entwicklung →
  das Tool **muss robust gegen fehlende/lückenhafte Signale** sein.
- **User-Präferenzen:** MATLAB + **Dark Mode**; Code lesbar und modular
  (ein Payload pro Tab).

### MATLAB-Coding-Konventionen (bitte einhalten)
- `snake_case`, deutsche Kommentare.
- Datei-Header (Zweck / Einheiten-Annahmen / Abhängigkeiten / Autor / Datum).
- Function-Docstring mit **Changelog**.
- Rückgaben als **structs**; Einheiten als Kommentar; Platzhalter `<dein Name>`.
- Frontend: dunkles Farbschema, rote Akzentfarbe **#c7222a**.

---

## 2. Architektur

**Backend:** MATLAB App-Designer-App **`RP_data_tool_App`** (der User pflegt diese
Datei selbst; wir liefern die Payloads, HTMLs und Helferfunktionen).

- Eine `TabGroup2` mit **9 Tabs**, je Tab **eine `uihtml`**-Komponente.
- **Jeder Tab = eine eigene HTML-Datei** + **eine `payload_<tab>.m`-Function**.
- Dispatch: `payload_map` (containers.Map: tab_key → function_handle),
  `HTML_Handles` (numerisches Array der uihtml-Handles, gleiche Reihenfolge).
- Beim Laden: `alle_tabs_aktualisieren` ruft je Tab `pl = fh(store, x, params, runden)`
  und setzt `h.Data = pl`.
- **Wichtig (Bug gefixt):** `containers.Map` erlaubt kein verkettetes Indizieren →
  erst `h = map(name)`, dann `h.Data = pl`.

**Tab-Keys (Dateiname der HTML = Key + `.html`):**
`uebersicht, fahrdynamik, fahrer, fahrerprofile, hardware_software, akku, mechanik, parameter, scratchbook`

**Frontend:** reines HTML/JS pro Tab. Bibliotheken **lokal unter `./lib/`**:
- `uPlot.iife.min.js` + `uPlot.min.css` (**uPlot 1.6.32**) — Zeitreihen.
- `echarts.min.js` (**ECharts 5.5.1** — bewusst diese Version für uihtml-Kompatibilität) — XY/Scatter/Radar/Bar.

**Datenfluss (Variante 2):** Beim Öffnen eines Runs schickt das Backend die auf die
x-Achse resampelten Daten + Übersicht; das Frontend zoomt/dezimiert selbst
(kein Roundtrip pro Zoom). Ausnahme Scratchbook (siehe unten, request/compute).

**uihtml-Anbindung im Frontend:** jede HTML hat `function setup(hc){…}; window.setup=setup;`
mit `hc.addEventListener("DataChanged", …)` und `window.sendToMatlab=(n,d)=>hc.sendEventToMATLAB(n,d)`.

---

## 3. Dateivertrag / Envelope

`payload_envelope(store, tab, x, signal_namen)` liefert die Basis:

```
pl.meta    = struct('tab', <key>, 'x_modus', 'distanz'|'zeit', 'x_einheit', 'm'|'s')
pl.x       = <Vektor der x-Achse>              % Distanz [m] oder Zeit [s]
pl.signals = [ {name, unit, status, y} … ]     % y auf pl.x resampled
pl.health  = [ {name, status} … ]
pl.panels  = struct()                          % tab-spezifisch, s.u.
```

- `status ∈ {gueltig, statisch, nan, fehlt}` (speist die Datenhealth-Ampel:
  grün=gueltig, gelb=statisch/nan, rot=fehlt).
- Fehlendes Signal → `y = []` (kein NaN-Dummy). NaN wird im JSON zu `null` (= Lücke).
- Tabs ohne Run-Bezug (parameter, fahrerprofile, scratchbook) bauen `pl` teils
  **ohne Envelope** (kein x nötig) und laufen auch ohne geladenen Run.

### ⚠ KRITISCHE JSON-FALLE (unbedingt beachten)
`jsonencode` macht aus einem **1-Element-struct-Array ein JS-Objekt** (0→`[]`, 1→`{}`, 2+→`[]`).
Das hat stundenlang leere ECharts-Panels verursacht (`.map`/`.forEach` auf einem Objekt wirft).
**Zwei Gegenmaßnahmen, beide konsequent anwenden:**
1. **Backend:** variabel lange Listen als **CELL-Arrays** bauen (`c{end+1}=struct(...)`),
   dann `struct('feld', {c})`. Cell-of-structs → immer JSON-Array.
2. **Frontend:** überall `const asArray=(v)=>Array.isArray(v)?v:(v==null?[]:[v]);`
   und `asArray(...)` vor jedem `.map/.forEach/.find`.

### ⚠ ECharts-Falle
ECharts `init` auf einem 0×0-Container (Tab beim Datenempfang nicht aktiv) rendert
nichts und korrigiert sich nicht. **Fix in jeder ECharts-HTML:**
`if(window.ResizeObserver) new ResizeObserver(planeResize).observe(document.body);`
(zeichnet neu, sobald der Container Größe bekommt). Zusätzlich Guard
`if(typeof echarts==="undefined") …"ECharts fehlt in ./lib"`.

---

## 4. Datenmodell / Laden

**`load_mf4(dateiname, fortschritt_cb)` → `[store, log_start]`**
- Eager laden mit Fortschrittsbalken; `mdf`-Objekt + `read` pro Kanalgruppe.
- **2. Ausgabe `log_start`** = `m.InitialTimestamp` (für die Uhrzeit im HW/SW-Feed).
  → App muss `[app.store, t0] = load_mf4(pfad, cb); app.params.log_start = t0;` aufrufen.
- Namensdopplungen: gültiges Vorkommen nehmen, sonst erstes.
- Interne Zeit = **Sekunden als double**, gemeinsames t0.
- **Signal-Store-Eintrag:** `{name, t, value, unit, subsystem, is_bool, gruppe, status}`.

**`signal_holen(store, name)`** — kanonischer Signalzugriff (dedupe + status).
**`berechne_x_achse(store, modus, params)`** — liefert `x.werte` (Distanz/Zeit) und
`x.t_ref` (Zeit je Sample, **gleiche Länge** wie `x.werte`). Distanz via Speed-Integral.

---

## 5. Datei-Inventar (Stand: alle 9 Tabs gebaut)

### Kern / IO / Helfer
| Datei | Zweck | Status |
|---|---|---|
| `load_mf4.m` | .mf4 laden, `[store, log_start]` | fertig |
| `signal_holen.m` | Signalzugriff mit Dedupe/Status | fertig |
| `berechne_x_achse.m` | x-Achse (Distanz/Zeit) + t_ref | fertig |
| `payload_envelope.m` | Dateivertrag-Basis | fertig |
| `subsystem_aus_name.m` | Subsystem aus Signalname ableiten | fertig |
| `fahrzeug_parameter.m` | **Standard-Config** (Default-Parameter, Platzhalterwerte) | fertig, Werte prüfen |
| `setze_pfad.m` | verschachtelten Struct-Wert per Punkt-Pfad setzen | fertig |
| `fahrer_fingerprint.m` | Fahrstil-Kennzahlen aus einem Run (0..100) | fertig, NOM_-Konstanten kalibrieren |

### Payloads (eine je Tab)
`payload_uebersicht.m`, `payload_fahrdynamik.m`, `payload_fahrer.m`,
`payload_fahrerprofile.m`, `payload_hardware_software.m`, `payload_akku.m`,
`payload_mechanik.m`, `payload_parameter.m`, `payload_scratchbook.m` — **alle gefüllt**.

### HTMLs (eine je Tab)
`uebersicht.html`, `fahrdynamik.html`, `fahrer.html`, `fahrerprofile.html`,
`hardware_software.html`, `akku.html`, `mechanik.html`, `parameter.html`,
`scratchbook.html` — **alle gebaut**. Zusätzlich `echarts_test.html` + `echarts_test.m`
(Diagnose-Standalone; nicht Teil der App).

### Persistenz-Helfer (benannte Configs in .mat)
| Thema | Dateien | Standard-Pfad-Property |
|---|---|---|
| Fahrerprofile | `fahrerprofile_laden.m`, `fahrerprofile_speichern.m` | `params.profil_datei` |
| Signal-Configs (HW/SW-Explorer) | `signalconfigs_laden/speichern/loeschen.m` | `params.signalconfig_datei` |
| Parameter-Configs | `parameterconfigs_laden/speichern/loeschen.m` | `params.parameterconfig_datei` |
| Scratchbook-Layouts | `scratchconfigs_laden/speichern/loeschen.m` | `params.scratchconfig_datei` |

### Bibliotheken (`./lib/`)
`uPlot.iife.min.js`, `uPlot.min.css` (1.6.32), `echarts.min.js` (5.5.1).

---

## 6. Tab-Details

### Übersicht (`uebersicht`)
Landeseite. Payload: `spine` (speed_can auf x) zum Markieren; `health_matrix`
[{name,subsystem,status}]; `kennzahlen` (Dauer, Strecke, Runden, Fahrer, Max-Speed,
Max ax/ay, Min-Zellspannung, Max-Temp); `runden` (aus `runden`-Arg auf x umgerechnet);
`triage` {anzahl_fehler, sdc_ungeplant}.
HTML: **Runden-Markierung per Ziehen auf dem Speed-Spine** (uPlot `drag.setScale:false`,
`setSelect`-Hook → Formular mit Name → Event **`runde_markiert {x_start,x_ende,name}`**;
bestehende Runden als rote Bänder via `draw`-Hook + Liste mit Löschen → **`runde_loeschen {name}`**).
Kennzahlen-Kacheln, Datenhealth-Matrix (gruppiert), Triage.

### Fahrdynamik (`fahrdynamik`)
Payload rechnet: Längsschlupf (eigen aus `tqv_rot_spd`·r vs. eckkorrigierte Ref-Geschw.
+ geloggter `slip_compare_val_*` + Delta), Schwimmwinkel β (primär INS_vel_y/x,
Fallback Integration aus acc_y/ang_vel_z/vel_x), Achs-Schräglaufwinkel v/h,
Radlast Fz je Ecke **auf beiden Wegen** (Beschleunigung+Geometrie UND Rocker×Federrate/MR),
Reifen-Längskraft am Latsch [N], g-g, Eigenlenk.
HTML: uPlot-Telemetriestack (Speed, ax/ay, Gierrate, Lenkwinkel; synchroner Cursor),
ECharts g-g (nach Speed eingefärbt), Eigenlenk-Scatter, geloggter Schlupf, β.
Kein Hinterachslenkwinkel (=0). Reifenwinkel = steering_wheel_angle / Lenkübersetzung.

### Fahrer (`fahrer`)
Payload: `verlauf` (laufende Aktivität gas/brems/lenk aus geglätteter Zeit-Rate + reibkreis);
`tqv` (Anforderung `tqv_wantedTq` vs. Lieferung je Ecke `unitek_*_torque_motor_ist` +
Delta + `eingriff{tc_anteil, moment_spread}`); `tc` (slip_target/slip_ist/mu_factor/strength);
`fingerprint` (Run + Metriken); `vergleich` (hinterlegte Profile).
HTML: Eingaben-Stack, Aktivitäts-Stack, TQV (Anforderung+4 Ecken)+Delta+KPIs, TC-Charts,
ECharts-Radar (Run + wählbares Profil-Overlay), **„Aus Run anlegen"** → Event `fahrer_anlegen`.

### Fahrerprofile (`fahrerprofile`)
Arbeitet auf separater .mat. Fingerprint-Metriken (Gewicht Bremsaggr. ×2, trennschärfst):
`gas_aggr, vollgas, brems_aggr, trail, lenk, reibkreis, tc, konsistenz` (0..100).
Payload (ohne Envelope): `profile`, `metriken`+Gewichte, `aktueller_run`,
`zuordnung` (Rangliste + Vertrauen% + **Schwelle 60%** + `vorschlag_neu`).
HTML: Auswahl-Checkboxen (nur gewählte vergleichen), ECharts-Radar, gewichtete
Abstands-Matrix, Zuordnungs-Rangliste, „Fahrer anlegen".
Events: `fahrer_anlegen {name,kennzahlen}`, `profil_datei_waehlen`.

### Hardware/Software (`hardware_software`)
Umgebaut auf **gemeinsamen Cursor**. Payload: Fahrt-Kontext (speed/apps/pbrake/steering
via Envelope); `bools` = Katalog aller Bool-Signale als **Transitions** (start_wert +
Umschaltpunkte, kompakt für hunderte Flags); `vorauswahl` (SDC-Kette + getoggelte);
`fehler_feed` (Events {name, schwere, t_s, uhrzeit, distanz, x} aus `_e_`/`_w_`-Flags);
`sdc` (Öffnungen mit `ungeplant`-Flag, speed>3); `rails` (IMON-Ströme + eFuse-Trips);
`presets` (thematisch: SDC&Shutdown, Autonomes System, Inverter-Faults, AMS/Akku,
eFuse-Trips, Fahrer-Buttons, Antriebs-Strategie — nur vorhandene); `configs` (Signal-Configs).
HTML: Signal-Explorer (Suche, Subsystem-Gruppen + Gruppen-Häkchen, Mehrfachauswahl,
ausgewählte Bools als kleine **Stufenkurven** via `boolAufX`), Schnellaktionen
(Alle abwählen / Nur getoggelte / Sichtbare wählen), Filter „nur getoggelte zeigen",
Preset-Buttons, Config-Leiste, Fehler-Zeitlog (t_s + Uhrzeit + Distanz + Textfilter),
SDC-Panel (Hinweis: Öffnen am Logende fehlt oft, weil der Logger mit dem SDC stirbt),
Rails-Overlay + Trips.
Events: `signalconfig_speichern {name,signale}`, `signalconfig_loeschen {name}`.

### Akku (`akku`) — nur HV-Traktionsakku
**Zellgesundheits-Strategie:** Kritikalitäts-Score je Zelle aus (1) Innenwiderstand
(neg. Steigung V_Zelle vs I_pack), (2) Abweichung unter Last (unter Pack-Mittel),
(3) Minimalspannung. `score = 0.5·rn + 0.3·dn + 0.2·(1-vn)`; **kritisch** = oberstes
Quantil (0.90) ODER v_min < 3.2 V.
Payload: Pack-Übersicht (Envelope); `soc` {ivt (Ladungsintegral über t_ref), bms
(ams_capacity_fl)}; `zellen` {anzahl, spread(min/mean/max), heatmap(t dezimiert ~320
Spalten, index, mean, matrix als Cell-of-Rows), kritische[{index,score,r_innen,v_min,
abweichung,kritisch}] sortiert}; `spannungsabfall` {r_i_pack, verlustleistung=I²·R};
`temp` {spread, hotspot_index, max_temp}; `derating` (drive_deratingAccu*).
Zellsignale via `startsWith('ams_cell_voltage')` / `ams_cell_temp`.
HTML: Pack-Übersicht (V/I/P/SOC), **Zell-Heatmap** (Canvas, Toggle Abweichung/Spannung,
rot=unter Mittel, Klick wählt Zelle), Kritische-Zellen-Ranking (Balken), Zell-Inspektor
(uPlot Zelle vs Mittel + KPIs), Spannungsabfall (ECharts V-über-I-Scatter + R_i +
Verlustleistung), Temperatur-Spread + Hotspot, Derating.

### Mechanik (`mechanik`)
Payload: `bremslinearitaet` (Regression p_hinten=m·p_vorn+b nur während Bremsens, R²,
achsenabschnitt; Heuristik `auffaelliger_kreis` = welcher Kreis keinen Druck baut →
'vorn'/'hinten'/'unklar'); `bremsbalance` (front_anteil); `daempfergeschw` je Ecke
(echtes dt in nativer Zeitbasis → x-Modus-unabhängig, für Histogramm); `rphw`
(Roll/Pitch/Heave/Warp aus 4 Rockern, Rocker-Einheiten).
HTML: Bremslinearität (ECharts-Scatter + Regressionsgerade + R², Warnung <0.9),
Bremsbalance, Dämpfergeschwindigkeit je Ecke (Histogramm, Bump/Rebound-Farbe),
RPHW. Frontend rechnet einiges selbst, bevorzugt aber Backend-Werte sobald vorhanden.

### Fahrzeug-Parameter (`parameter`)
Payload (ohne Envelope): `gruppen` (Cell-Array von {label, felder:[{pfad,label,einheit,wert}]}
aus dem Parametersatz) + `configs` (Namen gespeicherter Parametersätze).
HTML: editierbare gruppierte Felder (onchange → `parameter_geaendert {pfad,wert}`);
Toolbar „Standard laden", Config-Dropdown, Laden/Speichern/Löschen.
Events: `parameter_geaendert`, `parameter_standard`, `parameter_config_laden/speichern/loeschen`.
`fahrzeug_parameter.m` bleibt die Quelle der Wahrheit; Configs sind Overrides.

### Scratchbook (`scratchbook`) — freier Arbeitsplatz mit Formel-Engine
**Request/Compute-Modell:** Frontend baut Config `{math:[{name,ausdruck}], plots:[{typ,
titel,kanaele,x_kanal,bins}]}` → Event **`scratch_render {config}`** → App legt sie in
`params.scratch_config` ab und ruft den Payload neu. Payload resampled referenzierte
Signale auf x (vars-Struct, Feldname=Signalname), wertet **Math-Kanäle per `eval`** aus
(elementweise `.* ./ .^`; Namen müssen `isvarname` sein; können aufeinander aufbauen),
baut plots (zeit=uPlot, xy=ECharts-Scatter, hist=ECharts-Bar). Liefert `katalog`,
`configs`, `geladene_config{stamp,config}`, `plots`, `math_status`.
HTML: Math-Builder (Name+Formel+Status ✓/⚠), Plot-Builder (Typ, Kanäle als Chips via
datalist, x-Kanal bei XY), „Aktualisieren"-Button, Config Laden/Speichern/Löschen.
Load repopuliert den Builder über den steigenden `scratch_stamp`.
**Sicherheit:** `eval` führt beliebigen MATLAB-Code aus den Formelfeldern aus — für ein
lokales Eigen-Tool ok, aber nicht an Dritte weitergeben.

---

## 7. NOCH ZU TUN in `RP_data_tool_App` (App-seitige Verdrahtung)

Der User pflegt die App-Datei selbst. Diese Punkte sind teils erledigt, teils offen —
bitte beim Weitermachen abklären. **Alle Event-Callbacks sind an der jeweiligen uihtml
als `HTMLEventReceivedFcn` zu setzen.**

**Startup (`startupFcn`), Property-Defaults:**
```matlab
app.params = fahrzeug_parameter();
app.params.profil_datei          = fullfile(app.html_dir, 'fahrerprofile.mat');
app.params.signalconfig_datei    = fullfile(app.html_dir, 'signalconfigs.mat');
app.params.parameterconfig_datei = fullfile(app.html_dir, 'parameterconfigs.mat');
app.params.scratchconfig_datei   = fullfile(app.html_dir, 'scratchconfigs.mat');
app.params.scratch_stamp = 0;
% Store-unabhängige Tabs beim Start einmal rendern:
%   parameter, fahrerprofile (und ggf. scratchbook-Katalog)
```

**LadenButton:** `[app.store, t0] = load_mf4(pfad, cb); app.params.log_start = t0;`

**Event-Callbacks (Kurzfassung — Details in den jeweiligen Tab-Nachrichten):**
- `Uebersicht_HTML`: `runde_markiert` (x→t via `interp1(app.x.werte, app.x.t_ref, [x_start x_ende])`
  → `app.runden(end+1)` mit Feldern name/t_start/t_ende/fahrer → `alle_tabs_aktualisieren`),
  `runde_loeschen` (aus `app.runden` entfernen → neu).
- `Fahrer_HTML`: `fahrer_anlegen` (→ `fahrerprofile_speichern` → Fahrer- + Fahrerprofil-Tab neu).
- `Fahrerprofile_HTML`: `fahrer_anlegen`, `profil_datei_waehlen`.
- `Hardware_Software_HTML`: `signalconfig_speichern`, `signalconfig_loeschen`.
- `FahrzeugParameter_HTML`: `parameter_geaendert`, `parameter_standard`,
  `parameter_config_laden/speichern/loeschen`. Helfer **`uebernehmen(ziel,quelle)`**
  bewahrt beim Config-Wechsel die Laufzeit-Felder
  (`profil_datei, parameterconfig_datei, signalconfig_datei, log_start`).
- `Scratchbook_HTML`: `scratch_render`, `scratch_config_laden` (Datei → `params.scratch_config`
  + `scratch_stamp++`), `scratch_config_speichern/loeschen`.
- `Akku_HTML`: **kein Event nötig** (sendet nichts).

**Bekannte Kleinigkeiten in der aktuellen App-Datei des Users:**
- `tab_aktualisieren` indexierte `HTML_Handles(name)` mit Namen statt Zahl (unbenutzt,
  würde aber crashen).
- `otherwise`-Zweig eines Callbacks referenziert undefinierte Variable `tab_name`.
- Tab-HTMLs haben feste `Position = [-4 -1 1278 621]` (Container ist also immer sichtbar
  groß — die ResizeObserver-Fixes schaden nicht, waren aber nicht die eigentliche
  ECharts-Ursache; die war die 1-Element-JSON-Falle).

---

## 8. Offene Features / nächste Schritte

1. **Lap-Selection / Restriktion (`DropDown_3`):** markierte Runde auswählen und die
   Analyse **tab-übergreifend** auf das Rundenfenster einschränken (x/Store begrenzen).
   Größter verbleibender Baustein — erst dann wirkt das Runden-Markieren überall.
2. **Kinematik-Lookups** (Radhub-Kinematik aus Rockern): Platzhalter vorsehen, später.
3. **Reifenmodell** (.tir vorhanden): optionaler Platzhalter zur Limit-Validierung.
4. **Rocker → echte Aufbaueinheiten** umschalten, sobald Parameter verlässlich (klar kennzeichnen).
5. **Einheiten-/Namens-Bestätigung gegen echte Datei** (siehe unten).
6. Feinschliff Fahrer-Vergleich über Runden (hängt an Lap-Selection).

---

## 9. Zu bestätigende Annahmen (gegen echte Logdatei prüfen)

- Einheiten: `tqv_rot_spd`/`yaw` in rad/s, `INS_acc_*` in m/s², `steering_wheel_angle`
  in Grad, `rocker_*` in mm, `speed_can → m/s` via `params.log.geschw_in_ms`,
  IVT-Strom in A (positiv = Entladung), Zellspannung in V, Temperatur in °C.
- Echte **SDC-Master-Signalnamen** (aktuell Kandidaten: `SDC_AS_closed_b_can`,
  `sdc_res_b_can`, `SDC_Latch_Ready_b_can`).
- Zellsignal-Namensschema (`ams_cell_voltageNNN`, `ams_cell_tempNN`) — Präfix-Match.
- `fahrer_fingerprint.m`: `NOM_*`-Normierungskonstanten kalibrieren.
- `fahrzeug_parameter.m`: Platzhalterwerte durch echte RP26e-Werte ersetzen.

---

## 10. Testen ohne MATLAB-Rendering

- JS-Syntax der HTMLs per `node --check` auf dem extrahierten `<script>`-Block prüfen.
- `echarts_test.m` + `echarts_test.html` sind ein Minimaltest für ECharts in `uihtml`
  (bestätigt in 2026a lauffähig).
- Payloads sind offline als JSON exportierbar (MATLAB liefert nur Daten, JS bleibt außen vor).

---

## 11. Arbeitsweise für die neue Session

- Neue Tab-HTML/Payload immer mit **asArray im Frontend** + **Cell-Arrays für Listen im
  Backend** bauen (JSON-Falle) und **ResizeObserver** falls ECharts genutzt wird.
- Gleiche Design-Tokens/Helfer wie in den bestehenden HTMLs (Dark, #c7222a, `uo/uplotOpts`,
  `getSig`, `istOk`, `healthChips`).
- Änderungen an der App-Datei nur als **Snippet** liefern (der User integriert selbst in
  App Designer) — nie die ganze `.m` neu schreiben.
- Nach jedem Tab: `node --check` + `present_files`.
