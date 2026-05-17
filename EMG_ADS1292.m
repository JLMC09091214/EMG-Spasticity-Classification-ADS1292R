clear; clc;  % Limpiar entorno de trabajo
% Declaramos las variables globales necesarias
global allData currentIndex showFiltered filteredData showRectified rectifiedData showEnvelope envelope fs showWavelet waveletOption;

currentColumn = 2;  % Inicializar currentColumn
% Preparar el conjunto de datos original
addpath(genpath('./src'))  % Agrega las carpetas de funciones al path
datapath = fullfile('./datads');  % Ruta de la carpeta de datos
folderNames = FindFolders(datapath);  % Encontrar las carpetas dentro de la ruta de datos
allData = {};  % Inicializar celda para almacenar los gráficos y RMS
rmsData = NaN(2700, 2);  % Crear una matriz de NaN de 3120x2 para almacenar RMS y etiquetas

% Inicializamos las tablas para almacenar los valores de las funciones y su label
dASDVTable = table([], [], 'VariableNames', {'DASDV', 'Label'});
iemgTable = table([], [], 'VariableNames', {'IEMG', 'Label'});
mavTable = table([], [], 'VariableNames', {'MAV', 'Label'});
rmsTable = table([], [], 'VariableNames', {'RMS', 'Label'});
sscTable = table([], [], 'VariableNames', {'SSC', 'Label'});
varTable = table([], [], 'VariableNames', {'VAR', 'Label'});
varemgTable = table([], [], 'VariableNames', {'VAREMG', 'Label'});
wlTable = table([], [], 'VariableNames', {'WL', 'Label'});
waTable = table([], [], 'VariableNames', {'WA', 'Label'});
zcTable = table([], [], 'VariableNames', {'ZC', 'Label'});
% Tabla para almacenar el Label, FZC y ASM combinados
combinedTable = table([], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], 'VariableNames', {'Label', 'Sujeto', 'Musculo', 'Peso', 'Medicion', 'Pierna', 'DASDV', 'IEMG', 'MAV', 'RMS', 'SSC', 'VAR', 'VAREMG', 'WL','WA','ZC'});

% Especificaciones del filtro Butterworth
fs = 1000;  % Frecuencia de muestreo (ajusta según tus datos)
low_cutoff = 20;   % Frecuencia de corte inferior en Hz (20 Hz)
high_cutoff = 250;  % Frecuencia de corte superior en Hz (250 Hz)
order = 4;   % Orden del filtro Butterworth

% Diseñar el filtro Butterworth de paso banda
[b, a] = butter(order, [low_cutoff high_cutoff] / (fs / 2), 'bandpass');

% Definir parámetros para funciones que requieren umbral
opts.threshold = 0.05;  % Ajusta según tu señal (p. ej. 0.01, 0.05, etc.)

% Crear la figura y los botones de navegación
fig = uifigure('Name', 'Visualización de Datos', 'Position', [10, 100, 800, 600],'AutoResizeChildren', 'off');
ax = axes(fig, 'Position', [0.1, 0.35, 0.8, 0.6]);  % Crear un eje para la gráfica de la señal original

% Crear otra figura para la FFT
figFFT = figure('Name', 'Transformada de Fourier', 'Position', [820, 245, 540, 400]);
axFFT = axes(figFFT, 'Position', [0.1, 0.1, 0.8, 0.8]);  % Crear el eje para la FFT

currentIndex = 1;  % Índice inicial del gráfico mostrado
showFiltered = false;  % Variable de control para mostrar u ocultar la señal filtrada
showRectified = false;  % Variable de control para mostrar u ocultar la señal rectificada
showEnvelope = false;  % Variable de control para mostrar u ocultar la envolvente
showWavelet = false;  % Variable de control para mostrar u ocultar la transformada de wavelet
waveletOption = '';

