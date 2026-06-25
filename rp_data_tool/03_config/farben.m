function C = farben()
%FARBEN Racing-Performance Farbpalette fuer GUI und Plots.
%
%   Ausgabe:
%       C — Struct mit allen Farbdefinitionen
%
%   Verwendete Felder (passend zu erstelle_plot_bereich):
%       C.panel   — Panel-Hintergrund
%       C.grau2   — Border/Highlight
%       C.rot     — RP-Rot (Titel, Akzente)
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

    C = struct();

    %% --- RP Branding ---
    C.rot     = [0.85, 0.15, 0.15];  % % Racing-Performance-Rot
    C.dunkel  = [0.10, 0.10, 0.12];  % % Sehr dunkel (Haupt-HG)
    C.schwarz = [0.05, 0.05, 0.05];  % % Fast schwarz

    %% --- UI-Grau-Stufen ---
    C.panel   = [0.18, 0.18, 0.20];  % % Panel-Hintergrund
    C.grau1   = [0.22, 0.22, 0.24];  % % Leicht aufgehellt
    C.grau2   = [0.30, 0.30, 0.32];  % % Border/Highlight
    C.grau3   = [0.45, 0.45, 0.48];  % % Inaktiv/Disabled
    C.weiss   = [0.95, 0.95, 0.95];  % % Textweiss

    %% --- Status-Farben ---
    C.gruen   = [0.20, 0.75, 0.35];  % % OK / Positiv
    C.gelb    = [0.95, 0.75, 0.15];  % % Warnung
    C.orange  = [0.95, 0.50, 0.15];  % % Kritisch

    %% --- Plot-Farben (Multi-Line) ---
    C.plot_blau   = [0.15, 0.55, 0.85];
    C.plot_gruen  = [0.35, 0.75, 0.35];
    C.plot_orange = [0.95, 0.65, 0.15];
    C.plot_lila   = [0.55, 0.25, 0.75];
    C.plot_cyan   = [0.15, 0.75, 0.75];

    %% --- Shortcut-Vektor fuer Plot-Reihen ---
    C.plot_reihe = [
        C.rot;
        C.plot_blau;
        C.plot_gruen;
        C.plot_orange;
        C.plot_lila;
        C.plot_cyan
    ];
end