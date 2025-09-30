function plotDataMissingBox(ax)
% plotDataMissingBox Zeichnet eine schwarze Box mit rotem Text in einem Achsen-Objekt.
%
%   plotDataMissingBox(ax) schaltet die Achsen des übergebenen
%   Achsen-Handles 'ax' aus und zeigt stattdessen eine zentrierte
%   Textbox mit der Nachricht "data missing" an.
%
%   Input:
%       ax - Handle zum Achsen- oder Kachel-Objekt, in dem die Box
%            gezeichnet werden soll (z.B. von gca oder nexttile).

    % Achsen, Ticks und Beschriftungen ausschalten
    % axis(ax, 'off');
    
    % Fügt das Textfeld in die Mitte des leeren Plots ein
    text(ax, 0.5, 0.5, 'data missing', ...
        'Color',            'red', ...          % Textfarbe
        'BackgroundColor',  'black', ...        % Hintergrundfarbe des Kastens
        'HorizontalAlignment', 'center', ...   % Text horizontal zentrieren
        'VerticalAlignment', 'middle', ...     % Text vertikal zentrieren
        'FontSize',         14, ...             % Größere Schriftart
        'FontWeight',       'bold');            % Fettschrift für bessere Sichtbarkeit
end