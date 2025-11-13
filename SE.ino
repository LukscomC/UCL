/*
  Arduino UNO R3 - aquisição de tensão e corrente (envio serial)
  - ACS712 5A conectado ao A0 (corrente, sinal AC centrado em Vcc/2)
  - Divisor resistivo conectado ao A1 (tensão; use isolamento/transformador)
  - Serial: 9600 bps
  - Envio: a cada 350 ms no formato "SUB_Tensao:V;SUB_Corrente:A;\n"
*/

#include <Arduino.h>
#include <math.h>

// pinos
const int PIN_ACS = A0;    // ACS712 5A
const int PIN_VOLT = A1;   // divisor resistivo

// parâmetros de transmissão
const unsigned long BAUD = 9600;
const unsigned long SEND_INTERVAL_MS = 350UL;

// parâmetros de leitura RMS
const int RMS_SAMPLES = 200;      // número de amostras para cálculo RMS (ajustar)
const unsigned int SAMPLE_DELAY_US = 200; // espaçamento entre amostras (aprox.)

// parâmetros de hardware (CALIBRAR)
const float ADC_REF = 5.0;        // tensão de referência ADC (V)
const int ADC_MAX = 1023;
const float ACS_SENSITIVITY = 0.185; // V per A (ACS712 5A) - típico ~185 mV/A
// VOLTAGE_SCALE: multiplica o RMS medido no A1 para obter a tensão real (V)
// Calcule depois em bancada: VOLTAGE_SCALE = Vin_real_rms / Vout_rms_medido
float VOLTAGE_SCALE = 23.0; // EXEMPLO - ajustar conforme seu divisor/isolamento

unsigned long lastSend = 0;

// --- funções auxiliares ---
float readRMS(int pin, int samples) {
  // Calcula o valor RMS do sinal AC no pino analógico.
  // Para sensores centrados em Vcc/2 (como ACS712), subtrai Vcc/2 antes.
  double sumSq = 0.0;
  for (int i = 0; i < samples; i++) {
    int raw = analogRead(pin);
    float v = (raw * ADC_REF) / ADC_MAX;
    float centered = v - (ADC_REF / 2.0); // centraliza em zero
    sumSq += (double)centered * (double)centered;
    delayMicroseconds(SAMPLE_DELAY_US);
  }
  double meanSq = sumSq / (double)samples;
  float rms = sqrt(meanSq);
  return rms;
}

float measureCurrentA() {
  // lê RMS de tensão no sensor ACS e converte para corrente:
  // I_rms = V_rms / sensibilidade
  float vrms = readRMS(PIN_ACS, RMS_SAMPLES);
  float i_rms = vrms / ACS_SENSITIVITY;
  return i_rms;
}

float measureVoltageV() {
  // lê RMS no pino do divisor e aplica escala para obter tensão real RMS
  float vout_rms = readRMS(PIN_VOLT, RMS_SAMPLES);
  float vin_rms = vout_rms * VOLTAGE_SCALE;
  return vin_rms;
}

void sendSerial(float V, float I) {
  // envia na forma "SUB_Tensao:V;SUB_Corrente:I;\n"
  Serial.print("SUB_Tensao:");
  Serial.print(V, 2);
  Serial.print(";SUB_Corrente:");
  Serial.print(I, 2);
  Serial.print(";\n");
}

void setup() {
  Serial.begin(BAUD);
  delay(500); // tempo para estabilização
}

void loop() {
  unsigned long now = millis();
  if (now - lastSend >= SEND_INTERVAL_MS) {
    float V = measureVoltageV();
    float I = measureCurrentA();
    // enviar valores calculados
    sendSerial(V, I);
    lastSend = now;
  }
  // esvaziar buffer de entrada (se houver dados)
  while (Serial.available()) {
    Serial.read();
  }
}
