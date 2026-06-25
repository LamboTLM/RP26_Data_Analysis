function build_snapshot_fenster(signale, t_snap, cfg)
    % Erstellt Snapshot-Fenster mit allen Signalwerten zu t_snap
    % Autor: [Benutzer]
    % Datum: 2026-06-24

    C = cfg.farben;
    fig2 = uifigure('Name', sprintf('Snapshot  @  t = %.3f s', t_snap), ...
        'Position', [150, 80, 820, 820], 'Color', C.hintergrund);

    uilabel(fig2, 'Position', [14, 775, 790, 34], ...
        'Text', sprintf('Signalzustand  @  t = %.3f s', t_snap), ...
        'FontSize', 15, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');

    uilabel(fig2, 'Position', [14, 742, 45, 20], 'Text', 'Filter:', 'FontSize', 9, ...
        'FontColor', C.grau, 'BackgroundColor', 'none');
    ef_filter = uieditfield(fig2, 'text', 'Position', [62, 740, 430, 24], ...
        'FontSize', 9, 'BackgroundColor', C.karte, 'FontColor', C.weiss, ...
        'Placeholder', 'Signalname filtern...');

    lbl_anzahl = uilabel(fig2, 'Position', [504, 742, 300, 22], 'Text', '...', ...
        'FontSize', 9, 'FontColor', C.grau, 'BackgroundColor', 'none', 'HorizontalAlignment', 'right');

    % Pre-allocation
    feld_namen = fieldnames(signale);
    n_schaetzer = numel(feld_namen);
    alle_namen = cell(n_schaetzer, 1);
    alle_werte = cell(n_schaetzer, 1);
    idx = 0;

    for i = 1:numel(feld_namen)
        fn = feld_namen{i};
        if endsWith(fn, '_ok')
            continue;
        end
        if any(strcmp(fn, {'t_base', 't_base_ok', 'gps_x', 'gps_y', 'gps_t', 'E_total_kWh', 'E_regen_kWh'}))
            continue;
        end
        ok_fn = [fn, '_ok'];
        if ~isfield(signale, ok_fn) && isnumeric(signale.(fn)) && isscalar(signale.(fn))
            idx = idx + 1;
            alle_namen{idx} = fn;
            alle_werte{idx} = sprintf('%.5g  [konstant]', signale.(fn));
            continue;
        end
        if ~isfield(signale, ok_fn) || ~signale.(ok_fn)
            continue;
        end
        ts = signale.(fn);
        if ~isa(ts, 'timeseries') || isempty(ts.Data)
            continue;
        end
        try
            t_vec = ts.Time;
            d_vec = double(ts.Data);
            if size(d_vec, 2) > 1
                d_vec = d_vec(:, 1);
            end
            if t_snap <= t_vec(1)
                val = d_vec(1);
            elseif t_snap >= t_vec(end)
                val = d_vec(end);
            else
                val = interp1(t_vec, d_vec, t_snap, 'linear');
            end
            sig_label = ts.Name;
            if isempty(sig_label)
                sig_label = fn;
            end
            idx = idx + 1;
            alle_namen{idx} = sig_label;
            alle_werte{idx} = sprintf('%.5g', val);
        catch
            % ignore
        end
    end

    alle_namen = alle_namen(1:idx);
    alle_werte = alle_werte(1:idx);

    if ~isempty(alle_namen)
        [alle_namen, sort_idx] = sort(alle_namen);
        alle_werte = alle_werte(sort_idx);
    end
    n_sigs = numel(alle_namen);
    lbl_anzahl.Text = sprintf('%d Signale gefunden', n_sigs);

    if n_sigs == 0
        uilabel(fig2, 'Position', [14, 380, 790, 30], ...
            'Text', 'Keine Signaldaten verfuegbar.', 'FontSize', 12, ...
            'FontColor', C.fehlend, 'BackgroundColor', 'none', 'HorizontalAlignment', 'center');
        return;
    end

    uit = uitable(fig2, 'Position', [14, 14, 790, 718], ...
        'Data', [alle_namen(:), alle_werte(:)], ...
        'ColumnName', {'Signal', sprintf('Wert  @  t = %.3f s', t_snap)}, ...
        'ColumnWidth', {460, 250}, 'FontSize', 10, 'RowName', {}, ...
        'BackgroundColor', [C.karte; C.panel], 'ForegroundColor', C.weiss);

    ef_filter.ValueChangedFcn = @(src,~) ...
        filter_snapshot_tabelle(uit, alle_namen, alle_werte, src.Value, lbl_anzahl, n_sigs);
end