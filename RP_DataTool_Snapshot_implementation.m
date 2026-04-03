%% RP_DataTool.m
% FSAE Data Analysis Tool — Racing Performance Electrical
% Compatible: MATLAB R2023b+
% Usage: Run this script, then select MDF4 file via dialog
% =========================================================

function RP_DataTool()
    clc;
    fprintf('============================================\n');
    fprintf('  RP FSAE Data Analysis Tool\n');
    fprintf('  Racing Performance — Electrical\n');
    fprintf('============================================\n\n');

    [fname, fpath] = uigetfile('*.mf4;*.MF4', 'MDF4 Datei auswählen');
    if isequal(fname, 0)
        fprintf('Kein File gewählt. Tool wird beendet.\n');
        return;
    end
    Dateiname = fullfile(fpath, fname);
    fprintf('Lade: %s\n', Dateiname);

    try
        FileInfo = mdfInfo(Dateiname);
        Channels = mdfChannelInfo(Dateiname);
        Data     = mdfRead(Dateiname);
        fprintf('Datei geladen. Kanäle gefunden: %d\n', height(Channels));
    catch ME
        errordlg(sprintf('Fehler beim Laden:\n%s', ME.message), 'Ladefehler');
        return;
    end

    fprintf('mdfRead Format: %s, Gruppen: %d\n', class(Data), numel(Data));
    meta = parseFilename(fname);

    fprintf('Extrahiere Signale...\n');
    S = extractSignals(Data, Channels);
    fprintf('Signalextraktion abgeschlossen.\n\n');

    S = computeDerived(S);
    buildGUI(S, meta, Dateiname);
end

% =========================================================
%% FILENAME PARSER
% =========================================================
function meta = parseFilename(fname)
    meta.filename = fname;
    meta.vehicle  = 'Unbekannt';
    meta.date     = 'Unbekannt';
    meta.time     = '';
    meta.event    = 'Unbekannt';

    tokens = regexp(fname, '^(.+?)_(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})_(.+?)_(.+?)\.mf4$', 'tokens', 'ignorecase');
    if ~isempty(tokens)
        t = tokens{1};
        if numel(t) >= 5
            meta.vehicle = t{1};
            meta.date    = t{2};
            meta.time    = strrep(t{3}, '-', ':');
            meta.mode    = t{4};
            meta.event   = strrep(t{5}, '_', ' ');
        end
    end
end

% =========================================================
%% SIGNAL EXTRACTION
% =========================================================
function S = extractSignals(Data, Channels)
    signals = getSignalList();
    nFound  = 0;

    fprintf('  Durchsuche %d Cell-Gruppen nach Signalen...\n', numel(Data));

    lookup = containers.Map('KeyType','char','ValueType','any');
    for ci = 1:numel(Data)
        tt = Data{ci};
        if ~isa(tt, 'timetable'); continue; end
        cols = tt.Properties.VariableNames;
        for k = 1:numel(cols)
            if ~isKey(lookup, cols{k})
                lookup(cols{k}) = struct('cellIdx', ci, 'colName', cols{k});
            end
        end
    end
    fprintf('  Lookup fertig: %d eindeutige Spaltennamen.\n', lookup.Count);

    for i = 1:numel(signals)
        signame = signals{i};
        fname   = matlab2fieldname(signame);

        if isKey(lookup, signame)
            info    = lookup(signame);
            ci      = info.cellIdx;
            colName = info.colName;
            try
                tt    = Data{ci};
                t_raw = tt.Properties.RowTimes;
                if isa(t_raw, 'duration')
                    t_sec = seconds(t_raw - t_raw(1));
                elseif isa(t_raw, 'datetime')
                    t_sec = seconds(t_raw - t_raw(1));
                else
                    t_sec = double(t_raw) - double(t_raw(1));
                end
                vals  = tt.(colName);
                if ~isa(vals, 'double'); vals = double(vals); end
                if size(vals, 2) > 1; vals = vals(:,1); end
                S.(fname)         = timeseries(vals, t_sec, 'Name', signame);
                S.([fname '_ok']) = true;
                nFound = nFound + 1;
            catch ME
                S.(fname)         = [];
                S.([fname '_ok']) = false;
                if nFound == 0 && i <= 5
                    fprintf('  [ERR] %s: %s\n', signame, ME.message);
                end
            end
        else
            S.(fname)         = [];
            S.([fname '_ok']) = false;
        end
    end

    fprintf('  Signale erfolgreich geladen: %d / %d\n', nFound, numel(signals));

    fn_test = 'speed_can';
    if isfield(S, fn_test)
        fprintf('  [DEBUG] speed_can Feld vorhanden, _ok=%d\n', S.([fn_test '_ok']));
        if S.([fn_test '_ok'])
            fprintf('  [DEBUG] speed_can: %d Punkte, max=%.2f\n', numel(S.(fn_test).Data), max(S.(fn_test).Data));
        end
    else
        fprintf('  [DEBUG] speed_can NICHT als Feld in S vorhanden!\n');
    end

    S.t_base    = [];
    S.t_base_ok = false;
    for i = 1:numel(signals)
        fn = matlab2fieldname(signals{i});
        if isfield(S, [fn '_ok']) && S.([fn '_ok'])
            try
                S.t_base    = S.(fn).Time;
                S.t_base_ok = true;
                break;
            catch; end
        end
    end
end

function fname = matlab2fieldname(signame)
    fname = regexprep(signame, '[^a-zA-Z0-9_]', '_');
    if ~isempty(fname) && ~isletter(fname(1))
        fname = ['sig_' fname];
    end
end

% =========================================================
%% DERIVED QUANTITIES
% =========================================================
function S = computeDerived(S)
    wheels = {'fl','fr','rl','rr'};
    for i = 1:numel(wheels)
        w = wheels{i};
        spd_fn  = matlab2fieldname(['unitek_' w '_speed_motor_ist_can']);
        tq_fn   = matlab2fieldname(['unitek_' w '_torque_motor_ist_can']);
        vdc_fn  = matlab2fieldname(['unitek_' w '_Vdc_Bus_can']);
        iist_fn = matlab2fieldname(['unitek_' w '_i_ist_can']);

        S.(['omega_' w '_ok'])  = false;
        S.(['P_mech_' w '_ok']) = false;
        S.(['P_dc_'   w '_ok']) = false;
        S.(['P_loss_' w '_ok']) = false;

        if isfield(S, spd_fn) && S.([spd_fn '_ok'])
            try
                omega = S.(spd_fn);
                omega.Data = omega.Data * (2*pi/60);
                S.(['omega_' w]) = omega;
                S.(['omega_' w '_ok']) = true;
            catch; end
        end

        if S.(['omega_' w '_ok']) && isfield(S, tq_fn) && S.([tq_fn '_ok'])
            try
                tq     = resample(S.(tq_fn), S.(['omega_' w]).Time);
                P_mech = tq;
                P_mech.Data = tq.Data .* S.(['omega_' w]).Data;
                S.(['P_mech_' w]) = P_mech;
                S.(['P_mech_' w '_ok']) = true;
            catch; end
        end

        if isfield(S, vdc_fn) && S.([vdc_fn '_ok']) && ...
           isfield(S, iist_fn) && S.([iist_fn '_ok'])
            try
                vdc  = S.(vdc_fn);
                ii   = resample(S.(iist_fn), vdc.Time);
                P_dc = vdc;
                P_dc.Data = vdc.Data .* ii.Data;
                S.(['P_dc_' w]) = P_dc;
                S.(['P_dc_' w '_ok']) = true;
            catch; end
        end

        if S.(['P_dc_' w '_ok']) && S.(['P_mech_' w '_ok'])
            try
                P_mech_r = resample(S.(['P_mech_' w]), S.(['P_dc_' w]).Time);
                P_loss   = S.(['P_dc_' w]);
                P_loss.Data = S.(['P_dc_' w]).Data - P_mech_r.Data;
                S.(['P_loss_' w]) = P_loss;
                S.(['P_loss_' w '_ok']) = true;
            catch; end
        end
    end

    vfn = matlab2fieldname('IVT_Result_U2_Post_Airs_can');
    ifn = matlab2fieldname('IVT_Result_I_can');
    S.P_pack_ok = false;
    if isfield(S,vfn) && S.([vfn '_ok']) && isfield(S,ifn) && S.([ifn '_ok'])
        try
            ii     = resample(S.(ifn), S.(vfn).Time);
            P_pack = S.(vfn);
            P_pack.Data = S.(vfn).Data .* ii.Data;
            S.P_pack    = P_pack;
            S.P_pack_ok = true;
        catch; end
    end

    S.P_mech_total_ok = false;
    if S.P_mech_fl_ok && S.P_mech_fr_ok && S.P_mech_rl_ok && S.P_mech_rr_ok
        try
            t_ref = S.P_mech_fl.Time;
            Ptot  = S.P_mech_fl;
            for w = {'fr','rl','rr'}
                Pr = resample(S.(['P_mech_' w{1}]), t_ref);
                Ptot.Data = Ptot.Data + Pr.Data;
            end
            S.P_mech_total    = Ptot;
            S.P_mech_total_ok = true;
        catch; end
    end

    S.eta_powertrain_ok = false;
    if S.P_pack_ok && S.P_mech_total_ok
        try
            P_pack_r = resample(S.P_pack, S.P_mech_total.Time);
            eta      = S.P_mech_total;
            valid    = abs(P_pack_r.Data) > 100;
            eta.Data = zeros(size(P_pack_r.Data));
            eta.Data(valid) = S.P_mech_total.Data(valid) ./ P_pack_r.Data(valid) * 100;
            eta.Data = max(0, min(100, eta.Data));
            S.eta_powertrain    = eta;
            S.eta_powertrain_ok = true;
        catch; end
    end

    S.E_regen_ok = false;
    if S.P_pack_ok
        try
            dt          = mean(diff(S.P_pack.Time));
            regen_mask  = S.P_pack.Data < 0;
            E_regen_J   = sum(abs(S.P_pack.Data(regen_mask))) * dt;
            S.E_regen_kWh = E_regen_J / 3.6e6;
            S.E_regen_ok  = true;
        catch; end
    end

    S.E_total_ok = false;
    if S.P_pack_ok
        try
            dt         = mean(diff(S.P_pack.Time));
            drive_mask = S.P_pack.Data > 0;
            E_J        = sum(S.P_pack.Data(drive_mask)) * dt;
            S.E_total_kWh = E_J / 3.6e6;
            S.E_total_ok  = true;
        catch; end
    end

    S.gps_x_ok = false;
    vx_fn = matlab2fieldname('INS_vel_x_can');
    vy_fn = matlab2fieldname('INS_vel_y_can');
    ax_fn = matlab2fieldname('INS_acc_x_can');
    ay_fn = matlab2fieldname('INS_acc_y_can');

    if isfield(S,vx_fn) && S.([vx_fn '_ok']) && ...
       isfield(S,vy_fn) && S.([vy_fn '_ok'])
        try
            vx = S.(vx_fn);
            vy = resample(S.(vy_fn), vx.Time);
            dt = mean(diff(vx.Time));
            S.gps_x    = cumsum(vx.Data) * dt;
            S.gps_y    = cumsum(vy.Data) * dt;
            S.gps_t    = vx.Time;
            S.gps_x_ok = true;
            fprintf('  GPS: velocity integration OK (%d points)\n', numel(S.gps_x));
        catch; end
    end

    if ~S.gps_x_ok && isfield(S,ax_fn) && S.([ax_fn '_ok']) && ...
                       isfield(S,ay_fn) && S.([ay_fn '_ok'])
        try
            ax_ts = S.(ax_fn);
            ay_ts = resample(S.(ay_fn), ax_ts.Time);
            t_vec = ax_ts.Time;
            ax    = ax_ts.Data;
            ay    = ay_ts.Data;

            alpha  = 0.995;
            ax_hp  = zeros(size(ax)); ay_hp = zeros(size(ay));
            for k = 2:numel(ax)
                ax_hp(k) = alpha * (ax_hp(k-1) + ax(k) - ax(k-1));
                ay_hp(k) = alpha * (ay_hp(k-1) + ay(k) - ay(k-1));
            end

            vx_i = cumtrapz(t_vec, ax_hp);
            vy_i = cumtrapz(t_vec, ay_hp);

            vx_hp = zeros(size(vx_i)); vy_hp = zeros(size(vy_i));
            for k = 2:numel(vx_i)
                vx_hp(k) = alpha * (vx_hp(k-1) + vx_i(k) - vx_i(k-1));
                vy_hp(k) = alpha * (vy_hp(k-1) + vy_i(k) - vy_i(k-1));
            end

            S.gps_x    = cumtrapz(t_vec, vx_hp);
            S.gps_y    = cumtrapz(t_vec, vy_hp);
            S.gps_t    = t_vec;
            S.gps_x_ok = true;
            fprintf('  GPS: double-integration from acc OK (%d points)\n', numel(S.gps_x));
        catch ME
            fprintf('  GPS: failed - %s\n', ME.message);
        end
    end
end

