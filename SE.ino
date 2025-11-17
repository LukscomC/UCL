// arquivo: substation_acq_serial.ino
// Arduino UNO (sem Ethernet) - envia via Serial
#include <Arduino.h>

const int PIN_ACS = A0;
const int PIN_VOLT = A1;
const float ACS_SENS = 0.185; // V/A
const float ADC_REF = 5.0;
const int ADC_MAX = 1023;
const int RMS_SAMPLES = 200;
const unsigned long INTERVAL_MS = 350;
unsigned long last = 0;

float readRMS(int pin) {
  double sum=0;
  for(int i=0;i<RMS_SAMPLES;i++){
    int raw = analogRead(pin);
    float v = (raw * ADC_REF)/ADC_MAX;
    float centered = v - (ADC_REF/2.0);
    sum += centered*centered;
    delayMicroseconds(200);
  }
  return sqrt(sum / RMS_SAMPLES);
}

float measureCurrent() {
  float vrms = readRMS(PIN_ACS);
  return vrms / ACS_SENS;
}

float measureVoltage() {
  float vrms = readRMS(PIN_VOLT);
  // if no divisor, calibrate scale=1.0
  float scale = 1.0;
  return vrms * scale;
}

void setup() {
  Serial.begin(9600);
  delay(500);
}

void loop() {
  if (millis() - last >= INTERVAL_MS) {
    float V = measureVoltage();
    float I = measureCurrent();
    // format for gateway/InduSoft parsing:
    // Tensao=4.73;Corrente=1.25;
    Serial.print("Tensao=");
    Serial.print(V, 2);
    Serial.print(";Corrente=");
    Serial.print(I, 2);
    Serial.print(";\n");
    last = millis();
  }
  while (Serial.available()) Serial.read(); // flush any
}
