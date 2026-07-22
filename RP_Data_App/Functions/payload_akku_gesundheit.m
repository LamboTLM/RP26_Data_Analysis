% =========================================================================
%  payload_akku_gesundheit  –  Dateivertrag fuer den Akku-Gesundheits-Tab
% -------------------------------------------------------------------------
%  Zweck         : Reicht das vorab berechnete Ergebnis von
%                  akku_gesundheit_scan (liegt in params.akku_gesundheit)
%                  an das Frontend weiter. Ohne Scan wird ein Leer-Zustand
%                  geliefert ("Ordner waehlen").
%
%  Hinweis       : Dieser Tab ist NICHT run-bezogen (kein Envelope, kein x).
%                  Der eigentliche Scan (inkl. Ladebalken) laeuft im
%                  App-Event-Callback, weil nur die App den uihtml-Handle fuer
%                  sendEventToHTML besitzt. Das Ergebnis wird in
%                  params.akku_gesundheit abgelegt und hier nur formatiert.
%
%  Abhaengigkeiten: (keine – reine Formatierung)
%  Autor         : <dein Name>
%  Datum         : 2026-07-18
% =========================================================================

function pl = payload_akku_gesundheit(store, x, params, runden) %#ok<INUSL,INUSD>
%PAYLOAD_AKKU_GESUNDHEIT  pl = PAYLOAD_AKKU_GESUNDHEIT(store, x, params, runden)
%   Changelog:
%     2026-07-18  Erststand.

    pl = struct();
    pl.meta = struct('tab', 'akku_gesundheit');

    g = feld(params, 'akku_gesundheit', []);
    if isempty(g) || ~isstruct(g)
        pl.panels = struct('status', 'leer');
        return;
    end
    pl.panels = struct('status', 'fertig', 'gesundheit', g);
end

% =========================================================================
%  Functions
% =========================================================================

function val = feld(s, name, default)
    if isstruct(s) && isfield(s, name), val = s.(name); else, val = default; end
end
