% =========================================================================
%  payload_fahrerprofile  –  Dateivertrag fuer den Fahrerprofil-Tab
% -------------------------------------------------------------------------
%  Zweck         : Arbeitet auf der separaten Profildatei (nicht am Signal-
%                  Store). Liefert die hinterlegten Fahrer, die Metrik-Liste
%                  (mit Gewichten), den Fingerprint des aktuell geladenen Runs
%                  sowie die Zuordnung (Rangliste mit Vertrauenswert + Schwelle,
%                  darunter Vorschlag "neuen Fahrer anlegen").
%
%  Besonderheit  : Nutzt KEINE Envelope/x-Achse und laeuft auch ohne geladenen
%                  Run (dann ist aktueller_run.vorhanden = false).
%
%  Robustheit    : Alle Profilfelder werden DEFENSIV gelesen (feld(...,default)).
%                  Fehlt in einem geladenen Profil z.B. n_runden oder kennzahlen,
%                  stuerzt der Tab NICHT mehr ab (das war die Ursache dafuer,
%                  dass nach dem Laden das Radar nicht mehr plottete).
%
%  Abhaengigkeiten: fahrer_fingerprint, fahrerprofile_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-18
% =========================================================================

function pl = payload_fahrerprofile(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_FAHRERPROFILE  pl = PAYLOAD_FAHRERPROFILE(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Stub).
%     2026-07-15  Gefuellt: Profile, Fingerprint, Zuordnung.
%     2026-07-18  Defensive Feldzugriffe (kein Absturz bei unvollstaendigen
%                 Profilen); Radar/Save wieder stabil.

    %% Konfiguration
    SCHWELLE   = 60;    % % Vertrauen, darunter -> "unbekannt / neu anlegen?"
    DIST_SKALA = 25;    % Abstands-Skala fuer die Vertrauens-Abbildung

    % Metriken (Reihenfolge = Vektor-Reihenfolge); Bremsaggr. hoeher gewichtet
    keys    = {'gas_aggr','vollgas','brems_aggr','trail','lenk','reibkreis','tc','konsistenz'};
    labels  = {'Gasaggr.','Vollgas','Bremsaggr.','Trail-Brake','Lenkaktiv.','Reibkreis','TC-Eingriff','Konsistenz'};
    gewicht = [1, 1, 2, 1, 1, 1, 1, 1];

    %% Meta + Metrik-Liste
    pl = struct();
    pl.meta = struct('tab', 'fahrerprofile');
    metriken = struct('key', {}, 'label', {}, 'gewicht', {});
    for i = 1:numel(keys)
        metriken(i) = struct('key', keys{i}, 'label', labels{i}, 'gewicht', gewicht(i));
    end
    pl.panels.metriken   = metriken;
    pl.panels.profildatei = char(feld(params, 'profil_datei', ''));

    %% Hinterlegte Profile laden -> Vektoren in keys-Reihenfolge (robust)
    profile = normiere_profile(fahrerprofile_laden(pl.panels.profildatei));
    pl.panels.profile = profile_zu_payload(profile, keys);

    %% Fingerprint des aktuell geladenen Runs
    if ~isempty(fieldnames(store))
        fp    = fahrer_fingerprint(store, x, params);
        werte = fp_zu_vektor(fp, keys);
        pl.panels.aktueller_run = struct('vorhanden', true, 'werte', werte);
        pl.panels.zuordnung     = zuordnen(werte, profile, keys, gewicht, SCHWELLE, DIST_SKALA);
    else
        pl.panels.aktueller_run = struct('vorhanden', false, 'werte', []);
        pl.panels.zuordnung     = struct('rangliste', leere_rangliste(), ...
                                         'schwelle', SCHWELLE, 'vorschlag_neu', false);
    end
end

% =========================================================================
%  Functions
% =========================================================================

function profile = normiere_profile(roh)
% Bringt geladene Profile auf ein sicheres Schema {name, n_runden, kennzahlen}.
%   Fehlende Felder werden mit Defaults gefuellt -> nie ein harter Feldzugriff.
    profile = struct('name', {}, 'n_runden', {}, 'kennzahlen', {});
    if isempty(roh) || ~isstruct(roh), return; end
    for i = 1:numel(roh)
        profile(i) = struct( ...
            'name',       char(feld(roh(i), 'name', sprintf('Fahrer %d', i))), ...
            'n_runden',   max(1, feld(roh(i), 'n_runden', 1)), ...
            'kennzahlen', feld(roh(i), 'kennzahlen', struct()) );
    end
end

function out = profile_zu_payload(profile, keys)
% Profile -> Array {name, n_runden, werte[keys]}.
    out = struct('name', {}, 'n_runden', {}, 'werte', {});
    for i = 1:numel(profile)
        out(i) = struct('name', profile(i).name, 'n_runden', profile(i).n_runden, ...
                        'werte', fp_zu_vektor(profile(i).kennzahlen, keys));
    end
end

function v = fp_zu_vektor(kennzahlen, keys)
% Kennzahl-Struct -> Zeilenvektor in fester keys-Reihenfolge (0 als Default).
    v = zeros(1, numel(keys));
    if ~isstruct(kennzahlen), return; end
    for i = 1:numel(keys)
        if isfield(kennzahlen, keys{i}) && isscalar(kennzahlen.(keys{i})) && isfinite(kennzahlen.(keys{i}))
            v(i) = kennzahlen.(keys{i});
        end
    end
end

function z = zuordnen(werte, profile, keys, gewicht, schwelle, skala)
% Gewichteter Abstand des Runs zu jedem Profil -> Vertrauen -> Rangliste.
    n = numel(profile);
    namen = cell(1, n); konf = zeros(1, n);
    for i = 1:n
        pv   = fp_zu_vektor(profile(i).kennzahlen, keys);
        dist = gew_abstand(werte, pv, gewicht);
        namen{i} = profile(i).name;
        konf(i)  = 100 * exp(-dist / skala);   % 0..100 %
    end
    [konf, ord] = sort(konf, 'descend');
    namen = namen(ord);

    rangliste = struct('name', {}, 'konfidenz', {});
    for i = 1:n
        rangliste(i) = struct('name', namen{i}, 'konfidenz', konf(i));
    end
    if isempty(rangliste), rangliste = leere_rangliste(); end

    vorschlag_neu = isempty(profile) || (konf(1) < schwelle);
    z = struct('rangliste', rangliste, 'schwelle', schwelle, 'vorschlag_neu', vorschlag_neu);
end

function d = gew_abstand(a, b, w)
% Gewichteter euklidischer Abstand (auf Gewichtssumme normiert).
    d = sqrt(sum(w .* (a - b).^2) / sum(w));
end

function r = leere_rangliste()
    r = struct('name', {}, 'konfidenz', {});
end

function v = feld(s, name, default)
% Feld aus Struct mit Default (auch bei leerem/keinem Struct sicher).
    if isstruct(s) && isscalar(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