% =========================================================
%% GUI BUILDER
% =========================================================
function buildGUI(S, meta, filepath)
    C.bg        = [0.12 0.12 0.12];
    C.bg2       = [0.15 0.15 0.15];
    C.panel     = [0.16 0.16 0.16];
    C.card      = [0.20 0.20 0.20];
    C.red       = [0.80 0.00 0.00];
    C.redlight  = [1.00 0.42 0.42];
    C.white     = [1.00 1.00 1.00];
    C.gray      = [0.55 0.55 0.55];
    C.gray2     = [0.35 0.35 0.35];
    C.green     = [0.30 0.75 0.30];
    C.orange    = [1.00 0.60 0.00];
    C.yellow    = [1.00 0.85 0.00];
    C.missing   = [0.50 0.50 0.50];

    t_total = 0;
    if isfield(S,'t_base') && ~isempty(S.t_base)
        t_total = max(S.t_base);
    end
    if t_total < 1; t_total = 3600; end

    fig = uifigure('Name', sprintf('RP FSAE Data Tool — %s — %s', meta.vehicle, meta.event), ...
        'Position', [50 50 1600 980], ...
        'Color', C.bg);

    % --- Top Bar — gibt btnSnap zurück ---
    btnSnap = buildTopBar(fig, meta, filepath, S, C);

    % --- Slider Panel ---
    sliderPanel = uipanel(fig, 'Position', [0 900 1600 52], ...
        'BackgroundColor', [0.10 0.10 0.10], 'BorderType', 'none');

    uilabel(sliderPanel, 'Position', [8 17 55 18], ...
        'Text', 't start (s)', 'FontSize', 9, 'FontColor', C.red, 'BackgroundColor', 'none');
    efStart = uieditfield(sliderPanel, 'numeric', ...
        'Position', [68 15 65 22], 'Value', 0, 'Limits', [0 t_total], ...
        'FontSize', 9, 'BackgroundColor', C.card, 'FontColor', C.white);
    slStart = uislider(sliderPanel, 'Position', [145 28 550 3], ...
        'Limits', [0 t_total], 'Value', 0, 'MajorTicks', [], 'MinorTicks', []);

    uilabel(sliderPanel, 'Position', [720 17 55 18], ...
        'Text', 't end (s)', 'FontSize', 9, 'FontColor', C.red, 'BackgroundColor', 'none');
    efEnd = uieditfield(sliderPanel, 'numeric', ...
        'Position', [780 15 65 22], 'Value', t_total, 'Limits', [0 t_total], ...
        'FontSize', 9, 'BackgroundColor', C.card, 'FontColor', C.white);
    slEnd = uislider(sliderPanel, 'Position', [858 28 550 3], ...
        'Limits', [0 t_total], 'Value', t_total, 'MajorTicks', [], 'MinorTicks', []);

    lblRange = uilabel(sliderPanel, 'Position', [1430 17 160 18], ...
        'Text', sprintf('%.0f s total', t_total), ...
        'FontSize', 9, 'FontColor', C.gray, 'BackgroundColor', 'none');

    % --- Tab Group ---
    tg = uitabgroup(fig, 'Position', [0 0 1600 900], 'TabLocation', 'top');

    tabNames = {'Dashboard','Battery & AMS','Powertrain',...
        'Vehicle Dynamics','Efficiency','Temperaturen',...
        'Slip & TC','PDU & Power','Alle Signale'};

    tabs = gobjects(numel(tabNames),1);
    for i = 1:numel(tabNames)
        tabs(i) = uitab(tg, 'Title', tabNames{i}, 'BackgroundColor', C.bg);
    end

    % --- Tabs aufbauen ---
    buildTabDashboard(    tabs(1), S, meta, C);
    buildTabBattery(      tabs(2), S, C);
    buildTabPowertrain(   tabs(3), S, C);
    buildTabDynamics(     tabs(4), S, C);
    buildTabEfficiency(   tabs(5), S, C);
    buildTabTemperatures( tabs(6), S, C);
    buildTabSlipTC(       tabs(7), S, C);
    buildTabPDU(          tabs(8), S, C);

    % Tab 9 gibt Handles zurück für Snapshot-Update
    [valLabels, sigInfo] = buildTabAllSignals(tabs(9), S, C);

    % --- Snapshot-Button Callback JETZT setzen (valLabels existiert) ---
    efSnap = btnSnap.UserData;
    btnSnap.ButtonPushedFcn = @(~,~) onSnapshotBtn(S, efSnap, valLabels, sigInfo, C);

    % --- Slider Callbacks ---
    function applyTimeWindow(ts, te)
        ts = max(0, min(ts, te - 0.1));
        te = min(t_total, max(te, ts + 0.1));
        slStart.Value = ts; efStart.Value = ts;
        slEnd.Value   = te; efEnd.Value   = te;
        lblRange.Text = sprintf('%.1f – %.1f s  (%.1f s)', ts, te, te-ts);
        axList = findall(fig, 'Type', 'axes');
        for ai = 1:numel(axList)
            try; xlim(axList(ai), [ts te]); catch; end
        end
    end

    slStart.ValueChangedFcn = @(src,~) applyTimeWindow(src.Value, slEnd.Value);
    slEnd.ValueChangedFcn   = @(src,~) applyTimeWindow(slStart.Value, src.Value);
    efStart.ValueChangedFcn = @(src,~) applyTimeWindow(src.Value, slEnd.Value);
    efEnd.ValueChangedFcn   = @(src,~) applyTimeWindow(slStart.Value, src.Value);

    fprintf('GUI gestartet.\n');
end

% =========================================================
%% TOP BAR  — gibt btnSnap zurück
% =========================================================
function btnSnap = buildTopBar(fig, meta, filepath, S, C)
    topbar = uipanel(fig, 'Position', [0 935 1600 45], ...
        'BackgroundColor', [0.08 0.08 0.08], 'BorderType', 'none');

    uilabel(topbar, 'Position', [10 10 200 25], ...
        'Text', sprintf('%s  |  %s', meta.vehicle, meta.event), ...
        'FontSize', 13, 'FontWeight', 'bold', ...
        'FontColor', C.white, 'BackgroundColor', 'none');

    uilabel(topbar, 'Position', [230 10 200 25], ...
        'Text', sprintf('%s  %s', meta.date, meta.time), ...
        'FontSize', 11, 'FontColor', C.gray, 'BackgroundColor', 'none');

    [~,fn,ext] = fileparts(filepath);
    uilabel(topbar, 'Position', [430 10 380 25], ...
        'Text', [fn ext], 'FontSize', 10, 'FontColor', C.gray2, 'BackgroundColor', 'none');

    uilabel(topbar, 'Position', [845 13 85 18], ...
        'Text', 'Snapshot (s):', 'FontSize', 9, ...
        'FontColor', C.gray, 'BackgroundColor', 'none');

    efSnap = uieditfield(topbar, 'numeric', ...
        'Position', [935 11 75 23], 'Value', 0, ...
        'FontSize', 9, 'BackgroundColor', C.card, 'FontColor', C.white);

    % Callback wird NACH buildTabAllSignals in buildGUI gesetzt
    btnSnap = uibutton(topbar, 'Position', [1020 8 115 28], ...
        'Text', '▶  Snapshot', ...
        'BackgroundColor', C.red, 'FontColor', C.white, 'FontWeight', 'bold');

    % efSnap im UserData transportieren damit buildGUI drauf zugreifen kann
    btnSnap.UserData = efSnap;

    uibutton(topbar, 'Position', [1150 8 130 28], ...
        'Text', 'Export PDF / PNG', ...
        'BackgroundColor', [0.25 0.25 0.25], ...
        'FontColor', C.white, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) exportReport(S, meta));
end

% =========================================================
%% SNAPSHOT CALLBACK
% =========================================================
function onSnapshotBtn(S, efSnap, valLabels, sigInfo, C)
    t = efSnap.Value;
    buildSnapshotWindow(S, t, C);
    updateAllSignalsTab(valLabels, sigInfo, S, t, C);
end

% =========================================================
%% TAB 1 — DASHBOARD
% =========================================================
function buildTabDashboard(tab, S, meta, C)
    kpiData = computeKPIs(S);
    buildKPIRow(tab, kpiData, C, [10 820 760 90]);
    buildStatusBadges(tab, S, C, [10 760 760 55]);

    ax1 = buildPlotArea(tab, [10 540 760 210], 'Speed & Torque', C);
    plotOrMissing(ax1, S, {'speed_can','drive_pwtrTqTarget_can','tq_vehicle_pos_limit_can'}, ...
        {'Speed (km/h)','Tq Target (Nm)','Tq Limit+ (Nm)'}, C);

    buildLapTable(tab, S, C, [10 350 760 180]);

    ax2 = buildPlotArea(tab, [10 130 760 210], 'Pack Power', C);
    plotOrMissing(ax2, S, {'P_pack'}, {'P pack (W)'}, C, true);

    axGPS = buildPlotArea(tab, [800 540 780 370], 'GPS Track (INS dead-reckoning)', C);
    plotGPS(axGPS, S, C);

    axGG = buildPlotArea(tab, [800 290 780 240], 'g-g Diagramm', C);
    plotGG(axGG, S, C);

    ax3 = buildPlotArea(tab, [800 80 780 200], 'SoC & Energie', C);
    plotOrMissing(ax3, S, {'ams_capacity_fl_can'}, {'SoC (%)'}, C);
end

% =========================================================
%% TAB 2 — BATTERY & AMS
% =========================================================
function buildTabBattery(tab, S, C)
    fn_V  = matlab2fieldname('ams_overall_voltage_can');
    fn_I  = matlab2fieldname('IVT_Result_I_can');
    fn_mn = matlab2fieldname('ams_cell_min_voltage_can');
    fn_mx = matlab2fieldname('ams_cell_max_voltage_can');
    fn_Tm = matlab2fieldname('ams_cell_max_temp_can');
    fn_soc= matlab2fieldname('ams_capacity_fl_can');

    kpis = {
        'Gesamtspannung', getLastVal(S, fn_V,  '--'), 'V';
        'SoC',            getLastVal(S, fn_soc,'--'), '%';
        'Strom (IVT)',    getLastVal(S, fn_I,   '--'), 'A';
        'V cell min',     getLastVal(S, fn_mn,  '--'), 'V';
        'V cell max',     getLastVal(S, fn_mx,  '--'), 'V';
        'T cell max',     getLastVal(S, fn_Tm,  '--'), '°C';
    };
    buildKPIRowCustom(tab, kpis, C, [10 840 1560 80]);

    ax1 = buildPlotArea(tab, [10 620 770 210], 'Spannung & Strom', C);
    plotOrMissing(ax1, S, {'ams_overall_voltage_can','IVT_Result_I_can'}, {'V pack (V)','I (A)'}, C);

    ax2 = buildPlotArea(tab, [10 400 770 210], 'Zelltemperaturen', C);
    plotOrMissing(ax2, S, {'ams_cell_max_temp_can','ams_cell_avg_temp_can','ams_cell_min_temp_can'}, ...
        {'T max','T avg','T min'}, C);

    ax3 = buildPlotArea(tab, [10 180 770 210], 'AIR Status', C);
    plotOrMissing(ax3, S, {'air_minus_closed_b_can','air_plus_closed_b_can','precharge_closed_b_can'}, ...
        {'AIR-','AIR+','Precharge'}, C);

    axHM = buildPlotArea(tab, [800 400 770 440], 'Zellspannungs-Heatmap (144 Zellen)', C);
    plotCellHeatmap(axHM, S, 'voltage', C);

    axHM2 = buildPlotArea(tab, [800 180 770 210], 'Zelltemperatur-Heatmap (48 Sensoren)', C);
    plotCellHeatmap(axHM2, S, 'temp', C);

    buildAMSErrors(tab, S, C, [10 80 1560 90]);
end

% =========================================================
%% TAB 3 — POWERTRAIN
% =========================================================
function buildTabPowertrain(tab, S, C)
    wheels = {'fl','fr','rl','rr'};
    labels = {'FL — Front Left','FR — Front Right','RL — Rear Left','RR — Rear Right'};
    xpos   = [10 400 800 1190];

    for i = 1:4
        buildInverterCard(tab, S, wheels{i}, labels{i}, C, [xpos(i) 730 375 175]);
    end

    ax1 = buildPlotArea(tab, [10 510 770 210], 'Drehzahl alle Achsen (rpm)', C);
    plotOrMissing(ax1, S, arrayfun(@(w) ['unitek_' w{1} '_speed_motor_ist_can'], wheels,'uni',0), ...
        {'FL','FR','RL','RR'}, C);

    ax2 = buildPlotArea(tab, [800 510 780 210], 'Drehmoment alle Achsen (Nm)', C);
    plotOrMissing(ax2, S, arrayfun(@(w) ['unitek_' w{1} '_torque_motor_ist_can'], wheels,'uni',0), ...
        {'FL','FR','RL','RR'}, C);

    ax3 = buildPlotArea(tab, [10 280 770 220], 'Torque Vectoring — tqv_result', C);
    plotOrMissing(ax3, S, {'tqv_result_fl_can','tqv_result_fr_can','tqv_result_rl_can','tqv_result_rr_can'}, ...
        {'FL','FR','RL','RR'}, C);

    ax4 = buildPlotArea(tab, [800 280 780 220], 'Derating Flags', C);
    plotOrMissing(ax4, S, {'drive_deratingMotorTemp_b_can','drive_deratingAccuTemp_b_can',...
        'drive_deratingInverterTemp_b_can','drive_deratingAccuSoc_b_can'}, ...
        {'MotorTemp','AccuTemp','InvTemp','AccuSoC'}, C);

    ax5 = buildPlotArea(tab, [10 60 770 210], 'Tq Limits & Target', C);
    plotOrMissing(ax5, S, {'tq_vehicle_pos_limit_can','tq_vehicle_neg_limit_can','drive_pwtrTqTarget_can'}, ...
        {'Limit+','Limit-','Target'}, C);

    buildWheelPowerSummary(tab, S, C, [800 60 780 210]);
