function plot_oder_leer(ax, signale, signal_namen, label, cfg, ist_abgeleitet)
% Plottet Signale oder zeigt "Keine Daten"
% Autor: [Benutzer]
% Datum: 2026-06-24

if nargin < 6
    ist_abgeleitet = false;
end

C = cfg.farben;
farben = {C.rot, C.rot_hell, C.orange, C.gruen, [0.4, 0.7, 1], [0.9, 0.9, 0.4], C.grau};
hold(ax, 'on');
n_geplottet = 0;
fehlende_label = {};

for i = 1:numel(signal_namen)
    sn = signal_namen{i};
    lbl = label{i};
    fn = tern_str(ist_abgeleitet, sn, signal_zu_feldname(sn));
    col = farben{mod(i - 1, numel(farben)) + 1};

    if isfield(signale, fn) && isfield(signale, [fn, '_ok']) && signale.([fn, '_ok'])
        try
            ts = signale.(fn);
            if isa(ts, 'timeseries') && ~isempty(ts.Data)
                d_vec = double(ts.Data);
                if size(d_vec, 2) > 1
                    d_vec = d_vec(:, 1);
                end
                plot(ax, ts.Time, d_vec, 'Color', col, 'LineWidth', 1.2, 'DisplayName', lbl);
                n_geplottet = n_geplottet + 1;
            elseif isnumeric(ts) && ~isempty(ts)
                fehlende_label{end + 1} = [lbl, ' (keine Zeitachse)'];
            else
                fehlende_label{end + 1} = lbl;
            end
        catch ME2
            fehlende_label{end + 1} = [lbl, ' (ERR: ', ME2.message(1:min(40, end)), ')'];
        end
    else
        fehlende_label{end + 1} = lbl;
    end
end

if n_geplottet > 0
    legend(ax, 'Location', 'best', 'TextColor', C.grau, ...
        'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
    xlabel(ax, 'Zeit (s)', 'Color', C.grau, 'FontSize', 8);
end

if ~isempty(fehlende_label)
    ylims = ylim(ax);
    xlims = xlim(ax);
    if n_geplottet == 0
        ax.Color = [0.11, 0.11, 0.11];
        text(ax, mean(xlims), mean(ylims), ...
            sprintf('KEINE DATEN\n%s', strjoin(fehlende_label, '\n')), ...
            'Color', C.fehlend, 'FontSize', 9, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    else
        text(ax, xlims(1), ylims(1), sprintf('Keine Daten: %s', strjoin(fehlende_label, ', ')), ...
            'Color', C.fehlend, 'FontSize', 8, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
    end
end
hold(ax, 'off');
end