%% TRACKMAP — Standalone Debug Script
% Voraussetzung: S ist bereits im Workspace geladen (via RP_DataTool oder manuell)
% Führe die Abschnitte einzeln aus (Ctrl+Enter pro Abschnitt)

%% 1) Rohdaten prüfen
ax_fn = 'INS_acc_x_can';
ay_fn = 'INS_acc_y_can';

ax_ts = S.(ax_fn);
ay_ts = S.(ay_fn);

fprintf('acc_x: %d Punkte, min=%.3f, max=%.3f\n', numel(ax_ts.Data), min(ax_ts.Data), max(ax_ts.Data));
fprintf('acc_y: %d Punkte, min=%.3f, max=%.3f\n', numel(ay_ts.Data), min(ay_ts.Data), max(ay_ts.Data));

%% 2) Zeitbasis aufbauen und resamplen
t_vec = ax_ts.Time;                          % Zeitvektor in Sekunden
ay_r  = resample(ay_ts, t_vec);              % ay auf selbe Zeitbasis
dt    = mean(diff(t_vec));
fprintf('dt = %.4f s  (%.1f Hz)\n', dt, 1/dt);

ax = ax_ts.Data;
ay = ay_r.Data;

%% 3) Rohe Integration OHNE Filter — zum Vergleich
vx_raw = cumtrapz(t_vec, ax);
vy_raw = cumtrapz(t_vec, ay);
px_raw = cumtrapz(t_vec, vx_raw);
py_raw = cumtrapz(t_vec, vy_raw);

figure('Name','Track RAW (kein Filter)','Color','k');
plot(px_raw, py_raw, 'w-', 'LineWidth', 0.8);
axis equal; grid on;
set(gca,'Color','k','XColor','w','YColor','w');
title('RAW — kein Filter','Color','w');

%% 4) Hochpassfilter + doppelte Integration
% IIR Hochpass 1. Ordnung, alpha nahe 1 = niedrige Cutoff-Frequenz
alpha = 0.998;   % ~0.01 Hz cutoff bei 100 Hz Abtastrate — anpassen falls nötig

% Hochpass auf Beschleunigung
ax_hp = zeros(size(ax));
ay_hp = zeros(size(ay));
for k = 2:numel(ax)
    ax_hp(k) = alpha * (ax_hp(k-1) + ax(k) - ax(k-1));
    ay_hp(k) = alpha * (ay_hp(k-1) + ay(k) - ay(k-1));
end

% 1. Integration: acc → vel
vx_i = cumtrapz(t_vec, ax_hp);
vy_i = cumtrapz(t_vec, ay_hp);

% Hochpass auf Geschwindigkeit
vx_hp = zeros(size(vx_i));
vy_hp = zeros(size(vy_i));
for k = 2:numel(vx_i)
    vx_hp(k) = alpha * (vx_hp(k-1) + vx_i(k) - vx_i(k-1));
    vy_hp(k) = alpha * (vy_hp(k-1) + vy_i(k) - vy_i(k-1));
end

% 2. Integration: vel → pos
px = cumtrapz(t_vec, vx_hp);
py = cumtrapz(t_vec, vy_hp);

%% 5) Track plotten — gefärbt nach Geschwindigkeit (speed_can)
figure('Name','Track MAP — gefärbt nach Speed','Color',[0.12 0.12 0.12]);
ax_plot = axes('Color',[0.13 0.13 0.13],'XColor',[0.6 0.6 0.6],'YColor',[0.6 0.6 0.6]);
hold on;

% Versuche speed_can für Farbe
spd_fn = 'speed_can';
colored = false;
if isfield(S, spd_fn) && S.([spd_fn '_ok'])
    try
        spd_ts   = S.(spd_fn);
        spd_interp = interp1(spd_ts.Time, spd_ts.Data, t_vec, 'linear', 'extrap');
        spd_interp = max(0, spd_interp);

        % Scatter mit Farbkodierung
        scatter(ax_plot, px, py, 2, spd_interp, 'filled', 'MarkerFaceAlpha', 0.7);
        colormap(ax_plot, hot);
        cb = colorbar(ax_plot);
        cb.Color = [0.7 0.7 0.7];
        cb.Label.String = 'Speed (km/h)';
        colored = true;
    catch
        colored = false;
    end
end

if ~colored
    plot(ax_plot, px, py, 'Color', [0.8 0 0], 'LineWidth', 1.0);
end

% Startpunkt markieren
plot(ax_plot, px(1), py(1), 'o', 'MarkerSize', 10, ...
    'MarkerFaceColor', [0.3 0.75 0.3], 'MarkerEdgeColor', 'w', ...
    'DisplayName', 'Start');

axis(ax_plot, 'equal');
grid(ax_plot, 'on');
ax_plot.GridColor     = [0.25 0.25 0.25];
ax_plot.GridAlpha     = 0.6;
xlabel(ax_plot, 'X (m)', 'Color', [0.6 0.6 0.6]);
ylabel(ax_plot, 'Y (m)', 'Color', [0.6 0.6 0.6]);
title(ax_plot, 'Track Map — INS acc double integration', 'Color', [0.8 0 0], 'FontWeight', 'bold');

%% 6) Alpha-Wert Tuning — falls Track nicht erkennbar
% Probiere diese Werte: 0.990 / 0.995 / 0.998 / 0.9995
% Niedrigerer alpha = aggressiverer Hochpass = weniger Drift, aber auch weniger DC
% Führe Abschnitt 4+5 nochmal mit anderem alpha aus

fprintf('\nTipp: Falls der Track nicht erkennbar ist, alpha in Abschnitt 4 anpassen.\n');
fprintf('Aktuell: alpha = %.4f\n', alpha);
fprintf('Versuche: 0.990 (aggressiv) bis 0.9995 (sanft)\n');