end

% =========================================================
%% TAB 4 — VEHICLE DYNAMICS
% =========================================================
function buildTabDynamics(tab, S, C)
    kpis = {
        'V max',      getSignalMax(S, 'speed_can',          '--'), 'km/h';
        'a lat max',  getSignalMax(S, 'INS_acc_y_can',      '--'), 'g';
        'a long max', getSignalMax(S, 'INS_acc_x_can',      '--'), 'g';
        'Yaw max',    getSignalMax(S, 'INS_ang_vel_z_can',  '--'), '°/s';
    };
    buildKPIRowCustom(tab, kpis, C, [10 840 780 80]);

    ax1 = buildPlotArea(tab, [10 600 780 230], 'Geschwindigkeit & Lenkung', C);
    plotOrMissing(ax1, S, {'speed_can','steering_wheel_angle_can','DL_Yaw_rate_can'}, ...
        {'Speed (km/h)','Lenkwinkel (°)','Yaw rate (°/s)'}, C);

    ax2 = buildPlotArea(tab, [10 370 780 220], 'Bremsen & APPS', C);
    plotOrMissing(ax2, S, {'pbrake_front_can','pbrake_rear_can','apps_res_can','brake_balance_front_can'}, ...
        {'p front (bar)','p rear (bar)','APPS (%)','Balance front (%)'}, C);

    ax3 = buildPlotArea(tab, [10 140 780 220], 'Fahrwerk — Rocker', C);
    plotOrMissing(ax3, S, {'rocker_fl_can','rocker_fr_can','rocker_rl_can','rocker_rr_can'}, ...
        {'Rocker FL','Rocker FR','Rocker RL','Rocker RR'}, C);

    axGG = buildPlotArea(tab, [810 560 770 360], 'g-g Diagramm', C);
    plotGG(axGG, S, C);

    axGPS = buildPlotArea(tab, [810 300 770 250], 'GPS Track (INS dead-reckoning)', C);
    plotGPS(axGPS, S, C);

    ax4 = buildPlotArea(tab, [810 80 770 210], 'Beschleunigungen (g)', C);
    plotOrMissing(ax4, S, {'INS_acc_x_can','INS_acc_y_can','INS_acc_z_can'}, ...
        {'a long (g)','a lat (g)','a vert (g)'}, C);
end

% =========================================================
%% TAB 5 — EFFICIENCY
% =========================================================
function buildTabEfficiency(tab, S, C)
    e_total = '--'; e_regen = '--'; e_net = '--'; eta_avg = '--'; regen_pct = '--';
    if isfield(S,'E_total_ok') && S.E_total_ok
        e_total = sprintf('%.2f', S.E_total_kWh);
    end
    if isfield(S,'E_regen_ok') && S.E_regen_ok
        e_regen = sprintf('%.2f', S.E_regen_kWh);
    end
    if isfield(S,'E_total_ok') && S.E_total_ok && isfield(S,'E_regen_ok') && S.E_regen_ok
        e_net     = sprintf('%.2f', S.E_total_kWh - S.E_regen_kWh);
        regen_pct = sprintf('%.1f', S.E_regen_kWh / S.E_total_kWh * 100);
    end
    if isfield(S,'eta_powertrain_ok') && S.eta_powertrain_ok
        eta_avg = sprintf('%.1f', mean(S.eta_powertrain.Data(S.eta_powertrain.Data > 5)));
    end

    kpis = {
        'Energie gesamt', e_total,   'kWh';
        'Rekuperation',   e_regen,   'kWh';
        'Netto-Verbrauch',e_net,     'kWh';
        'Regen-Anteil',   regen_pct, '%';
        'Ø η Powertrain', eta_avg,   '%';
    };
    buildKPIRowCustom(tab, kpis, C, [10 840 1560 80]);

    ax1 = buildPlotArea(tab, [10 600 770 230], 'Powertrain Wirkungsgrad η (%)', C);
    plotOrMissing(ax1, S, {'eta_powertrain'}, {'η (Pack→Rad)'}, C, true);
    if isfield(S,'eta_powertrain_ok') && S.eta_powertrain_ok
        hold(ax1,'on');
        yline(ax1, mean(S.eta_powertrain.Data(S.eta_powertrain.Data>5)), '--', ...
            'Color', C.orange, 'LineWidth', 1.2, 'Label', 'Ø');
        hold(ax1,'off');
    end

    ax2 = buildPlotArea(tab, [800 600 770 230], 'Pack vs. Mech. Leistung (W)', C);
    plotOrMissing(ax2, S, {'P_pack','P_mech_total'}, {'P pack','P mech total'}, C, true);

    ax3 = buildPlotArea(tab, [10 370 770 220], 'Inverter Verlustleistung pro Achse (W)', C);
    plotOrMissing(ax3, S, {'P_loss_fl','P_loss_fr','P_loss_rl','P_loss_rr'}, ...
        {'P loss FL','P loss FR','P loss RL','P loss RR'}, C, true);

    ax4 = buildPlotArea(tab, [800 370 770 220], 'Mechanische Leistung pro Rad (W)', C);
    plotOrMissing(ax4, S, {'P_mech_fl','P_mech_fr','P_mech_rl','P_mech_rr'}, ...
        {'P mech FL','P mech FR','P mech RL','P mech RR'}, C, true);

    axLap = buildPlotArea(tab, [10 130 770 230], 'Energie pro Runde (kWh)', C);
    plotEnergyPerLap(axLap, S, C);

    ax5 = buildPlotArea(tab, [800 130 770 230], 'Rekuperation vs. Bremsleistung', C);
    plotRegenVsBrake(ax5, S, C);
end

% =========================================================
%% TAB 6 — TEMPERATUREN
% =========================================================
function buildTabTemperatures(tab, S, C)
    ax1 = buildPlotArea(tab, [10 680 770 220], 'Motor Temperaturen (°C)', C);
    plotOrMissing(ax1, S, {'unitek_fl_motor_temp_can','unitek_fr_motor_temp_can',...
        'unitek_rl_motor_temp_can','unitek_rr_motor_temp_can'}, ...
        {'T mot FL','T mot FR','T mot RL','T mot RR'}, C);

    ax2 = buildPlotArea(tab, [800 680 770 220], 'IGBT / Inverter Temperaturen (°C)', C);
    plotOrMissing(ax2, S, {'unitek_fl_igbt_temp_can','unitek_fr_igbt_temp_can',...
        'unitek_rl_igbt_temp_can','unitek_rr_igbt_temp_can'}, ...
        {'T IGBT FL','T IGBT FR','T IGBT RL','T IGBT RR'}, C);

    ax3 = buildPlotArea(tab, [10 460 770 210], 'Akku Zelltemperaturen (°C)', C);
    plotOrMissing(ax3, S, {'ams_cell_max_temp_can','ams_cell_avg_temp_can','ams_cell_min_temp_can'}, ...
        {'T max','T avg','T min'}, C);

    ax4 = buildPlotArea(tab, [800 460 770 210], 'Bremsscheiben & Rotoren (°C)', C);
    plotOrMissing(ax4, S, {'wpmd_brake_temp_fl_can','wpmd_brake_temp_fr_can',...
        'wpmd_rotor_temp_fl_can','wpmd_rotor_temp_fr_can'}, ...
        {'Brake FL','Brake FR','Rotor FL','Rotor FR'}, C);

    axHM = buildPlotArea(tab, [10 220 770 230], 'Zelltemperatur-Heatmap (48 Sensoren)', C);
    plotCellHeatmap(axHM, S, 'temp', C);

    ax5 = buildPlotArea(tab, [800 220 770 230], 'Getriebe & Transmission Temp (°C)', C);
    plotOrMissing(ax5, S, {'wpmd_trans_temp_fl_can','wpmd_trans_temp_fr_can'}, ...
        {'Trans FL','Trans FR'}, C);

    buildTempStatusRow(tab, S, C, [10 120 1560 90]);
end

% =========================================================
%% TAB 7 — SLIP & TC
% =========================================================
function buildTabSlipTC(tab, S, C)
    kpis = {
        'TC enabled',   getLastBool(S,'tqv_status_tc_enabled_b_can'),       '';
        'TQV enabled',  getLastBool(S,'tqv_status_tqv_enabled_b_can'),      '';
        'GPS Fix',      getLastBool(S,'tqv_status_gps_fix_aquired_b_can'),  '';
        'TQV Strength', getLastVal(S,matlab2fieldname('tqv_status_tqv_strength_can'),'--'),'';
        'µ Factor',     getLastVal(S,matlab2fieldname('tqv_status_tc_mu_factor_can'),'--'),'';
    };
    buildKPIRowCustom(tab, kpis, C, [10 840 1560 80]);

    ax1 = buildPlotArea(tab, [10 600 770 230], 'Slip Compare alle Räder', C);
    plotOrMissing(ax1, S, {'slip_compare_val_fl_can','slip_compare_val_fr_can',...
        'slip_compare_val_rl_can','slip_compare_val_rr_can'}, {'Slip FL','Slip FR','Slip RL','Slip RR'}, C);

    ax2 = buildPlotArea(tab, [800 600 770 230], 'TC Eingriff & Slip Target', C);
    plotOrMissing(ax2, S, {'tqv_status_tc_slip_target_can','tqv_status_tqv_strength_can',...
        'tqv_status_tqv_base_strength_can'}, {'Slip Target','TQV Strength','Base Strength'}, C);

    ax3 = buildPlotArea(tab, [10 370 770 220], 'Radgeschwindigkeiten (rpm)', C);
    plotOrMissing(ax3, S, {'tqv_rot_spd_fl_can','tqv_rot_spd_fr_can','tqv_rot_spd_rl_can','tqv_rot_spd_rr_can'}, ...
        {'FL','FR','RL','RR'}, C);

    ax4 = buildPlotArea(tab, [800 370 770 220], 'Tq Limits Front / Rear (Nm)', C);
    plotOrMissing(ax4, S, {'tqv_tqLimitPos_front_can','tqv_tqLimitNeg_front_can',...
        'tqv_tqLimitPos_rear_can','tqv_tqLimitNeg_rear_can'}, ...
        {'Lim+ Front','Lim- Front','Lim+ Rear','Lim- Rear'}, C);

    ax5 = buildPlotArea(tab, [10 140 770 220], 'TQV Torque Results (Nm)', C);
    plotOrMissing(ax5, S, {'tqv_result_fl_can','tqv_result_fr_can','tqv_result_rl_can','tqv_result_rr_can'}, ...
        {'TQV FL','TQV FR','TQV RL','TQV RR'}, C);

    ax6 = buildPlotArea(tab, [800 140 770 220], 'µ Faktor & TQV Strength über Zeit', C);
    plotOrMissing(ax6, S, {'tqv_status_tc_mu_factor_can','tqv_status_tqv_strength_can'}, ...
        {'µ factor','TQV strength'}, C);
end

% =========================================================
%% TAB 8 — PDU & POWER
% =========================================================
function buildTabPDU(tab, S, C)
    dcdc_names = {'12V_Gen','24V_Gen','DV','Ewp_Mot_1','Ewp_Mot_2','Fan_Inv','Fan_Motor'};
    xpos = [10 240 470 700 930 1160 1370];
    for i = 1:numel(dcdc_names)
        buildDCDCCard(tab, S, dcdc_names{i}, C, [xpos(i) 800 215 100]);
    end

    buildEFusePanel(tab, S, C, [10 590 770 200]);

    ax1 = buildPlotArea(tab, [800 590 770 200], 'Kühlung Duty Cycles (%)', C);
    plotOrMissing(ax1, S, {'ewpInverterDuty_can','ewpMotorDuty_can','fanInverterDuty_can','fanMotorDuty_can'}, ...
        {'EWP Inv','EWP Mot','Fan Inv','Fan Mot'}, C);

    ax2 = buildPlotArea(tab, [10 370 770 210], 'DCDC Ausgangsspannungen (V)', C);
    plotOrMissing(ax2, S, {'PDU_DCDC_12V_Gen_vout_can','PDU_DCDC_24V_Gen_vout_can','PDU_DCDC_DV_vout_can'}, ...
        {'12V Gen','24V Gen','DV'}, C);

    ax3 = buildPlotArea(tab, [800 370 770 210], 'eFuse Strom Monitor (A)', C);
    plotOrMissing(ax3, S, {'PDU_eFuse_ACE_IMON_can','PDU_eFuse_AMS_IMON_can',...
        'PDU_eFuse_DVSC_IMON_can','PDU_eFuse_SDC_IMON_can'}, {'ACE','AMS','DVSC','SDC'}, C);

    ax4 = buildPlotArea(tab, [10 150 770 210], 'Inverter eFuse Strom (A)', C);
    plotOrMissing(ax4, S, {'PDU_eFuse_Inv_FL_IMON_can','PDU_eFuse_Inv_FR_IMON_can',...
        'PDU_eFuse_Inv_RL_IMON_can','PDU_eFuse_Inv_RR_IMON_can'}, {'Inv FL','Inv FR','Inv RL','Inv RR'}, C);

    ax5 = buildPlotArea(tab, [800 150 770 210], 'SDC & Safety', C);
    plotOrMissing(ax5, S, {'SDC_AS_closed_b_can','SDC_Latch_Ready_b_can','imd_ok_b_can','ams_ok_b_can'}, ...
        {'SDC closed','Latch ready','IMD OK','AMS OK'}, C);
