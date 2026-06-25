function build_tab_pdu(tab, signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
dcdc_namen = {'12V_Gen', '24V_Gen', 'DV', 'Ewp_Mot_1', 'Ewp_Mot_2', 'Fan_Inv', 'Fan_Motor'};
xpos = [10, 240, 470, 700, 930, 1160, 1370];
for i = 1:numel(dcdc_namen)
    build_dcdc_karte(tab, signale, dcdc_namen{i}, cfg, [xpos(i), 800, 215, 100]);
end

build_efuse_panel(tab, signale, cfg, [10, 590, 770, 200]);

ax1 = erstelle_plot_bereich(tab, [800, 590, 770, 200], 'Kuehlung Duty Cycles (%)', cfg);
plot_oder_leer(ax1, signale, {'ewpInverterDuty_can', 'ewpMotorDuty_can', 'fanInverterDuty_can', 'fanMotorDuty_can'}, ...
    {'EWP Inv', 'EWP Mot', 'Fan Inv', 'Fan Mot'}, cfg);

ax2 = erstelle_plot_bereich(tab, [10, 370, 770, 210], 'DCDC Ausgangsspannungen (V)', cfg);
plot_oder_leer(ax2, signale, {'PDU_DCDC_12V_Gen_vout_can', 'PDU_DCDC_24V_Gen_vout_can', 'PDU_DCDC_DV_vout_can'}, ...
    {'12V Gen', '24V Gen', 'DV'}, cfg);

ax3 = erstelle_plot_bereich(tab, [800, 370, 770, 210], 'eFuse Strom Monitor (A)', cfg);
plot_oder_leer(ax3, signale, {'PDU_eFuse_ACE_IMON_can', 'PDU_eFuse_AMS_IMON_can', ...
    'PDU_eFuse_DVSC_IMON_can', 'PDU_eFuse_SDC_IMON_can'}, {'ACE', 'AMS', 'DVSC', 'SDC'}, cfg);

ax4 = erstelle_plot_bereich(tab, [10, 150, 770, 210], 'Inverter eFuse Strom (A)', cfg);
plot_oder_leer(ax4, signale, {'PDU_eFuse_Inv_FL_IMON_can', 'PDU_eFuse_Inv_FR_IMON_can', ...
    'PDU_eFuse_Inv_RL_IMON_can', 'PDU_eFuse_Inv_RR_IMON_can'}, {'Inv FL', 'Inv FR', 'Inv RL', 'Inv RR'}, cfg);

ax5 = erstelle_plot_bereich(tab, [800, 150, 770, 210], 'SDC & Safety', cfg);
plot_oder_leer(ax5, signale, {'SDC_AS_closed_b_can', 'SDC_Latch_Ready_b_can', 'imd_ok_b_can', 'ams_ok_b_can'}, ...
    {'SDC closed', 'Latch ready', 'IMD OK', 'AMS OK'}, cfg);
end