% Crear los botones de flecha
btnLeft = uibutton(fig, 'Text', '←', 'Position', [100, 50, 50, 30], ...
    'ButtonPushedFcn', @(btn, event) updatePlot(-1, ax, axFFT));  % Pasa -1 al presionar la flecha izquierda
btnRight = uibutton(fig, 'Text', '→', 'Position', [650, 50, 50, 30], ...
    'ButtonPushedFcn', @(btn, event) updatePlot(1, ax, axFFT));  % Pasa 1 al presionar la flecha derecha

% Ajustar el espacio entre los botones y la posición de los mismos
buttonWidth = 120;  % Ancho de cada botón
buttonHeight = 30;  % Altura de los botones
horizontalSpacing = 10;  % Espaciado horizontal entre los botones
startX = 150;  % Posición X inicial para los botones (más espacio para no sobreponerse con las flechas)

% Crear los botones entre las flechas
% Crear el botón "Señal Filtrada"
btnFiltered = uibutton(fig, 'Text', 'Señal Filtrada', 'Position', [startX, 50, buttonWidth, buttonHeight], ...
    'ButtonPushedFcn', @(btn, event) toggleFilteredSignal(btn, ax, axFFT));

% Crear el botón "Señal Rectificada"
btnRectified = uibutton(fig, 'Text', 'Señal Rectificada', 'Position', [startX + (buttonWidth + horizontalSpacing), 50, buttonWidth, buttonHeight], ...
    'ButtonPushedFcn', @(btn, event) toggleRectifiedSignal(btn, ax, axFFT));

% Crear el botón "Envolvente"
btnEnvelope = uibutton(fig, 'Text', 'Envolvente', 'Position', [startX + 2 * (buttonWidth + horizontalSpacing), 50, buttonWidth, buttonHeight], ...
    'ButtonPushedFcn', @(btn, event) toggleEnvelopeSignal(btn, ax, axFFT));

% Crear un menú desplegable para seleccionar los coeficientes de la wavelet
btnWavelet = uidropdown(fig, ...
    'Position', [startX + 3 * (buttonWidth + horizontalSpacing), 50, buttonWidth, buttonHeight], ...
    'Items', {'Coef. Aproximación', 'Coef. Detalle Nivel 1', 'Coef. Detalle Nivel 2', 'Coef. Detalle Nivel 3','Señal DWT'}, ...
    'Value', 'Coef. Aproximación', ...
    'ValueChangedFcn', @(src, event) handleWaveletOption(ax, src.Value));  % <--- función separada

btnClearWavelet = uibutton(fig, 'Text', 'Limpiar Wavelet', ...
    'Position', [startX + 3 * (buttonWidth + horizontalSpacing), 10, buttonWidth, buttonHeight], ...
    'ButtonPushedFcn', @(btn, event) clearWaveletPlots(ax));