end

% =========================================================
%% TAB 9 — ALLE SIGNALE
% =========================================================
function [valLabels, sigInfo] = buildTabAllSignals(tab, S, C)
    TAB_W  = 1590;  TAB_H  = 855;
    N_COLS = 4;     RH     = 13;    SH  = 14;
    FS_SIG = 7.5;   FS_HDR = 7;

    colW = floor(TAB_W / N_COLS);
    valW = 70;
    nmW  = colW - valW - 18;

    entries  = buildFlatSignalList();
    nEntries = numel(entries);
    perCol   = ceil(nEntries / N_COLS);

    % Zeitstempel-Label oben
    lblTime = uilabel(tab, ...
        'Position',  [6 TAB_H-16 500 14], ...
        'Text',      '● letzter Wert  —  Snapshot-Zeit über Topbar setzen', ...
        'FontSize',  7.5, 'FontColor', [0.45 0.45 0.45], ...
        'BackgroundColor', 'none');

    valLabels = gobjects(0);
    sigInfo   = {};

    for ci = 1:N_COLS
        x0   = 2 + (ci-1)*colW;
        yTop = TAB_H - 20;

        idxFrom = (ci-1)*perCol + 1;
        idxTo   = min(ci*perCol, nEntries);

        for ei = idxFrom:idxTo
            e = entries{ei};

            % Sektions-Header
            if isstruct(e)
                yTop = yTop - SH;
                if yTop < 2; break; end
                uilabel(tab, ...
                    'Position',        [x0 yTop colW-3 SH-1], ...
                    'Text',            ['  ' upper(e.header)], ...
                    'FontSize',        FS_HDR, 'FontWeight', 'bold', ...
                    'FontColor',       C.orange, ...
                    'BackgroundColor', [0.11 0.09 0.06], ...
                    'Interpreter',     'none');
                continue;
            end

            % Signal-Zeile
            yTop = yTop - RH;
            if yTop < 2; break; end

            if iscell(e)
                fn    = e{1};  label = e{2};  ok_fn = e{3};
            else
                fn    = matlab2fieldname(e);
                ok_fn = [fn '_ok'];
                label = strrep(strrep(e,'_can',''),'_',' ');
                if numel(label) > 38; label = [label(1:36) '…']; end
            end

            [v, fc] = getSignalValAt(S, fn, ok_fn, []);

            uilabel(tab, 'Position', [x0+1 yTop 9 RH], ...
                'Text','●','FontSize',5.5,'FontColor',fc,'BackgroundColor','none');
            uilabel(tab, 'Position', [x0+10 yTop nmW RH], ...
                'Text', label, 'FontSize', FS_SIG, ...
                'FontColor', [0.82 0.82 0.82], 'BackgroundColor', 'none', ...
                'Interpreter', 'none');

            lh = uilabel(tab, ...
                'Position',           [x0+colW-valW-4 yTop valW RH], ...
                'Text',               v, ...
                'FontSize',           FS_SIG, 'FontWeight', 'bold', ...
                'FontColor',          fc, ...
                'BackgroundColor',    'none', ...
                'HorizontalAlignment','right', ...
                'Interpreter',        'none');

            valLabels(end+1) = lh;
            sigInfo{end+1}   = {fn, ok_fn};
        end
    end

    % Index 1 = Zeit-Label (Sondereintrag)
    valLabels = [lblTime; valLabels(:)];
    sigInfo   = [{'__time__',''}; sigInfo(:)];
end

% =========================================================
%% SIGNAL-WERT ZU ZEITPUNKT t_snap
% =========================================================
function [vStr, fc] = getSignalValAt(S, fn, ok_fn, t_snap)
    if isfield(S, ok_fn) && S.(ok_fn) && isfield(S, fn)
        try
            raw = S.(fn);
            if isa(raw,'timeseries') && ~isempty(raw.Data)
                if isempty(t_snap)
                    val = raw.Data(end);
                elseif t_snap <= raw.Time(1)
                    val = raw.Data(1);
                elseif t_snap >= raw.Time(end)
                    val = raw.Data(end);
                else
                    val = interp1(raw.Time, double(raw.Data), t_snap, 'linear');
                end
                vStr = snapVal(val);
            elseif isnumeric(raw) && isscalar(raw)
                vStr = snapVal(raw);
            else
                vStr = '?';
            end
            fc = [0.55 0.95 0.55];
        catch
            vStr = 'ERR';  fc = [1.0 0.6 0.0];
        end
    else
        vStr = '—';  fc = [0.32 0.32 0.32];
    end
end

% =========================================================
%% TAB-WERTE AKTUALISIEREN
% =========================================================
function updateAllSignalsTab(valLabels, sigInfo, S, t_snap, C)
    if ~isempty(valLabels) && isvalid(valLabels(1))
        valLabels(1).Text      = sprintf('● Snapshot  @  t = %.3f s', t_snap);
        valLabels(1).FontColor = C.orange;
    end
    for i = 2:numel(valLabels)
        if ~isvalid(valLabels(i)); continue; end
        fn    = sigInfo{i}{1};
        ok_fn = sigInfo{i}{2};
        [v, fc] = getSignalValAt(S, fn, ok_fn, t_snap);
        valLabels(i).Text      = v;
        valLabels(i).FontColor = fc;
    end
end

% =========================================================
%% FLACHE SIGNALLISTE
% =========================================================
function entries = buildFlatSignalList()
    e = {};

    e{end+1} = struct('header','Geschwindigkeit & Lenkung');
    e = [e, {'speed_can','steering_wheel_angle_can',...
             'steering_wheel_angle_e_b_can','INS_ang_vel_z_can','DL_Yaw_rate_can'}];

    e{end+1} = struct('header','APPS');
    e = [e, {'apps1_can','apps2_can','apps3_can','apps_res_can',...
             'apps_state_can','apps1_e_b_can','apps2_e_b_can','apps_bse_impl_b_can'}];

    e{end+1} = struct('header','Bremsen');
    e = [e, {'brake_pressed_b_can','pbrake_front_can','pbrake_rear_can',...
             'brake_balance_front_can','pbrake_front_e_b_can','pbrake_rear_e_b_can'}];

    e{end+1} = struct('header','Fahrwerk / Rocker');
    e = [e, {'rocker_fl_can','rocker_fr_can','rocker_rl_can','rocker_rr_can',...
             'rocker_fl_e_b_can','rocker_fr_e_b_can'}];

    e{end+1} = struct('header','INS / IMU');
    e = [e, {'INS_acc_x_can','INS_acc_y_can','INS_acc_z_can',...
             'INS_vel_x_can','INS_vel_y_can'}];

    e{end+1} = struct('header','Lap');
    e = [e, {'lap_cnt_can','laptime_can','lap_time_last_can',...
             'lap_time_best_can','lap_dist_can','lap_trigger_b_can'}];

    e{end+1} = struct('header','WPMD');
    e = [e, {'wpmd_brake_temp_fl_can','wpmd_brake_temp_fr_can',...
             'wpmd_rotor_temp_fl_can','wpmd_rotor_temp_fr_can',...
             'wpmd_trans_temp_fl_can','wpmd_trans_temp_fr_can',...
             'wpmd_brake_temp_e_b_fl_can','wpmd_brake_temp_e_b_fr_can'}];

    e{end+1} = struct('header','Batterie Überblick');
    e = [e, {'ams_overall_voltage_can','ams_capacity_fl_can',...
             'IVT_Result_I_can','IVT_Result_U2_Post_Airs_can',...
             'IVT_Result_U1_Pre_Airs_can','IVT_Result_W_can'}];

    e{end+1} = struct('header','Zelle min/max');
    e = [e, {'ams_cell_min_voltage_can','ams_cell_max_voltage_can',...
             'ams_cell_min_temp_can','ams_cell_avg_temp_can','ams_cell_max_temp_can'}];

    e{end+1} = struct('header','AMS Status');
    e = [e, {'ams_ok_b_can','ams_ok_pst_b_can','ams_cell_overvoltage_b_can',...
             'ams_cell_undervoltage_b_can','ams_cell_overtemp_b_can',...
             'ams_cell_undertemp_b_can','ams_com_error_can','ams_slave_fail_b_can',...
             'ams_balancing_active_b_can','ams_balance_fb_err_b_can','ams_fan_duty_can'}];

    e{end+1} = struct('header','AMS Occurences');
    e = [e, {'ams_overvoltage_occu_b_can','ams_undervoltage_occu_b_can',...
             'ams_overtemp_occu_b_can','ams_undertemp_occu_b_can',...
             'ams_overcurrent_occu_b_can','ams_ivtTimeout_occu_b_can'}];

    e{end+1} = struct('header','AIR & TS');
    e = [e, {'air_minus_closed_b_can','air_plus_closed_b_can',...
             'precharge_closed_b_can','ts_active_b_can','ts_state_can',...
             'ts_precharge_progress_can'}];

    e{end+1} = struct('header','IMD & TSAL');
    e = [e, {'imd_ok_b_can','imd_state_can','imd_insulation_can',...
             'tsal_state_can','tsal_hv_bat_b_can','tsal_error_b_can'}];

    for wheel = {'fl','fr','rl','rr'}
        w = wheel{1};
        e{end+1} = struct('header', upper(w));
        e{end+1} = ['unitek_' w '_speed_motor_ist_can'];
        e{end+1} = ['unitek_' w '_torque_motor_ist_can'];
        e{end+1} = ['unitek_' w '_torque_motor_soll_can'];
        e{end+1} = ['unitek_' w '_motor_temp_can'];
        e{end+1} = ['unitek_' w '_igbt_temp_can'];
        e{end+1} = ['unitek_' w '_Vdc_Bus_can'];
        e{end+1} = ['unitek_' w '_i_ist_can'];
        e{end+1} = ['unitek_' w '_rdy_b_can'];
        e{end+1} = ['unitek_' w '_run_b_can'];
        e{end+1} = ['unitek_' w '_motortemp_b_can'];
        e{end+1} = ['unitek_' w '_devicetemp_b_can'];
        e{end+1} = ['unitek_' w '_power_fault_b_can'];
    end

    e{end+1} = struct('header','Torque & Derating');
    e = [e, {'drive_pwtrTqTarget_can','tq_vehicle_pos_limit_can','tq_vehicle_neg_limit_can',...
             'drive_deratingMotorTemp_b_can','drive_deratingAccuTemp_b_can',...
             'drive_deratingInverterTemp_b_can','drive_deratingAccuSoc_b_can',...
             'drive_stratRecuActive_b_can','drive_powerLimitActive_b_can'}];

    e{end+1} = struct('header','TQV Status');
    e = [e, {'tqv_status_tc_enabled_b_can','tqv_status_tqv_enabled_b_can',...
             'tqv_status_gps_fix_aquired_b_can','tqv_status_tqv_strength_can',...
             'tqv_status_tc_mu_factor_can','tqv_status_tc_slip_target_can'}];

    e{end+1} = struct('header','TQV Ergebnisse');
    e = [e, {'tqv_result_fl_can','tqv_result_fr_can','tqv_result_rl_can','tqv_result_rr_can',...
             'tqv_tqLimitPos_front_can','tqv_tqLimitNeg_front_can',...
             'tqv_tqLimitPos_rear_can','tqv_tqLimitNeg_rear_can'}];

    e{end+1} = struct('header','Slip');
    e = [e, {'slip_compare_val_fl_can','slip_compare_val_fr_can',...
             'slip_compare_val_rl_can','slip_compare_val_rr_can'}];

    e{end+1} = struct('header','PDU DCDC');
    for dcdc = {'12V_Gen','24V_Gen','DV','Ewp_Mot_1','Fan_Inv','Fan_Motor'}
        d = dcdc{1};
        e{end+1} = ['PDU_DCDC_' d '_vout_can'];
        e{end+1} = ['PDU_DCDC_' d '_iout_can'];
        e{end+1} = ['PDU_DCDC_' d '_e_b_can'];
    end

    e{end+1} = struct('header','Kühlung');
    e = [e, {'ewpInverterDuty_can','ewpMotorDuty_can','fanInverterDuty_can','fanMotorDuty_can'}];

    e{end+1} = struct('header','eFuse (Auswahl)');
    for fuse = {'ACE','AMS','DVSC','Inv_FL','Inv_FR','Inv_RL','Inv_RR','SDC'}
        f = fuse{1};
        e{end+1} = ['PDU_eFuse_' f '_IMON_can'];
        e{end+1} = ['PDU_eFuse_' f '_e_b_can'];
    end

    e{end+1} = struct('header','Safety & SDC');
    e = [e, {'SDC_AS_closed_b_can','SDC_Latch_Ready_b_can','sdc_res_b_can',...
             'bspd_b_can','bots_b_can','bspd_avoid_b_can','ams_ok_b_can','imd_ok_b_can'}];

    e{end+1} = struct('header','Driverless');
    e = [e, {'DL_EBS_state_can','DL_AS_state_can','DL_speed_actual_can',...
             'DL_speed_target_can','DL_steering_angle_actual_can',...
             'DL_Motor_moment_actual_can','DL_Lap_counter_can',...
             'VCU_Statemachine_can','VCU_AMI_state_can','VCU_GO_b_can'}];

    e{end+1} = struct('header','Abgeleitet');
    e{end+1} = {'P_pack',        'P pack (W)',       'P_pack_ok'};
    e{end+1} = {'P_mech_total',  'P mech total (W)', 'P_mech_total_ok'};
    e{end+1} = {'P_mech_fl',     'P mech FL (W)',    'P_mech_fl_ok'};
    e{end+1} = {'P_mech_fr',     'P mech FR (W)',    'P_mech_fr_ok'};
    e{end+1} = {'P_mech_rl',     'P mech RL (W)',    'P_mech_rl_ok'};
    e{end+1} = {'P_mech_rr',     'P mech RR (W)',    'P_mech_rr_ok'};
    e{end+1} = {'eta_powertrain','η Powertrain (%)', 'eta_powertrain_ok'};
    e{end+1} = {'E_total_kWh',   'E total (kWh)',    'E_total_ok'};
    e{end+1} = {'E_regen_kWh',   'E regen (kWh)',    'E_regen_ok'};

    entries = e;
