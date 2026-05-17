#include <SPI.h>     // Librería para comunicación SPI (usada para hablar con el ADS1292R)

// -------- Definición de pines del ESP32 --------
#define PIN_CS    5     // Chip Select del ADS1292R
#define PIN_DRDY  15    // Data Ready → indica cuando hay nueva muestra disponible
#define PIN_START 26    // Pin START → inicia conversiones ADC
#define PIN_PWDN  27    // Pin Power Down → reinicio y control de energía

// Función para activar comunicación SPI (CS en bajo)
void csLow()  { digitalWrite(PIN_CS, LOW); }

// Función para desactivar comunicación SPI (CS en alto)
void csHigh() { digitalWrite(PIN_CS, HIGH); }


// -------- Función para enviar comandos al ADS1292R --------
void sendCommand(byte cmd) {
  csLow();                 // Activa comunicación SPI
  SPI.transfer(cmd);       // Envía comando al ADS1292R
  csHigh();                // Termina comunicación
}

// -------- Función para escribir registros internos del ADS1292R --------
void writeRegister(byte reg, byte value) {
  csLow();                     
  SPI.transfer(0x40 | reg);    // Comando WREG + dirección del registro
  SPI.transfer(0x00);          // Indica que se escribirá solo un registro
  SPI.transfer(value);         // Valor que se quiere escribir
  csHigh();
}

// Variable global que guardará el offset de la señal
// Sirve para centrar la señal EMG en cero
long offset = 0; 

// ===================== SETUP =====================
void setup() {

  Serial.begin(115200);    // Inicializa comunicación serial con la PC

  // Inicializa bus SPI
  // Orden: SCLK, MISO, MOSI, CS
  SPI.begin(18, 19, 23, 5); 

  // Configuración de pines
  pinMode(PIN_CS, OUTPUT);   
  digitalWrite(PIN_CS, HIGH);   // CS comienza desactivado

  pinMode(PIN_DRDY, INPUT);     // DRDY es entrada (señal del ADS1292R)

  pinMode(PIN_START, OUTPUT);   
  digitalWrite(PIN_START, HIGH); // Mantiene activo el inicio de conversión

  pinMode(PIN_PWDN, OUTPUT);  
  digitalWrite(PIN_PWDN, HIGH);  // Mantiene encendido el ADS1292R

  // -------- Reinicio del ADS1292R --------
  delay(100);                    // Espera estabilidad
  digitalWrite(PIN_PWDN, LOW);   // Apaga momentáneamente
  delay(100);
  digitalWrite(PIN_PWDN, HIGH);  // Vuelve a encender
  delay(100);

  sendCommand(0x11);   // SDATAC → Detiene modo lectura continua
  delay(10);

  // -------- Configuración de registros del ADS1292R --------

  writeRegister(0x01, 0x03); // CONFIG1 → Frecuencia de muestreo = 1000 SPS
  writeRegister(0x02, 0xE0); // CONFIG2 → Buffer interno activado
  writeRegister(0x03, 0x0C); // CH1SET → Canal 1 activo, ganancia = 12
  writeRegister(0x04, 0x81); // CH2SET → Canal 2 apagado
  writeRegister(0x0D, 0x20); // RESP1 → Config respiración (no afecta EMG)
  writeRegister(0x0E, 0x00); // RESP2

  sendCommand(0x10); // START → Inicia conversiones ADC
  delay(10);

  sendCommand(0x01); // RDATAC → Activa lectura continua de datos

  Serial.println("Adquiriendo EMG real ±5 mV...");

  // -------- Cálculo del offset inicial --------
  // Se toman 100 muestras para calcular promedio
  long suma = 0;

  for(int i=0; i<100; i++){

    // Espera hasta que el ADS1292R indique nueva muestra
    while(digitalRead(PIN_DRDY) != LOW);

    csLow();

    byte datos[9];    // Buffer para guardar los 9 bytes del ADS1292R

    // Lee los 9 bytes del ADC
    for (int j = 0; j < 9; j++) 
      datos[j] = SPI.transfer(0x00);

    csHigh();

    // Reconstruye valor de 24 bits del canal 1
    long raw = ((long)datos[3] << 16) |
               ((long)datos[4] << 8)  |
                datos[5];

    // Ajusta signo del número (24 bits a 32 bits)
    if (raw & 0x800000) 
      raw |= 0xFF000000;

    suma += raw;   // Acumula muestras
  }

  offset = suma / 100; // Promedio = offset inicial
}

// ===================== LOOP =====================
void loop() {

  // Verifica si hay nueva muestra disponible
  if (digitalRead(PIN_DRDY) == LOW) {

    csLow();

    byte datos[9];

    // Lectura de los 9 bytes provenientes del ADS1292R
    for (int i = 0; i < 9; i++) 
      datos[i] = SPI.transfer(0x00);

    csHigh();

    // Reconstrucción del canal 1 (24 bits)
    long raw_ch1 = ((long)datos[3] << 16) |
                   ((long)datos[4] << 8)  |
                    datos[5];

    // Ajuste de signo
    if (raw_ch1 & 0x800000) 
      raw_ch1 |= 0xFF000000;

    // -------- Eliminación del offset --------
    raw_ch1 -= offset;

    // -------- Conversión digital a voltaje --------
    // 2.4 V es la referencia del ADS1292R
    float voltage_mV = 
        (raw_ch1 * 2.4f / 8388607.0f) * 1000.0f;

    // -------- Escalamiento para EMG superficial --------
    voltage_mV *= 0.002;  // Ajusta rango aproximado ±5 mV

    // -------- Envío al Serial Plotter --------
    Serial.println(voltage_mV, 3);  // 3 decimales
  }
}