% Leer y procesar los archivos de datos
counter = 1;  % Contador para asegurarse de que no se excedan las 25 filas
for j = 1:length(folderNames)  % Recorre todas las carpetas encontradas
    path1 = fullfile(datapath, folderNames(j).name);  % Ruta de la carpeta actual
    filenames = dir(fullfile(path1, '*.xlsx')); % Encuentra todos los archivos .xlsx dentro de la carpeta
    % Filtrar archivos donde la primera parte sean solo dígitos
    validFiles = [];
    %Saltar carpeta si no tiene archivos .xlsx
    if isempty(filenames)
        error('No se encontraron archivos .xlsx en la carpeta.'); 
    end
    [~, idx] = sort({filenames.name});
    filenames = filenames(idx);
    for i = 1:length(filenames)  % Recorre todos los archivos .xlsx
        % Leer el archivo Excel utilizando readtable
        dataTable = readtable(fullfile(path1, filenames(i).name));  % Aquí accedemos correctamente a la estructura
        OriginalSignal = dataTable{:, currentColumn};

        % Convertir los datos de la tabla a un arreglo numérico
        if width(dataTable) > 1
            raw = dataTable{:,2};     % Selecciona amplitud
        else
            raw = dataTable{:,1};     % Si solo existe una columna
        end

        raw(isnan(raw)) = 0;  % Reemplaza NaN con 0
        % Detectar si los datos parecen conteos enteros grandes (unsigned)
        counts = raw;
        % Si parecen enteros grandes (>1e5), convertir two's complement 24-bit
        if max(abs(counts)) > 1e5
            % convertir unsigned->signed si hace falta
            mask = counts > (2^23 - 1);
            counts(mask) = counts(mask) - 2^24;
             % Conversión 24 bits a Voltios
            Vref = 2.42;     % Voltaje de referencia típico del ADS1292
            Gain = 12;       % Ganancia interna configurada
            ADCres = 2^23-1; % Resolución en 24 bits (signed)
            volts = (counts ./ ADCres) * Vref / Gain;
            originalSignal = volts * 1000; % en mV
        else
            % Si los valores parecen ya pequeños (ej. en V o mV), asumir ya en mV o V
            % aquí asumimos que están en V si max<10; conviértelo a mV
            if max(abs(counts)) < 10
                originalSignal = counts * 1000; % V -> mV
            else
                originalSignal = counts; % ya en mV
            end
        end

        % Filtrar la señal con el filtro Butterworth de paso banda
        filteredData = filtfilt(b, a, originalSignal);

        % Rectificar la señal
        rectifiedData = abs(filteredData);  % Rectificación de la señal
        
        % Calcular la DWT de la señal filtrada
        maxLevel = wmaxlev(length(filteredData), 'bior3.3');
        level = min(4, maxLevel);
        [c, l] = wavedec(filteredData, level, 'bior3.3');
        
        approx4 = appcoef(c, l, 'bior3.3', 4);
        detail1 = detcoef(c, l, 1);
        detail2 = detcoef(c, l, 2);
        detail3 = detcoef(c, l, 3);
    
        % Obtiene nombre sin .xlsx
        filename = erase(filenames(i).name, ".xlsx");
        
        % Separa codigo y numero de medicion
        parts = split(filename, "_");
        
        if numel(parts) ~= 2
            error('El nombre %s no tiene el formato XXXXXXX_Y.xlsx', filenames(i).name);
        end
        
        code = parts{1};   % Ejemplo: '0111002'
        num_medicion = str2double(parts{2});  % Ej: 1,2,...,10
        
        if ~any(strlength(code) == [6 7])
            error('El código "%s" debe tener exactamente 6 o 7 dígitos.', code);
        end
        
        Label = str2double(code(1));  
        
        if strlength(code) == 7
            Sujeto = str2double(code(2:3));  % 2 dígitos
            idx = 4;                         % resto empieza en posición 4
        else
            Sujeto = str2double(code(2));    % 1 dígito
            idx = 3;                         % resto empieza en posición 3
        end
        
        Musculo = str2double(code(idx));
        Peso = str2double(code(idx+1));
        Medicion = str2double(code(idx+2));
        Pierna = str2double(code(idx+3));

        signalForFeatures = originalSignal; 
    
        % Funciones a calcular y almacenar en tablas con su Label
        % 1. Calcular DASDV
        DASDV = jDifferenceAbsoluteStandardDeviationValue(signalForFeatures);  % Llamada a la función DASDV
        dASDVTable = [dASDVTable; table(DASDV, Label)];  % Almacenar DASDV en la tabla
        
        % 2. Calcular IEMG
        IEMG = jIntegratedEMG(signalForFeatures);  % Llamada a la función IEMG
        iemgTable = [iemgTable; table(IEMG, Label)];  % Almacenar IEMG en la tabla
        
        % 3. Calcular MAV
        MAV = jMeanAbsoluteValue(signalForFeatures);  % Llamada a la función MAV
        mavTable = [mavTable; table(MAV, Label)];  % Almacenar MAV en la tabla
        
        % 4. Calcular RMS
        RMS = jRootMeanSquare(signalForFeatures);  % Llamada a la función RMS
        rmsTable = [rmsTable; table(RMS, Label)];  % Almacenar RMS en la tabla
        
        % 5. Calcular SSC
        SSC = jSlopeSignChange(signalForFeatures, opts);  % Llamada a la función SSC
        sscTable = [sscTable; table(SSC, Label)];  % Almacenar SSC en la tabla
        
        % 6. Calcular VAR
        VAR = jVariance(signalForFeatures);  % Llamada a la función VAR
        varTable = [varTable; table(VAR, Label)];  % Almacenar VAR en la tabla
        
        % 7. Calcular VAR de EMG
        VAREMG = jVarianceOfEMG(signalForFeatures);  % Llamada a la función VAR de EMG
        varemgTable = [varemgTable; table(VAREMG, Label)];  % Almacenar VAR de EMG en la tabla
        
        % 8. Calcular WL
        WL = jWaveformLength(signalForFeatures);  % Llamada a la función WL
        wlTable = [wlTable; table(WL, Label)];  % Almacenar
        
        % 9. Calcular WA
        WA = jWillisonAmplitude(signalForFeatures,opts);  % Llamada a la función WL
        waTable = [waTable; table(WA, Label)];  % Almacenar

         % 10. Calcular ZC
        ZC = jZeroCrossing(signalForFeatures, opts);  % Llamada a la función VO
        zcTable = [zcTable; table(ZC, Label)];  % Almacenar VO en la tabla
        
        % Almacenar los valores de FZC, ASM y Label en la tabla combinada
        combinedTable = [combinedTable; table(Label, Sujeto, Musculo, Peso, Medicion, Pierna, DASDV, IEMG, MAV, RMS, SSC, VAR, VAREMG, WL, WA, ZC)];

        % Calcular el RMS de los datos filtrados
        rmsValue = rms(filteredData);  % Calcular el valor RMS
        
        % Calcular la envolvente de la señal rectificada
        window = 100;  % Tamaño de la ventana en ms (ajustable)
        L = length(rectifiedData);  % Longitud de la señal rectificada
        envelope = sqrt(movmean(rectifiedData.^2, window));  % Cálculo de la envolvente

         allData{end+1} = struct('dataOriginal', OriginalSignal, 'rms', rmsValue, 'label', Label, ...
        'filteredData', filteredData, 'rectifiedData', rectifiedData, 'envelope', envelope, ...
        'filename', filenames(i).name, 'fs',fs, 'dwt_c', c, 'dwt_l', l, 'approx4', approx4, 'detail1', detail1, 'detail2', detail2, 'detail3', detail3);  % Almacenar el nombre del archivo

        % Almacenar el valor RMS y la etiqueta en la matriz rmsData
        if counter <= 2700
            rmsData(counter, :) = [rmsValue, Label];
            counter = counter + 1;
        else
            break;  % Si hemos alcanzado 2250, no agregamos más datos
        end
    end
    if counter > 2700
        break;  % Si hemos alcanzado 2250, no seguimos procesando más carpetas
    end