end

% =========================================================
%% snapVal helper
% =========================================================
function v = snapVal(val)
    if ~isfinite(val); v = 'NaN'; return; end
    a = abs(val);
    if     a == 0;    v = '0';
    elseif a >= 1e5;  v = sprintf('%.0f', val);
    elseif a >= 1000; v = sprintf('%.1f', val);
    elseif a >= 10;   v = sprintf('%.2f', val);
    elseif a >= 0.1;  v = sprintf('%.3f', val);
    else;             v = sprintf('%.2e', val);
    end
end

% =========================================================
%% PLOT HELPERS
% =========================================================
function ax = buildPlotArea(parent, pos, titleStr, C)
    pnl = uipanel(parent, 'Position', pos, ...
        'BackgroundColor', C.panel, 'BorderType', 'line', ...
        'BorderWidth', 1, 'HighlightColor', C.gray2);
    uilabel(pnl, 'Position', [0 pos(4)-52 pos(3) 18], ...
        'Text', titleStr, 'FontSize', 10, 'FontWeight', 'bold', ...
        'FontColor', C.red, 'BackgroundColor', 'none');
    ax = uiaxes(pnl, 'Position', [5 5 pos(3)-10 pos(4)-58]);
    styleAxes(ax, C);
end

function styleAxes(ax, C)
    ax.Color           = [0.13 0.13 0.13];
    ax.XColor          = C.gray;
    ax.YColor          = C.gray;
    ax.GridColor       = [0.25 0.25 0.25];
    ax.GridAlpha       = 0.5;
    ax.XGrid           = 'on';
    ax.YGrid           = 'on';
    ax.FontSize        = 9;
    ax.Box             = 'on';
    ax.BackgroundColor = [0.13 0.13 0.13];
end

