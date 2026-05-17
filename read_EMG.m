% ------------------ Datos del paciente ------------------
clc; clear; close all;

directorio = 'C:\Users\JOSE LUIS\Desktop\Mediciones_ADS1292R\';

label = 0;  % Etiqueta fija por defecto

Sujeto = input('Ingrese número o nombre del sujeto: ','s');

Musculo = input('Ingrese músculo (1 = Vasto Medial, 2 = Recto Femoral, 3 = Vasto Lateral): ');
if ~ismember(Musculo,1:3)
    error('Músculo debe ser 1, 2 o 3');
end

Peso = input('Ingrese nivel de contracción (0 = relajado, 1 = isométrica sin peso, 2 = isométrica con peso): ');
if ~ismember(Peso,0:2)
    error('Peso debe ser 0, 1 o 2');
end

Pierna = input('Ingrese pierna (1 = Izquierda, 2 = Derecha): ');
if ~ismember(Pierna,1:2)
    error('Pierna debe ser 1 o 2');
end

% ------------------ Medición fija en 0 ------------------
Medicion = 0;

% ------------------ Nombre base (sin _n todavía) ------------------
nombre_base = sprintf('%d%s%d%d%d%d', label, Sujeto, Musculo, Peso, Medicion, Pierna);

% ------------------ Buscar si ya existen archivos previos ------------------
archivos_existentes = dir(fullfile(directorio, [nombre_base, '_*.xlsx']));
num_mediciones = length(archivos_existentes) + 1;

% ------------------ Generar el nombre final con _n ------------------
nombre_archivo = sprintf('%s_%d.xlsx', nombre_base, num_mediciones);
ruta_completa = fullfile(directorio, nombre_archivo);

%% ------------------ Configuración de adquisición ------------------
puerto = 'COM3';
baudrate = 115200;
duracion = 5;

% ------------------ Conexión serial ------------------
s = serialport(puerto, baudrate);
flush(s);

disp(['Iniciando adquisición de EMG durante ', num2str(duracion), ' segundos...']);
pause(1);

datos = [];
t_inicial = tic;
ultimo_segundo = 0;

% ------------------ Lectura de muestras ------------------
while toc(t_inicial) < duracion
    if s.NumBytesAvailable > 0
        linea = readline(s);
        valor = str2double(linea);
        if ~isnan(valor)
            datos = [datos; valor];
        end

        tiempo_actual = toc(t_inicial);
        if floor(tiempo_actual) > ultimo_segundo
            ultimo_segundo = floor(tiempo_actual);
            fprintf('Segundo %d...\n', ultimo_segundo);
        end
    end
end

fprintf('Adquisición finalizada (%.2f s reales)\n', toc(t_inicial));

clear s;

%% ------------------ Interpolación a 1000 Hz ------------------
Fs = 1000;
t_original = linspace(0, duracion, length(datos));
t_uniforme = 0:1/Fs:duracion;
datos_interp = interp1(t_original, datos, t_uniforme, 'linear', 'extrap');

%% ------------------ Filtrado ------------------
senal_cruda = datos_interp - mean(datos_interp);
senal_filtrada = bandpass(senal_cruda, [20 250], Fs);

%% ------------------ Gráfica ------------------
figure;
plot(t_uniforme, senal_filtrada, 'b', 'LineWidth', 1.2);
title('Señal EMG');
xlabel('Tiempo (s)');
ylabel('Amplitud (mV)');
grid on;
xlim([0 duracion]);

%% ------------------ Guardado automático ------------------
writematrix([t_uniforme' senal_filtrada'], ruta_completa);
fprintf('Archivo guardado como: %s\n', ruta_completa);