end

    outputFeaturesFile = fullfile(path1, 'features_dataset.xlsx');
    writetable(combinedTable, outputFeaturesFile);
    
    fprintf('Tabla combinada exportada a: %s\n', outputFeaturesFile);

% Verificar si 'allData' tiene datos antes de intentar graficar
    if isempty(allData)
        error('No se han cargado datos. Verifique que los archivos se están leyendo correctamente.');
    else
    % Inicializar la primera gráfica
        updatePlot(0, ax, axFFT);  % Muestra el primer gráfico cuando el script se ejecuta
    end
 
% Función para actualizar el gráfico según el índice
function updatePlot(direction, ax, axFFT)
    global allData currentIndex showFiltered showRectified showEnvelope showWavelet waveletOption fs;

    currentIndex = currentIndex + direction;
    if currentIndex < 1, currentIndex = length(allData); end
    if currentIndex > length(allData), currentIndex = 1; end

    cla(ax);
    % Graficar señal ORIGINAL por defecto
    plot(ax, allData{currentIndex}.dataOriginal, 'b'); hold(ax,'on');

    % Título y ejes
    filename = erase(allData{currentIndex}.filename, '.xlsx');
    title(ax, ['Archivo: ' filename ' - RMS filtrada: ' num2str(allData{currentIndex}.rms)]);
    xlabel(ax, 'Sample index'); ylabel(ax, 'Amplitude (mV)');
    grid(ax,'on');

    legendEntries = {'Señal Original'};

    % Mostrar señal filtrada (visual)
    if showFiltered && isfield(allData{currentIndex}, 'filteredData')
        plot(ax, allData{currentIndex}.filteredData, 'r', 'LineWidth', 1.2);
        legendEntries{end+1} = 'Señal Filtrada';
    end

    % Mostrar señal rectificada (visual)
    if showRectified && isfield(allData{currentIndex}, 'rectifiedData')
        plot(ax, allData{currentIndex}.rectifiedData, 'g', 'LineWidth', 1.2);
        legendEntries{end+1} = 'Señal Rectificada';
    end

    % Mostrar envolvente (visual)
    if showEnvelope && isfield(allData{currentIndex}, 'envelope')
        plot(ax, allData{currentIndex}.envelope, 'k', 'LineWidth', 1.5);
        legendEntries{end+1} = 'Envolvente';
    end

    legend(ax, legendEntries, 'Location', 'best');
    hold(ax,'off');

    % actualizar wavelet si está encendida
    if showWavelet && ~isempty(waveletOption)
        updateWavelet(ax, waveletOption);
    end

    % actualizar FFT en la otra figura
    updateFFT(axFFT);