function plotOrMissing(ax, S, signames, labels, C, isDerived)
    if nargin < 6; isDerived = false; end
    colors = {C.red, C.redlight, C.orange, C.green, [0.4 0.7 1], [0.9 0.9 0.4], C.gray};
    hold(ax, 'on');
    nPlotted = 0;
    missingLabels = {};

    for i = 1:numel(signames)
        sn  = signames{i};
        lbl = labels{i};
        fn  = ternStr(isDerived, sn, matlab2fieldname(sn));
        col = colors{mod(i-1, numel(colors))+1};

        if isfield(S, fn) && isfield(S, [fn '_ok']) && S.([fn '_ok'])
            try
                ts = S.(fn);
                if isa(ts, 'timeseries') && ~isempty(ts.Data)
                    dVec = double(ts.Data);
                    if size(dVec,2) > 1; dVec = dVec(:,1); end
                    plot(ax, ts.Time, dVec, 'Color', col, 'LineWidth', 1.2, 'DisplayName', lbl);
                    nPlotted = nPlotted + 1;
                elseif isnumeric(ts) && ~isempty(ts)
                    plot(ax, double(ts(:)), 'Color', col, 'LineWidth', 1.2, 'DisplayName', lbl);
                    nPlotted = nPlotted + 1;
                else
                    missingLabels{end+1} = lbl;
                end
            catch ME2
                missingLabels{end+1} = [lbl ' (ERR: ' ME2.message(1:min(40,end)) ')'];
            end
        else
            missingLabels{end+1} = lbl;
        end
    end

    if nPlotted > 0
        legend(ax, 'Location', 'best', 'TextColor', C.gray, ...
            'Color', [0.13 0.13 0.13], 'EdgeColor', C.gray2, 'FontSize', 8);
        xlabel(ax, 'Zeit (s)', 'Color', C.gray, 'FontSize', 8);
    end

    if ~isempty(missingLabels)
        ylims = ylim(ax); xlims = xlim(ax);
        if nPlotted == 0
            ax.Color = [0.11 0.11 0.11];
            text(ax, mean(xlims), mean(ylims), ...
                sprintf('KEINE DATEN\n%s', strjoin(missingLabels, '\n')), ...
                'Color', C.missing, 'FontSize', 9, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        else
            text(ax, xlims(1), ylims(1), sprintf('Keine Daten: %s', strjoin(missingLabels, ', ')), ...
                'Color', C.missing, 'FontSize', 8, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
        end
    end
    hold(ax, 'off');
end

function plotGPS(ax, S, C)
    if ~isfield(S,'gps_x_ok') || ~S.gps_x_ok
        markMissing(ax, 'GPS / INS Daten nicht verfügbar', C); return;
    end
    fn_spd = matlab2fieldname('speed_can');
    try
        if isfield(S,fn_spd) && S.([fn_spd '_ok'])
            spd_r = interp1(S.(fn_spd).Time, S.(fn_spd).Data, S.gps_t, 'linear', 'extrap');
            scatter(ax, S.gps_x, S.gps_y, 3, spd_r, 'filled');
            colormap(ax, 'hot');
            cb = colorbar(ax); cb.Color = C.gray; cb.Label.String = 'Speed (km/h)';
        else
            plot(ax, S.gps_x, S.gps_y, 'Color', C.red, 'LineWidth', 1.5);
        end
    catch
        plot(ax, S.gps_x, S.gps_y, 'Color', C.red, 'LineWidth', 1.5);
    end
    hold(ax,'on');
    plot(ax, S.gps_x(1), S.gps_y(1), 'o', 'Color', C.green, 'MarkerSize', 8, 'MarkerFaceColor', C.green);
    hold(ax,'off');
    axis(ax,'equal');
    xlabel(ax,'X (m)','Color',C.gray,'FontSize',8);
    ylabel(ax,'Y (m)','Color',C.gray,'FontSize',8);
end

function plotGG(ax, S, C)
    fn_ax = matlab2fieldname('INS_acc_x_can');
    fn_ay = matlab2fieldname('INS_acc_y_can');
    fn_sp = matlab2fieldname('speed_can');

    if ~isfield(S,fn_ax) || ~S.([fn_ax '_ok']) || ~isfield(S,fn_ay) || ~S.([fn_ay '_ok'])
        markMissing(ax, 'IMU Daten (INS_acc_x/y) nicht verfügbar', C); return;
    end

    ax_d = S.(fn_ax).Data / 9.81;
    ay_d = S.(fn_ay).Data / 9.81;
    t_ax = S.(fn_ax).Time;

    try
        if isfield(S,fn_sp) && S.([fn_sp '_ok'])
            spd = interp1(S.(fn_sp).Time, S.(fn_sp).Data, t_ax, 'linear','extrap');
            scatter(ax, ay_d, ax_d, 2, spd, 'filled', 'MarkerFaceAlpha', 0.6);
            colormap(ax, 'hot');
            cb = colorbar(ax); cb.Color = C.gray; cb.Label.String = 'Speed (km/h)';
        else
            scatter(ax, ay_d, ax_d, 2, C.red, 'filled', 'MarkerFaceAlpha', 0.5);
        end
    catch
        scatter(ax, ay_d, ax_d, 2, C.red, 'filled', 'MarkerFaceAlpha', 0.5);
    end

    hold(ax,'on');
    th = linspace(0,2*pi,100);
    for r = [1 2]
        plot(ax, r*cos(th), r*sin(th), '--', 'Color', C.gray2, 'LineWidth', 0.8);
    end
    xline(ax, 0, 'Color', C.gray2, 'LineWidth', 0.8);
    yline(ax, 0, 'Color', C.gray2, 'LineWidth', 0.8);
    hold(ax,'off');
    axis(ax,'equal');
    xlabel(ax,'a_y (g) — lateral','Color',C.gray,'FontSize',8);
    ylabel(ax,'a_x (g) — longitudinal','Color',C.gray,'FontSize',8);
    xlim(ax,[-3 3]); ylim(ax,[-3 3]);
end

function plotCellHeatmap(ax, S, mode, C)
    if strcmp(mode,'voltage')
        prefix = 'ams_cell_voltage'; nCells = 144; nRows = 12; nCols = 12;
        unit = 'V'; clim_range = [3.5 4.2];
    else
        prefix = 'ams_cell_temp'; nCells = 48; nRows = 6; nCols = 8;
        unit = '°C'; clim_range = [20 60];
    end

    data = nan(nRows, nCols); nFound = 0;
    for i = 1:nCells
        r  = floor((i-1)/nCols) + 1;
        c  = mod(i-1,nCols) + 1;
        fn = matlab2fieldname(sprintf('%s%03d_can', prefix, i));
        if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
            try
                ts = S.(fn);
                if isa(ts,'timeseries'); data(r,c) = mean(ts.Data,'omitnan');
                else; data(r,c) = mean(ts,'omitnan'); end
                nFound = nFound + 1;
            catch; end
        end
    end

    if nFound == 0; markMissing(ax, sprintf('Keine Zell-%s Daten', unit), C); return; end
    imagesc(ax, data); colormap(ax, 'hot'); clim(ax, clim_range);
    cb = colorbar(ax); cb.Color = C.gray; cb.Label.String = unit;
    axis(ax,'tight');
    xlabel(ax, sprintf('Spalte  (%d/%d Zellen)', nFound, nCells), 'Color', C.gray, 'FontSize', 8);
    ylabel(ax, 'Reihe', 'Color', C.gray, 'FontSize', 8);
end

function plotEnergyPerLap(ax, S, C)
    fn_lap = matlab2fieldname('lap_cnt_can');
    if ~isfield(S,'P_pack_ok') || ~S.P_pack_ok || ~isfield(S,fn_lap) || ~S.([fn_lap '_ok'])
        markMissing(ax, 'Lap counter oder Pack-Leistung nicht verfügbar', C); return;
    end
    try
        lap_ts = S.(fn_lap);
        P_ts   = resample(S.P_pack, lap_ts.Time);
        laps   = round(lap_ts.Data);
        ulaps  = unique(laps); ulaps = ulaps(ulaps > 0);
        E_per_lap = zeros(numel(ulaps),1);
        for i = 1:numel(ulaps)
            mask = laps == ulaps(i);
            dt   = mean(diff(lap_ts.Time));
            E_per_lap(i) = sum(P_ts.Data(mask)) * dt / 3.6e6;
        end
        bar(ax, ulaps, E_per_lap, 'FaceColor', C.red, 'EdgeColor', 'none');
        xlabel(ax,'Runde','Color',C.gray,'FontSize',8);
        ylabel(ax,'Energie (kWh)','Color',C.gray,'FontSize',8);
        hold(ax,'on');
        yline(ax, mean(E_per_lap), '--', 'Color', C.orange, 'LineWidth', 1.2);
        hold(ax,'off');
    catch ME
        markMissing(ax, sprintf('Fehler: %s', ME.message), C);
    end
end

function plotRegenVsBrake(ax, S, C)
    if ~isfield(S,'P_pack_ok') || ~S.P_pack_ok
        markMissing(ax, 'Pack-Leistung nicht verfügbar', C); return;
    end
    try
        t = S.P_pack.Time; P = S.P_pack.Data;
        plot(ax, t,  P.*(P>0)/1000, 'Color', C.red,   'LineWidth', 1.0, 'DisplayName', 'Antrieb (kW)');
        hold(ax,'on');
        plot(ax, t, -P.*(P<0)/1000, 'Color', C.green, 'LineWidth', 1.0, 'DisplayName', 'Rekuperation (kW)');
        hold(ax,'off');
        legend(ax,'Location','best','TextColor',C.gray,'Color',[0.13 0.13 0.13],...
            'EdgeColor',C.gray2,'FontSize',8);
        xlabel(ax,'Zeit (s)','Color',C.gray,'FontSize',8);
        ylabel(ax,'Leistung (kW)','Color',C.gray,'FontSize',8);
    catch ME
        markMissing(ax, sprintf('Fehler: %s', ME.message), C);
    end
end

% =========================================================
%% KPI & CARD HELPERS
% =========================================================
function buildKPIRow(parent, kpiData, C, pos)
    n = size(kpiData,1);
    w = floor(pos(3)/n) - 5;
    for i = 1:n
        buildKPICard(parent, kpiData{i,1}, kpiData{i,2}, kpiData{i,3}, C, ...
            [pos(1)+(i-1)*(w+5) pos(2) w pos(4)]);
    end
end

function buildKPIRowCustom(parent, kpis, C, pos)
    n = size(kpis,1);
    w = floor(pos(3)/n) - 5;
    for i = 1:n
        buildKPICard(parent, kpis{i,1}, kpis{i,2}, kpis{i,3}, C, ...
            [pos(1)+(i-1)*(w+5) pos(2) w pos(4)]);
    end
end

function buildKPICard(parent, label, value, unit, C, pos)
    pnl = uipanel(parent, 'Position', pos, 'BackgroundColor', C.card, 'BorderType','none');
    uilabel(pnl,'Position',[8 pos(4)-22 pos(3)-16 14],...
        'Text', upper(label), 'FontSize', 9, 'FontColor', C.gray, 'BackgroundColor','none');
    if isnumeric(value); valStr = sprintf('%.1f', value); else; valStr = char(value); end
    uilabel(pnl,'Position',[8 8 pos(3)-16 pos(4)-32],...
        'Text', [valStr ' ' unit], 'FontSize', 18, 'FontWeight','bold',...
        'FontColor', C.white, 'BackgroundColor','none', 'VerticalAlignment','top');
end

function buildInverterCard(parent, S, wheel, label, C, pos)
    pnl = uipanel(parent,'Position',pos,'BackgroundColor',C.card,...
        'BorderType','line','HighlightColor',C.red,'BorderWidth',1);
    uilabel(pnl,'Position',[8 pos(4)-22 pos(3)-16 16],...
        'Text',label,'FontSize',9,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');

    fields = {
        ['unitek_' wheel '_motor_temp_can'],      'T mot',  '°C';
        ['unitek_' wheel '_igbt_temp_can'],        'T IGBT', '°C';
        ['unitek_' wheel '_speed_motor_ist_can'],  'Speed',  'rpm';
        ['unitek_' wheel '_torque_motor_ist_can'], 'Tq ist', 'Nm';
        ['unitek_' wheel '_Vdc_Bus_can'],          'Vdc',    'V';
        ['unitek_' wheel '_i_ist_can'],            'I ist',  'A';
    };

    for i = 1:size(fields,1)
        fn = matlab2fieldname(fields{i,1});
        if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
            try
                ts = S.(fn);
                v  = ternStr(isa(ts,'timeseries'), ts.Data(end), ts(end));
                vstr = sprintf('%.1f %s', v, fields{i,3}); col = C.white;
            catch; vstr = '--'; col = C.missing; end
        else; vstr = 'N/A'; col = C.missing; end
        uilabel(pnl,'Position',[8 pos(4)-40-i*18 80 16],...
            'Text',fields{i,2},'FontSize',8,'FontColor',C.gray,'BackgroundColor','none');
        uilabel(pnl,'Position',[90 pos(4)-40-i*18 pos(3)-100 16],...
            'Text',vstr,'FontSize',8,'FontWeight','bold','FontColor',col,'BackgroundColor','none');
    end
end

function buildWheelPowerSummary(parent, S, C, pos)
    pnl = uipanel(parent,'Position',pos,'BackgroundColor',C.panel,'BorderType','none');
    uilabel(pnl,'Position',[0 pos(4)-20 pos(3) 16],'Text','Mittlere Radleistung',...
        'FontSize',10,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');
    wheels = {'fl','fr','rl','rr'}; vals = zeros(1,4); found = false;
    for i = 1:4
        if isfield(S,['P_mech_' wheels{i} '_ok']) && S.(['P_mech_' wheels{i} '_ok'])
            try; vals(i) = mean(abs(S.(['P_mech_' wheels{i}]).Data))/1000; found = true; catch; end
        end
    end
    ax = uiaxes(pnl,'Position',[5 5 pos(3)-10 pos(4)-28]);
    styleAxes(ax, C);
    if found
        b = bar(ax, vals, 'FaceColor','flat'); b.CData = repmat(C.red,4,1);
        set(ax,'XTickLabel',{'FL','FR','RL','RR'},'XTick',1:4);
        ylabel(ax,'Ø Leistung (kW)','Color',C.gray,'FontSize',8);
    else
        markMissing(ax, 'Mech. Leistung nicht verfügbar', C);
    end
end

function buildStatusBadges(parent, S, C, pos)
    checks = {'ams_ok_b_can','AMS OK'; 'imd_ok_b_can','IMD OK';
              'SDC_AS_closed_b_can','SDC closed'; 'DL_EBS_state_can','EBS'};
    xp = pos(1);
    for i = 1:size(checks,1)
        fn  = matlab2fieldname(checks{i,1});
        lbl = checks{i,2};
        if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
            try; ts = S.(fn);
                v  = ternStr(isa(ts,'timeseries'), ts.Data(end), ts(end));
                ok = v >= 1;
            catch; ok = false; end
            bgc = C.green * 0.25; fc = C.green;
        else; ok = false; bgc = [0.2 0.1 0.1]; fc = C.missing; lbl = [lbl ' (N/A)']; end
        p2 = uipanel(parent,'Position',[xp pos(2) 130 30],'BackgroundColor',bgc,'BorderType','none');
        uilabel(p2,'Position',[5 5 120 20],'Text',lbl,...
            'FontSize',9,'FontWeight','bold','FontColor',fc,'BackgroundColor','none');
        xp = xp + 140;
    end
end

function buildLapTable(parent, S, C, pos)
    fn_lap = matlab2fieldname('lap_cnt_can');
    fn_t   = matlab2fieldname('laptime_can');
    pnl = uipanel(parent,'Position',pos,'BackgroundColor',C.panel,'BorderType','none');
    uilabel(pnl,'Position',[0 pos(4)-20 pos(3) 16],'Text','Lap Übersicht',...
        'FontSize',10,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');
    if ~isfield(S,fn_lap) || ~S.([fn_lap '_ok'])
        uilabel(pnl,'Position',[10 pos(4)/2-10 pos(3)-20 20],...
            'Text','Keine Lap-Daten verfügbar','FontSize',10,...
            'FontColor',C.missing,'BackgroundColor','none','HorizontalAlignment','center');
        return;
    end
    try
        lap_ts = S.(fn_lap); laps = round(lap_ts.Data);
        ulaps  = unique(laps); ulaps = ulaps(ulaps > 0);
        nLaps  = min(numel(ulaps), 8);
        colW   = floor((pos(3)-10)/5);
        headers = {'Lap','Zeit (s)','V avg','SoC','Status'};
        for h = 1:5
            uilabel(pnl,'Position',[5+(h-1)*colW pos(4)-38 colW-2 16],...
                'Text',headers{h},'FontSize',8,'FontWeight','bold',...
                'FontColor',C.red,'BackgroundColor','none');
        end
        fn_spd = matlab2fieldname('speed_can');
        fn_soc = matlab2fieldname('ams_capacity_fl_can');
        for i = 1:nLaps
            yp = pos(4)-42-(i*22); if yp < 5; break; end
            mask = laps == ulaps(i);
            bgc  = ternStr(mod(i,2)==0, C.panel, C.card);
            bk   = uipanel(pnl,'Position',[0 yp pos(3) 20],'BackgroundColor',bgc,'BorderType','none');
            uilabel(bk,'Position',[5 2 colW-2 16],'Text',num2str(ulaps(i)),...
                'FontSize',8,'FontColor',C.white,'BackgroundColor','none');
            t_str = '--';
            if isfield(S,fn_t) && S.([fn_t '_ok'])
                try; lt = S.(fn_t).Data(mask); if ~isempty(lt); t_str = sprintf('%.1f',max(lt)); end; catch; end
            end
            uilabel(bk,'Position',[5+colW 2 colW-2 16],'Text',t_str,...
                'FontSize',8,'FontColor',C.white,'BackgroundColor','none');
            spd_str = '--';
            if isfield(S,fn_spd) && S.([fn_spd '_ok'])
                try; sp = interp1(S.(fn_spd).Time,S.(fn_spd).Data,lap_ts.Time(mask),'linear','extrap');
                    spd_str = sprintf('%.0f km/h',mean(sp,'omitnan')); catch; end
            end
            uilabel(bk,'Position',[5+2*colW 2 colW-2 16],'Text',spd_str,...
                'FontSize',8,'FontColor',C.gray,'BackgroundColor','none');
            soc_str = '--';
            if isfield(S,fn_soc) && S.([fn_soc '_ok'])
                try; sc = interp1(S.(fn_soc).Time,S.(fn_soc).Data,lap_ts.Time(mask),'linear','extrap');
                    soc_str = sprintf('%.0f%%',sc(end)); catch; end
            end
            uilabel(bk,'Position',[5+3*colW 2 colW-2 16],'Text',soc_str,...
                'FontSize',8,'FontColor',C.orange,'BackgroundColor','none');
            uilabel(bk,'Position',[5+4*colW 2 colW-2 16],'Text','OK',...
                'FontSize',8,'FontColor',C.green,'BackgroundColor','none');
        end
    catch ME
        uilabel(pnl,'Position',[10 10 pos(3)-20 20],...
            'Text',sprintf('Fehler: %s',ME.message),'FontSize',8,...
            'FontColor',C.missing,'BackgroundColor','none');
    end
end

function buildAMSErrors(parent, S, C, pos)
    checks = {
        'ams_cell_overvoltage_b_can', 'Overvoltage';
        'ams_cell_undervoltage_b_can','Undervoltage';
        'ams_cell_overtemp_b_can',    'Overtemp';
        'ams_cell_undertemp_b_can',   'Undertemp';
        'ams_com_error_can',          'COM Error';
        'ams_slave_fail_b_can',       'Slave Fail';
        'ams_ok_b_can',               'AMS OK';
    };
    pnl = uipanel(parent,'Position',pos,'BackgroundColor',C.panel,'BorderType','none');
    uilabel(pnl,'Position',[0 pos(4)-18 200 16],'Text','AMS Fehler & Status',...
        'FontSize',10,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');
    xp = 5;
    for i = 1:size(checks,1)
        fn  = matlab2fieldname(checks{i,1});
        lbl = checks{i,2};
        if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
            try
                v = max(S.(fn).Data);
                if strcmp(lbl,'AMS OK')
                    ok = v>=1; bgc = ok*[0.1 0.3 0.1]+(~ok)*[0.3 0.1 0.1]; fc = ok*C.green+(~ok)*C.red;
                else
                    ok = v<0.5; bgc = ok*[0.1 0.3 0.1]+(~ok)*[0.3 0.1 0.1]; fc = ok*C.green+(~ok)*C.red;
                    if ~ok; lbl = [lbl ' !']; end
                end
            catch; bgc=[0.2 0.15 0.1]; fc=C.missing; lbl=[lbl ' (N/A)']; end
        else; bgc=[0.15 0.15 0.15]; fc=C.missing; lbl=[lbl ' (N/A)']; end
        p2 = uipanel(pnl,'Position',[xp 5 140 35],'BackgroundColor',bgc,'BorderType','none');
        uilabel(p2,'Position',[5 8 130 20],'Text',lbl,...
            'FontSize',9,'FontWeight','bold','FontColor',fc,'BackgroundColor','none');
        xp = xp + 148;
    end
end

function buildTempStatusRow(parent, S, C, pos)
    checks = {
        'unitek_fl_motor_temp_can','T mot FL', 80,100;
        'unitek_fr_motor_temp_can','T mot FR', 80,100;
        'unitek_rl_motor_temp_can','T mot RL', 80,100;
        'unitek_rr_motor_temp_can','T mot RR', 80,100;
        'unitek_fl_igbt_temp_can', 'T IGBT FL',70, 90;
        'unitek_fr_igbt_temp_can', 'T IGBT FR',70, 90;
        'ams_cell_max_temp_can',   'T bat max',45, 60;
        'wpmd_brake_temp_fl_can',  'T brake FL',200,400;
    };
    pnl = uipanel(parent,'Position',pos,'BackgroundColor',C.panel,'BorderType','none');
    uilabel(pnl,'Position',[0 pos(4)-18 300 16],'Text','Temperatur Status — Spitzenwerte',...
        'FontSize',10,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');
    xp = 5;
    for i = 1:size(checks,1)
        fn = matlab2fieldname(checks{i,1}); lbl = checks{i,2};
        warn = checks{i,3}; crit = checks{i,4};
        if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
            try
                vmax = max(S.(fn).Data); valStr = sprintf('%.0f°C',vmax);
                if vmax>=crit; fc=C.red; bgc=[0.3 0.05 0.05];
                elseif vmax>=warn; fc=C.orange; bgc=[0.25 0.15 0.0];
                else; fc=C.green; bgc=[0.05 0.2 0.05]; end
            catch; valStr='ERR'; fc=C.missing; bgc=[0.15 0.15 0.15]; end
        else; valStr='N/A'; fc=C.missing; bgc=[0.15 0.15 0.15]; end
        p2 = uipanel(pnl,'Position',[xp 5 175 35],'BackgroundColor',bgc,'BorderType','none');
        uilabel(p2,'Position',[5 18 100 14],'Text',lbl,'FontSize',8,'FontColor',C.gray,'BackgroundColor','none');
        uilabel(p2,'Position',[5 3 100 16],'Text',valStr,'FontSize',11,'FontWeight','bold',...
            'FontColor',fc,'BackgroundColor','none');
        xp = xp + 182;
    end
end

function buildDCDCCard(parent, S, name, C, pos)
    fn_v = matlab2fieldname(['PDU_DCDC_' name '_vout_can']);
    fn_i = matlab2fieldname(['PDU_DCDC_' name '_iout_can']);
    fn_t = matlab2fieldname(['PDU_DCDC_' name '_temp_can']);
    fn_e = matlab2fieldname(['PDU_DCDC_' name '_e_b_can']);
    pnl  = uipanel(parent,'Position',pos,'BackgroundColor',C.card,...
        'BorderType','line','HighlightColor',C.gray2);
    uilabel(pnl,'Position',[5 pos(4)-18 pos(3)-10 16],...
        'Text',strrep(name,'_',' '),'FontSize',8,'FontWeight','bold',...
        'FontColor',C.red,'BackgroundColor','none');
    pairs = {fn_v,'V'; fn_i,'A'; fn_t,'°C'};
    for j = 1:3
        fn = pairs{j,1}; unit = pairs{j,2};
        if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
            try; v = S.(fn).Data(end); vstr = sprintf('%.1f%s',v,unit); catch; vstr=['--' unit]; end
            fc = C.white;
        else; vstr=['N/A ' unit]; fc=C.missing; end
        uilabel(pnl,'Position',[5 pos(4)-35-j*16 pos(3)-10 14],...
            'Text',vstr,'FontSize',8,'FontColor',fc,'BackgroundColor','none');
    end
    hasErr = false;
    if isfield(S,fn_e) && isfield(S,[fn_e '_ok']) && S.([fn_e '_ok'])
        try; hasErr = max(S.(fn_e).Data) > 0.5; catch; end
    end
    fc2 = hasErr*C.red + (~hasErr)*C.green;
    uilabel(pnl,'Position',[5 5 pos(3)-10 14],'Text',ternStr(hasErr,'FEHLER','OK'),...
        'FontSize',8,'FontWeight','bold','FontColor',fc2,'BackgroundColor','none');
end

function buildEFusePanel(parent, S, C, pos)
    pnl   = uipanel(parent,'Position',pos,'BackgroundColor',C.panel,'BorderType','none');
    uilabel(pnl,'Position',[0 pos(4)-18 200 16],'Text','eFuse Monitor',...
        'FontSize',10,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');
    fuses = {'ACE','AMS','AMS_Fans','DVSC','Ewp_Inv','Inv_FL','Inv_FR','Inv_RL','Inv_RR','SDC','12V_Gen'};
    colW  = floor((pos(3)-10)/4);
    
    for h = 1:4
        uilabel(pnl,'Position',[5+(h-1)*colW pos(4)-36 colW-2 16],'Text',{'eFuse','I mon (A)','Error','Occurrence'}{h},'FontSize',8,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');
    end

    nShow = min(numel(fuses), floor((pos(4)-45)/20));
    for i = 1:nShow
        yp   = pos(4)-40-i*20;
        fn_I = matlab2fieldname(['PDU_eFuse_' fuses{i} '_IMON_can']);
        fn_e = matlab2fieldname(['PDU_eFuse_' fuses{i} '_e_b_can']);
        bgc  = ternStr(mod(i,2)==0, C.card, C.panel);
        bk   = uipanel(pnl,'Position',[0 yp pos(3) 19],'BackgroundColor',bgc,'BorderType','none');
        uilabel(bk,'Position',[5 2 colW-2 15],'Text',strrep(fuses{i},'_',' '),...
            'FontSize',8,'FontColor',C.white,'BackgroundColor','none');
        if isfield(S,fn_I) && isfield(S,[fn_I '_ok']) && S.([fn_I '_ok'])
            try; v=mean(S.(fn_I).Data,'omitnan'); istr=sprintf('%.2f',v); fc=C.white;
            catch; istr='--'; fc=C.missing; end
        else; istr='N/A'; fc=C.missing; end
        uilabel(bk,'Position',[5+colW 2 colW-2 15],'Text',istr,'FontSize',8,'FontColor',fc,'BackgroundColor','none');
        hasErr=false; occ=0;
        if isfield(S,fn_e) && isfield(S,[fn_e '_ok']) && S.([fn_e '_ok'])
            try; ed=S.(fn_e).Data; hasErr=max(ed)>0.5; occ=sum(diff(ed>0.5)>0); catch; end
            estr=ternStr(hasErr,'JA','nein'); efc=hasErr*C.red+(~hasErr)*C.green;
        else; estr='N/A'; efc=C.missing; end
        uilabel(bk,'Position',[5+2*colW 2 colW-2 15],'Text',estr,'FontSize',8,...
            'FontWeight','bold','FontColor',efc,'BackgroundColor','none');
        uilabel(bk,'Position',[5+3*colW 2 colW-2 15],'Text',num2str(occ),...
            'FontSize',8,'FontColor',C.gray,'BackgroundColor','none');
    end
end

% =========================================================
%% UTILITY
% =========================================================
function kpiData = computeKPIs(S)
    fn_soc = matlab2fieldname('ams_capacity_fl_can');
    kpiData = {
        'V max',     getSignalMax(S, 'speed_can',              '--'), 'km/h';
        'SoC',       getLastVal(  S, fn_soc,                   '--'), '%';
        'Verbrauch', getFieldStr( S, 'E_total_kWh','E_total_ok','--'), 'kWh';
        'T mot max', getSignalMax(S, 'unitek_rl_motor_temp_can','--'), '°C';
        'T bat max', getSignalMax(S, 'ams_cell_max_temp_can',   '--'), '°C';
        'η Ø',       getFieldStr( S, 'eta_powertrain','eta_powertrain_ok','--','mean_data'), '%';
    };
end

function v = getLastVal(S, fn, def)
    if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
        try; ts=S.(fn); v=sprintf('%.2f', ternStr(isa(ts,'timeseries'),ts.Data(end),ts(end)));
        catch; v=def; end
    else; v=def; end
end

function v = getSignalMax(S, signame, def)
    fn = matlab2fieldname(signame);
    if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
        try; ts=S.(fn); v=sprintf('%.1f', ternStr(isa(ts,'timeseries'),max(ts.Data),max(ts)));
        catch; v=def; end
    else; v=def; end
end

function v = getFieldStr(S, fval, fok, def, mode)
    if nargin < 5; mode = 'val'; end
    if isfield(S,fok) && S.(fok)
        try
            raw = S.(fval);
            if strcmp(mode,'mean_data') && isa(raw,'timeseries')
                d = raw.Data(raw.Data > 5); v = sprintf('%.1f', mean(d,'omitnan'));
            elseif strcmp(mode,'mean_data') && isnumeric(raw)
                v = sprintf('%.1f', raw);
            else
                v = sprintf('%.2f', ternStr(isa(raw,'timeseries'), raw.Data(end), raw));
            end
        catch; v=def; end
    else; v=def; end
end

function v = getLastBool(S, signame)
    fn = matlab2fieldname(signame);
    if isfield(S,fn) && isfield(S,[fn '_ok']) && S.([fn '_ok'])
        try; ts=S.(fn); bv=ternStr(isa(ts,'timeseries'),ts.Data(end),ts(end))>=1;
            v=ternStr(bv,'JA','NEIN');
        catch; v='ERR'; end
    else; v='N/A'; end
end

function markMissing(ax, msg, C)
    ax.Color = [0.11 0.11 0.11]; xlim(ax,[0 1]); ylim(ax,[0 1]);
    text(ax,0.5,0.55,'KEINE DATEN','Color',C.missing,'FontSize',11,'FontWeight','bold',...
        'HorizontalAlignment','center','VerticalAlignment','middle');
    text(ax,0.5,0.38,msg,'Color',[0.45 0.45 0.45],'FontSize',8,...
        'HorizontalAlignment','center','VerticalAlignment','middle');
    ax.XTick=[]; ax.YTick=[];
end

% =========================================================
%% EXPORT
% =========================================================
function exportReport(S, meta)
    [fname, fpath] = uiputfile({'*.pdf','PDF Report';'*.png','PNG Screenshot'},...
        'Report speichern', sprintf('Report_%s_%s', meta.vehicle, strrep(meta.date,'-','')));
    if isequal(fname,0); return; end
    [~,~,ext] = fileparts(fname);
    outpath = fullfile(fpath, fname);
    figs = findall(groot,'Type','figure');
    if ~isempty(figs)
        if strcmpi(ext,'.pdf')
            exportgraphics(figs(1), outpath, 'ContentType','vector','Resolution',150);
        else
            exportgraphics(figs(1), outpath, 'Resolution',200);
        end
        fprintf('Export: %s\n', outpath);
    end
    msgbox(sprintf('Export abgeschlossen:\n%s', outpath),'Export OK');
end

% =========================================================
%% SNAPSHOT WINDOW
% =========================================================
function buildSnapshotWindow(S, t_snap, C)
    fig2 = uifigure('Name', sprintf('Snapshot  @  t = %.3f s', t_snap), ...
        'Position', [150 80 820 820], 'Color', C.bg);

    uilabel(fig2,'Position',[14 775 790 34],...
        'Text', sprintf('Signalzustand  @  t = %.3f s', t_snap),...
        'FontSize',15,'FontWeight','bold','FontColor',C.red,'BackgroundColor','none');

    uilabel(fig2,'Position',[14 742 45 20],'Text','Filter:','FontSize',9,...
        'FontColor',C.gray,'BackgroundColor','none');
    efFilter = uieditfield(fig2,'text','Position',[62 740 430 24],...
        'FontSize',9,'BackgroundColor',C.card,'FontColor',C.white,...
        'Placeholder','Signalname filtern...');
    lblCount = uilabel(fig2,'Position',[504 742 300 22],'Text','...',...
        'FontSize',9,'FontColor',C.gray,'BackgroundColor','none','HorizontalAlignment','right');

    allNames = {}; allVals = {};
    fields = fieldnames(S);
    for i = 1:numel(fields)
        fn = fields{i};
        if endsWith(fn,'_ok'); continue; end
        if any(strcmp(fn,{'t_base','t_base_ok','gps_x','gps_y','gps_t','E_total_kWh','E_regen_kWh'})); continue; end
        ok_fn = [fn '_ok'];
        if ~isfield(S,ok_fn) && isnumeric(S.(fn)) && isscalar(S.(fn))
            allNames{end+1} = fn; allVals{end+1} = sprintf('%.5g  [konstant]',S.(fn)); continue;
        end
        if ~isfield(S,ok_fn) || ~S.(ok_fn); continue; end
        ts = S.(fn);
        if ~isa(ts,'timeseries') || isempty(ts.Data); continue; end
        try
            tVec = ts.Time; dVec = double(ts.Data);
            if size(dVec,2)>1; dVec=dVec(:,1); end
            if     t_snap <= tVec(1);   val = dVec(1);
            elseif t_snap >= tVec(end); val = dVec(end);
            else;  val = interp1(tVec, dVec, t_snap, 'linear'); end
            sigLabel = ts.Name; if isempty(sigLabel); sigLabel=fn; end
            allNames{end+1} = sigLabel; allVals{end+1} = sprintf('%.5g',val);
        catch; end
    end

    if ~isempty(allNames)
        [allNames, idx] = sort(allNames); allVals = allVals(idx);
    end
    nSigs = numel(allNames);
    lblCount.Text = sprintf('%d Signale gefunden', nSigs);

    if nSigs == 0
        uilabel(fig2,'Position',[14 380 790 30],...
            'Text','Keine Signaldaten verfügbar.','FontSize',12,...
            'FontColor',C.missing,'BackgroundColor','none','HorizontalAlignment','center');
        return;
    end

    uit = uitable(fig2,'Position',[14 14 790 718],...
        'Data',[allNames(:), allVals(:)],...
        'ColumnName',{'Signal', sprintf('Wert  @  t = %.3f s', t_snap)},...
        'ColumnWidth',{460,250},'FontSize',10,'RowName',{},...
        'BackgroundColor',[C.card; C.panel],'ForegroundColor',C.white);

    efFilter.ValueChangedFcn = @(src,~) ...
        filterSnapshotTable(uit, allNames, allVals, src.Value, lblCount, nSigs);
end

function filterSnapshotTable(uit, allNames, allVals, filterStr, lblCount, nTotal)
    fs = strtrim(filterStr);
    if isempty(fs); mask = true(numel(allNames),1);
    else; mask = contains(lower(allNames(:)), lower(fs)); end
    uit.Data = [allNames(mask)', allVals(mask)'];
    lblCount.Text = sprintf('%d / %d Signale', sum(mask), nTotal);
end

% =========================================================
%% SIGNAL LIST
% =========================================================
function signals = getSignalList()
    signals = {
        'speed_can','steering_wheel_angle_can','steering_wheel_angle_e_b_can',...
        'brake_pressed_b_can','brake_balance_front_can',...
        'pbrake_front_can','pbrake_rear_can','pbrake_front_e_b_can','pbrake_rear_e_b_can',...
        'pbrake_front_raw_can','pbrake_rear_raw_can',...
        'apps1_can','apps2_can','apps3_can','apps_res_can','apps_state_can',...
        'apps1_e_b_can','apps2_e_b_can','apps3_e_b_can','apps_bse_impl_b_can',...
        'rocker_fl_can','rocker_fr_can','rocker_rl_can','rocker_rr_can',...
        'rocker_fl_e_b_can','rocker_fr_e_b_can','rocker_rl_e_b_can','rocker_rr_e_b_can',...
        'INS_acc_x_can','INS_acc_y_can','INS_acc_z_can',...
        'INS_ang_vel_z_can','INS_vel_x_can','INS_vel_y_can',...
        'ams_overall_voltage_can','ams_capacity_fl_can',...
        'ams_cell_min_voltage_can','ams_cell_max_voltage_can',...
        'ams_cell_avg_temp_can','ams_cell_min_temp_can','ams_cell_max_temp_can',...
        'ams_cell_overvoltage_b_can','ams_cell_undervoltage_b_can',...
        'ams_cell_overtemp_b_can','ams_cell_undertemp_b_can',...
        'ams_ok_b_can','ams_ok_pst_b_can','ams_slave_fail_b_can',...
        'ams_com_error_can','ams_com_error_occu_b_can',...
        'ams_balance_fb_err_b_can','ams_balancing_active_b_can',...
        'ams_fan_duty_can','ams_pecErrors_can',...
        'ams_overvoltage_occu_b_can','ams_undervoltage_occu_b_can',...
        'ams_overtemp_occu_b_can','ams_undertemp_occu_b_can',...
        'ams_overcurrent_occu_b_can','ams_ivtTimeout_occu_b_can',...
        'IVT_Result_I_can','IVT_Result_U1_Pre_Airs_can','IVT_Result_U2_Post_Airs_can',...
        'IVT_Result_U3_can','IVT_Result_W_can',...
        'IVT_Result_I_Channel_Error_b_can','IVT_Result_As_Channel_Err_b_can',...
        'IVT_Result_System_Error_b_can','IVT_Result_OCS_b_can',...
        'IVT_Result_Measurement_Err_b_can',...
        'air_minus_closed_b_can','air_plus_closed_b_can',...
        'air_minus_aux_b_can','air_plus_aux_b_can',...
        'precharge_closed_b_can','precharge_aux_b_can',...
        'imd_ok_b_can','imd_ok_pst_b_can','imd_state_can','imd_insulation_can',...
        'tsal_state_can','tsal_hv_bat_b_can','tsal_error_b_can',...
        'ts_active_b_can','ts_activate_b_can','ts_state_can','ts_precharge_progress_can',...
        'unitek_fl_speed_motor_ist_can','unitek_fl_torque_motor_ist_can',...
        'unitek_fl_torque_motor_soll_can','unitek_fl_motor_temp_can',...
        'unitek_fl_igbt_temp_can','unitek_fl_Vdc_Bus_can','unitek_fl_i_ist_can',...
        'unitek_fl_status_can','unitek_fl_rdy_b_can','unitek_fl_rfe_b_can',...
        'unitek_fl_run_b_can','unitek_fl_go_b_can','unitek_fl_feedback_b_can',...
        'unitek_fl_overvoltage_b_can','unitek_fl_motortemp_b_can','unitek_fl_motortemp_w_b_can',...
        'unitek_fl_devicetemp_b_can','unitek_fl_devicetemp_w_b_can',...
        'unitek_fl_power_fault_b_can','unitek_fl_rfe_fault_b_can',...
        'unitek_fl_i_peak_b_can','unitek_fl_i_lim_inuse_ramp_can',...
        'unitek_fr_speed_motor_ist_can','unitek_fr_torque_motor_ist_can',...
        'unitek_fr_torque_motor_soll_can','unitek_fr_motor_temp_can',...
        'unitek_fr_igbt_temp_can','unitek_fr_Vdc_Bus_can','unitek_fr_i_ist_can',...
        'unitek_fr_status_can','unitek_fr_rdy_b_can','unitek_fr_rfe_b_can',...
        'unitek_fr_run_b_can','unitek_fr_go_b_can','unitek_fr_feedback_b_can',...
        'unitek_fr_overvoltage_b_can','unitek_fr_motortemp_b_can','unitek_fr_motortemp_w_b_can',...
        'unitek_fr_devicetemp_b_can','unitek_fr_power_fault_b_can','unitek_fr_rfe_fault_b_can',...
        'unitek_rl_speed_motor_ist_can','unitek_rl_torque_motor_ist_can',...
        'unitek_rl_torque_motor_soll_can','unitek_rl_motor_temp_can',...
        'unitek_rl_igbt_temp_can','unitek_rl_Vdc_Bus_can','unitek_rl_i_ist_can',...
        'unitek_rl_status_can','unitek_rl_rdy_b_can','unitek_rl_rfe_b_can',...
        'unitek_rl_run_b_can','unitek_rl_go_b_can','unitek_rl_feedback_b_can',...
        'unitek_rl_overvoltage_b_can','unitek_rl_motortemp_b_can','unitek_rl_motortemp_w_b_can',...
        'unitek_rl_devicetemp_b_can','unitek_rl_power_fault_b_can','unitek_rl_rfe_fault_b_can',...
        'unitek_rr_speed_motor_ist_can','unitek_rr_torque_motor_ist_can',...
        'unitek_rr_torque_motor_soll_can','unitek_rr_motor_temp_can',...
        'unitek_rr_igbt_temp_can','unitek_rr_Vdc_Bus_can','unitek_rr_i_ist_can',...
        'unitek_rr_status_can','unitek_rr_rdy_b_can','unitek_rr_rfe_b_can',...
        'unitek_rr_run_b_can','unitek_rr_go_b_can','unitek_rr_feedback_b_can',...
        'unitek_rr_overvoltage_b_can','unitek_rr_motortemp_b_can','unitek_rr_motortemp_w_b_can',...
        'unitek_rr_devicetemp_b_can','unitek_rr_power_fault_b_can','unitek_rr_rfe_fault_b_can',...
        'drive_pwtrTqTarget_can','tq_vehicle_pos_limit_can','tq_vehicle_neg_limit_can',...
        'drive_deratingMotorTemp_b_can','drive_deratingAccuTemp_b_can',...
        'drive_deratingInverterTemp_b_can','drive_deratingAccuSoc_b_can',...
        'drive_deratingMotorCurrent_b_can','drive_deratingPeakPerf_b_can',...
        'drive_stratRecuActive_b_can','drive_powerLimitActive_b_can',...
        'tqv_result_fl_can','tqv_result_fr_can','tqv_result_rl_can','tqv_result_rr_can',...
        'tqv_rot_spd_fl_can','tqv_rot_spd_fr_can','tqv_rot_spd_rl_can','tqv_rot_spd_rr_can',...
        'tqv_status_tc_enabled_b_can','tqv_status_tqv_enabled_b_can',...
        'tqv_status_gps_fix_aquired_b_can','tqv_status_tqv_strength_can',...
        'tqv_status_tqv_base_strength_can','tqv_status_tc_mu_factor_can',...
        'tqv_status_tc_slip_target_can','tqv_tire_steerangle_can',...
        'tqv_tqLimitPos_front_can','tqv_tqLimitNeg_front_can',...
        'tqv_tqLimitPos_rear_can','tqv_tqLimitNeg_rear_can',...
        'slip_compare_val_fl_can','slip_compare_val_fr_can',...
        'slip_compare_val_rl_can','slip_compare_val_rr_can',...
        'wpmd_brake_temp_fl_can','wpmd_brake_temp_fr_can',...
        'wpmd_rotor_temp_fl_can','wpmd_rotor_temp_fr_can',...
        'wpmd_trans_temp_fl_can','wpmd_trans_temp_fr_can',...
        'wpmd_brake_temp_e_b_fl_can','wpmd_brake_temp_e_b_fr_can',...
        'wpmd_rotor_temp_e_b_fl_can','wpmd_rotor_temp_e_b_fr_can',...
        'ebs_preasure_front_can','ebs_preasure_rear_can',...
        'ebs_preasure_storage_can','ebs_preasure_cyl_front_can','ebs_preasure_cyl_back_can',...
        'SDC_AS_closed_b_can','SDC_Latch_Ready_b_can','sdc_res_b_can',...
        'bspd_b_can','bspd_avoid_b_can','bspd_sensor_err_b_can',...
        'bots_b_can','hv_current_bspd_can','hv_current_bspd_High_can',...
        'lap_cnt_can','laptime_can','lap_time_last_can','lap_time_best_can',...
        'lap_dist_can','lap_trigger_b_can',...
        'PDU_DCDC_12V_Gen_vout_can','PDU_DCDC_12V_Gen_iout_can','PDU_DCDC_12V_Gen_temp_can',...
        'PDU_DCDC_12V_Gen_vin_can','PDU_DCDC_12V_Gen_e_b_can','PDU_DCDC_12V_Gen_e_occu_b_can',...
        'PDU_DCDC_24V_Gen_vout_can','PDU_DCDC_24V_Gen_iout_can','PDU_DCDC_24V_Gen_temp_can',...
        'PDU_DCDC_24V_Gen_vin_can','PDU_DCDC_24V_Gen_e_b_can','PDU_DCDC_24V_Gen_e_occu_b_can',...
        'PDU_DCDC_DV_vout_can','PDU_DCDC_DV_iout_can','PDU_DCDC_DV_temp_can',...
        'PDU_DCDC_DV_vin_can','PDU_DCDC_DV_e_b_can','PDU_DCDC_DV_e_occu_b_can',...
        'PDU_DCDC_Ewp_Mot_1_vout_can','PDU_DCDC_Ewp_Mot_1_iout_can','PDU_DCDC_Ewp_Mot_1_temp_can',...
        'PDU_DCDC_Ewp_Mot_1_e_b_can','PDU_DCDC_Ewp_Mot_1_e_occu_b_can',...
        'PDU_DCDC_Ewp_Mot_2_vout_can','PDU_DCDC_Ewp_Mot_2_iout_can','PDU_DCDC_Ewp_Mot_2_temp_can',...
        'PDU_DCDC_Ewp_Mot_2_e_b_can','PDU_DCDC_Ewp_Mot_2_e_occu_b_can',...
        'PDU_DCDC_Fan_Inv_vout_can','PDU_DCDC_Fan_Inv_iout_can','PDU_DCDC_Fan_Inv_temp_can',...
        'PDU_DCDC_Fan_Inv_e_b_can','PDU_DCDC_Fan_Inv_e_occu_b_can',...
        'PDU_DCDC_Fan_Motor_vout_can','PDU_DCDC_Fan_Motor_iout_can','PDU_DCDC_Fan_Motor_temp_can',...
        'PDU_DCDC_Fan_Motor_e_b_can','PDU_DCDC_Fan_Motor_e_occu_b_can',...
        'PDU_eFuse_ACE_IMON_can','PDU_eFuse_ACE_e_b_can','PDU_eFuse_ACE_IMON_e_b_can',...
        'PDU_eFuse_AMS_IMON_can','PDU_eFuse_AMS_e_b_can','PDU_eFuse_AMS_IMON_e_b_can',...
        'PDU_eFuse_AMS_Fans_IMON_can','PDU_eFuse_AMS_Fans_e_b_can',...
        'PDU_eFuse_DVSC_IMON_can','PDU_eFuse_DVSC_e_b_can','PDU_eFuse_DVSC_IMON_e_b_can',...
        'PDU_eFuse_Ewp_Inv_IMON_can','PDU_eFuse_Ewp_Inv_e_b_can',...
        'PDU_eFuse_Inv_FL_IMON_can','PDU_eFuse_Inv_FL_e_b_can','PDU_eFuse_Inv_FL_IMON_e_b_can',...
        'PDU_eFuse_Inv_FR_IMON_can','PDU_eFuse_Inv_FR_e_b_can','PDU_eFuse_Inv_FR_IMON_e_b_can',...
        'PDU_eFuse_Inv_RL_IMON_can','PDU_eFuse_Inv_RL_e_b_can','PDU_eFuse_Inv_RL_IMON_e_b_can',...
        'PDU_eFuse_Inv_RR_IMON_can','PDU_eFuse_Inv_RR_e_b_can','PDU_eFuse_Inv_RR_IMON_e_b_can',...
        'PDU_eFuse_SDC_IMON_can','PDU_eFuse_SDC_e_b_can','PDU_eFuse_SDC_IMON_e_b_can',...
        'PDU_eFuse_12V_Gen_IMON_can','PDU_eFuse_12V_Gen_e_b_can','PDU_eFuse_12V_Gen_IMON_e_b_can',...
        'ewpInverterDuty_can','ewpMotorDuty_can','fanInverterDuty_can','fanMotorDuty_can',...
        'PDU_DCDC_Inv_temp_can','PDU_DCDC_Inv_temp_e_b_can',...
        'DL_EBS_state_can','DL_AS_state_can','DL_speed_actual_can','DL_speed_target_can',...
        'DL_steering_angle_actual_can','DL_steering_angle_target_can',...
        'DL_Motor_moment_actual_can','DL_Motor_moment_target_can',...
        'DL_Brake_hydr_actual_can','DL_Brake_hydr_target_can',...
        'DL_Cones_count_actual_can','DL_Cones_count_all_can',...
        'DL_Lap_counter_can','DL_Yaw_rate_can',...
        'VCU_Statemachine_can','VCU_AMI_state_can','VCU_GO_b_can',...
        'VCU_sc_b_can','ts_activate_b_can',...
    };
    for i = 1:144; signals{end+1} = sprintf('ams_cell_voltage%03d_can', i); end
    for i = 1:48;  signals{end+1} = sprintf('ams_cell_temp%03d_can',    i); end
end

% =========================================================
%% TERNARY HELPER
% =========================================================
function s = ternStr(cond, strTrue, strFalse)
    if cond; s = strTrue; else; s = strFalse; end
end
