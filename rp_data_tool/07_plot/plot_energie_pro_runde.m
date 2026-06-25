function plot_energie_pro_runde(ax, signale, cfg)
% Plottet Energieverbrauch pro Runde
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
fn_lap = signal.signal_zu_feldname('lap_cnt_can');
if ~isfield(signale, 'P_pack_ok') || ~signale.P_pack_ok || ~isfield(signale, fn_lap) || ~signale.([fn_lap, '_ok'])
    util.markiere_leer(ax, 'Lap counter oder Pack-Leistung nicht verfuegbar', cfg);
    return;
end

try
    lap_ts = signale.(fn_lap);
    P_ts = util.sicheres_resample(signale.P_pack, lap_ts.Time);
    laps = round(lap_ts.Data);
    u_laps = unique(laps);
    u_laps = u_laps(u_laps > 0);
    E_pro_runde = zeros(numel(u_laps), 1);

    for i = 1:numel(u_laps)
        mask = laps == u_laps(i);
        t_runde = lap_ts.Time(mask);
        P_runde = P_ts.Data(mask);
        E_pro_runde(i) = trapz(t_runde, P_runde) * cfg.phys.kwh_pro_j;
    end

    bar(ax, u_laps, E_pro_runde, 'FaceColor', C.rot, 'EdgeColor', 'none');
    xlabel(ax, 'Runde', 'Color', C.grau, 'FontSize', 8);
    ylabel(ax, 'Energie (kWh)', 'Color', C.grau, 'FontSize', 8);
    hold(ax, 'on');
    yline(ax, mean(E_pro_runde), '--', 'Color', C.orange, 'LineWidth', 1.2);
    hold(ax, 'off');
catch ME
    util.markiere_leer(ax, sprintf('Fehler: %s', ME.message), cfg);
end
end