end

% Función para actualizar la Transformada de Fourier en la segunda ventana (figura)
function updateFFT(axFFT)
    global allData currentIndex fs;
    cla(axFFT);
    sig = allData{currentIndex}.filteredData;
    sig = detrend(sig);         % quitar tendencia/DC antes de FFT
    L = length(sig);
    Y = fft(sig);
    P2 = abs(Y / L);
    P1 = P2(1:floor(L/2)+1);
    P1(2:end-1) = 2*P1(2:end-1);
    f = fs*(0:(floor(L/2)))/L;
    plot(axFFT, f, P1);
    title(axFFT, ['Transformada de Fourier - ' erase(allData{currentIndex}.filename, '.xlsx')]);
    xlabel(axFFT,'Frecuencia (Hz)'); ylabel(axFFT,'Amplitud');
    grid(axFFT,'on');
end

function handleWaveletOption(ax, selectedOption)
    global showWavelet waveletOption;

    waveletOption = selectedOption;
    showWavelet = true;

    updatePlot(0, ax, []);  % Re-dibuja la señal con la wavelet seleccionada
end

function updateWavelet(ax, selectedOption)
    global allData currentIndex;

    % Limpiar eje antes de graficar
    cla(ax);

    % Obtener señal filtrada actual
    signal = allData{currentIndex}.filteredData;

    % Si la señal tiene menos de 5000 muestras, evitar error del xlim
    maxSamples = min(5000, length(signal));

    % Cálculo de wavelet
    [c, l] = wavedec(signal, 4, 'bior3.3');

    coeffData.approxCoefficients = appcoef(c, l, 'bior3.3', 4);

    coeffData.detailCoefficients = cell(1, 3);
    for i = 1:3
        coeffData.detailCoefficients{i} = detcoef(c, l, i);
    end

    % Iniciar leyenda
    legendEntries = {'Señal Original'};

    hold(ax, 'on');

    % Señal original siempre en verde
    plot(ax, signal, 'g', 'LineWidth', 1.5);

    switch selectedOption
        case 'Coef. Aproximación'
            approxCoefficients = coeffData.approxCoefficients;

            originalIdx = linspace(1, length(approxCoefficients), length(approxCoefficients));
            targetIdx   = linspace(1, length(approxCoefficients), length(signal));

            approxExt = interp1(originalIdx, approxCoefficients, targetIdx,'spline');

            plot(ax, approxExt, 'k');
            legendEntries{end+1} = 'Coef. Aproximación Nivel 3';

        case 'Coef. Detalle Nivel 1'
            detail = coeffData.detailCoefficients{1};

            originalIdx = linspace(1, length(detail), length(detail));
            targetIdx   = linspace(1, length(detail), length(signal));

            detailExt = interp1(originalIdx, detail, targetIdx,'linear');
            plot(ax, detailExt, 'Color',[0.54, 0.27, 0.07]);
            legendEntries{end+1} = 'Coef. Detalle Nivel 1';

        case 'Coef. Detalle Nivel 2'
            detail = coeffData.detailCoefficients{2};

            originalIdx = linspace(1, length(detail), length(detail));
            targetIdx   = linspace(1, length(detail), length(signal));

            detailExt = interp1(originalIdx, detail, targetIdx,'linear');
            plot(ax, detailExt, 'Color',[1.0, 0.65, 0.0]);
            legendEntries{end+1} = 'Coef. Detalle Nivel 2';

        case 'Coef. Detalle Nivel 3'
            detail = coeffData.detailCoefficients{3};

            originalIdx = linspace(1, length(detail), length(detail));
            targetIdx   = linspace(1, length(detail), length(signal));

            detailExt = interp1(originalIdx, detail, targetIdx,'linear');
            plot(ax, detailExt, 'm');
            legendEntries{end+1} = 'Coef. Detalle Nivel 3';

        case 'Señal DWT'
            reconstructed = waverec(c, l, 'bior3.3');
            plot(ax, reconstructed, 'b');
            legendEntries{end+1} = 'Señal DWT Reconstruida';
    end

    % Limitar a máximo 5000 muestras o longitud real, lo que sea menor
    xlim(ax, [1 maxSamples]);

    legend(ax, legendEntries, 'Location', 'best');
    grid(ax, 'on');
    hold(ax, 'off');
