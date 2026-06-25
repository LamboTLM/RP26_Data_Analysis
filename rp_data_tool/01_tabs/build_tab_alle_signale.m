function [wert_label, signal_info] = build_tab_alle_signale(tab, signale, cfg)
%BUILD_TAB_ALLE_SIGNALE Erstellt den Tab mit allen Signalwerten.
%
%   Eingabe:
%       tab     — ui.Tab Objekt
%       signale — Struct mit extrahierten Signalen
%       cfg     — Config-Struct
%
%   Ausgabe:
%       wert_label  — Array von uilabel-Handles (fuer Live-Updates)
%       signal_info — Cell-Array mit {feldname, ok_feldname} pro Zeile
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24
%   Changelog:
%       2026-06-24  Schleifenabbruch korrigiert, vertcat-Fix

    C = farben();

    TAB_W = 1590;
    TAB_H = 855;
    N_COLS = cfg.layout.spalten_signale;
    RH = cfg.layout.zeilen_hoehe_signale;
    SH = cfg.layout.sektions_hoehe_signale;
    FS_SIG = cfg.layout.schrift.signal;
    FS_HDR = cfg.layout.schrift.header;

    col_w = floor(TAB_W / N_COLS);
    val_w = 70;
    nm_w = col_w - val_w - 18;

    eintraege = build_flat_signal_list(cfg);
    n_eintraege = numel(eintraege);
    pro_spalte = ceil(n_eintraege / N_COLS);

    % Zeitstempel-Label oben
    uilabel(tab, ...
        'Position', [6, TAB_H - 16, 500, 14], ...
        'Text', '● letzter Wert  —  Snapshot-Zeit ueber Topbar setzen', ...
        'FontSize', 7.5, ...
        'FontColor', [0.45, 0.45, 0.45], ...
        'BackgroundColor', 'none');

    wert_label = gobjects(0);
    signal_info = {};

    for ci = 1:N_COLS
        x0 = 2 + (ci - 1) * col_w;
        y_top = TAB_H - 20;

        idx_from = (ci - 1) * pro_spalte + 1;
        idx_to = min(ci * pro_spalte, n_eintraege);

        for ei = idx_from:idx_to
            e = eintraege{ei};

            % Sektions-Header
            if isstruct(e)
                y_top = y_top - SH;
                if y_top < 2
                    break;
                end
                uilabel(tab, ...
                    'Position', [x0, y_top, col_w - 3, SH - 1], ...
                    'Text', ['  ', upper(e.header)], ...
                    'FontSize', FS_HDR, ...
                    'FontWeight', 'bold', ...
                    'FontColor', C.orange, ...
                    'BackgroundColor', [0.11, 0.09, 0.06], ...
                    'Interpreter', 'none');
                continue;
            end

            % Signal-Zeile
            y_top = y_top - RH;
            if y_top < 2
                break;
            end

            if iscell(e)
                fn = e{1};
                label = e{2};
                ok_fn = e{3};
            else
                fn =signal_zu_feldname(e);
                ok_fn = [fn, '_ok'];
                label = strrep(strrep(e, '_can', ''), '_', ' ');
                if numel(label) > 38
                    label = [label(1:36), char(8230)]; % % echte Ellipse
                end
            end

            [v, fc] =signal_wert_zu_zeitpunkt(signale, fn, ok_fn, []);

            uilabel(tab, ...
                'Position', [x0 + 1, y_top, 9, RH], ...
                'Text', '●', ...
                'FontSize', 5.5, ...
                'FontColor', fc, ...
                'BackgroundColor', 'none');

            uilabel(tab, ...
                'Position', [x0 + 10, y_top, nm_w, RH], ...
                'Text', label, ...
                'FontSize', FS_SIG, ...
                'FontColor', [0.82, 0.82, 0.82], ...
                'BackgroundColor', 'none', ...
                'Interpreter', 'none');

            lh = uilabel(tab, ...
                'Position', [x0 + col_w - val_w - 4, y_top, val_w, RH], ...
                'Text', v, ...
                'FontSize', FS_SIG, ...
                'FontWeight', 'bold', ...
                'FontColor', fc, ...
                'BackgroundColor', 'none', ...
                'HorizontalAlignment', 'right', ...
                'Interpreter', 'none');

            wert_label(end + 1) = lh;
            signal_info{end + 1} = {fn, ok_fn};
        end

        if y_top < 2
            break;
        end
    end

    % FIX: Sichere vertcat mit Cell-Arrays
    if isempty(signal_info)
        signal_info = {{'__time__', ''}};
    else
        signal_info = signal_info(:);
    end
end

function [wert_str, farbe] = signal_wert_zu_zeitpunkt(signale, fn, ok_fn, zeitpunkt)
%SIGNAL_WERT_ZU_ZEITPUNKT Gibt den Wert eines Signals als String zurueck.
%
%   Eingabe:
%       signale   — Struct mit Signalen
%       fn        — Feldname des Signals
%       ok_fn     — Feldname des OK-Flags
%       zeitpunkt — Zeitpunkt fuer Interpolation (leer = letzter Wert)
%
%   Ausgabe:
%       wert_str — Formatierter Wert oder '--'
%       farbe    — RGB-Farbe (OK=weiss, nicht OK=grau, Fehler=rot)
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

C = farben();
wert_str = '--';
farbe = C.grau3;

% OK-Flag pruefen
if ~isempty(ok_fn) && isfield(signale, ok_fn)
    if ~signale.(ok_fn)
        return;
    end
end

if ~isfield(signale, fn)
    return;
end

try
    daten =extrahiere_rohdaten(signale.(fn));

    if isempty(daten)
        return;
    end

    if isnumeric(daten)
        if isempty(zeitpunkt)
            % Letzten gueltigen Wert
            gueltig = find(~isnan(daten), 1, 'last');
            if isempty(gueltig)
                return;
            end
            wert = daten(gueltig);
        else
            % Interpolation am Zeitpunkt (falls timeseries)
            if isa(signale.(fn), 'timeseries')
                wert = interp1(signale.(fn).Time, daten, zeitpunkt, 'linear', 'extrap');
            else
                wert = daten(end);
            end
        end

        % Formatierung
        if abs(wert) >= 1000
            wert_str = sprintf('%.1f', wert);
        elseif abs(wert) >= 10
            wert_str = sprintf('%.2f', wert);
        elseif abs(wert) >= 1
            wert_str = sprintf('%.3f', wert);
        else
            wert_str = sprintf('%.4f', wert);
        end

        farbe = C.weiss;
    elseif islogical(daten)
        if daten(end)
            wert_str = '1';
            farbe = C.gruen;
        else
            wert_str = '0';
            farbe = C.rp_rot;
        end
    else
        wert_str = char(daten(end));
        farbe = C.weiss;
    end

catch
    wert_str = 'ERR';
    farbe = C.rp_rot;
end
end