end

function clearWaveletPlots(ax)
    global showWavelet waveletOption;

    % Apagar la visualización de Wavelet
    showWavelet = false;
    waveletOption = '';  % Limpiar la opción seleccionada

    % Volver a graficar sin los coeficientes de wavelet
    updatePlot(0, ax, []);  % Usamos gca como axFFT porque solo actualizamos el principal
end

% Función para alternar la visualización de la señal filtrada
function toggleFilteredSignal(btn, ax, axFFT)
    global showFiltered;
    
    % Alternar el estado de la variable showFiltered
    showFiltered = ~showFiltered;
    
    % Cambiar el texto del botón
    if showFiltered
        btn.Text = 'Ocultar Señal Filtrada';
    else
        btn.Text = 'Señal Filtrada';
    end
    
    % Actualizar los gráficos
    updatePlot(0, ax, axFFT);
end

% Función para mostrar u ocultar la señal rectificada
function toggleRectifiedSignal(btn, ax, axFFT)
    global showRectified;
    
    % Alternar el estado de la variable showRectified
    showRectified = ~showRectified;
    
    % Cambiar el texto del botón
    if showRectified
        btn.Text = 'Ocultar Señal Rectificada';
    else
        btn.Text = 'Señal Rectificada';
    end
    
    % Actualizar los gráficos
    updatePlot(0, ax, axFFT);
end

% Función para mostrar u ocultar la envolvente
function toggleEnvelopeSignal(btn, ax, axFFT)
    global showEnvelope;
    
    % Alternar el estado de la variable showEnvelope
    showEnvelope = ~showEnvelope;
    
    % Cambiar el texto del botón
    if showEnvelope
        btn.Text = 'Ocultar Envolvente';
    else
        btn.Text = 'Envolvente';
    end
    
    % Actualizar los gráficos
    updatePlot(0, ax, axFFT);
end




 