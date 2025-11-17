// ===============================================================
//  Arduino OPC Server (biblioteca OPC.h)
//  Autor da lib: Ildefonso Martinez (https://github.com/ildemartinez/OPC)
//  Este sketch transforma o Arduino em um OPC Server via Ethernet.
//
//  Publica as variáveis:
//    Tensao (float)
//    Corrente (float)
//    Status_OPC (int)
//    Timestamp (string)
//
// ===============================================================

#include <SPI.h>
#include <Ethernet.h>
#include <OPC.h>        // biblioteca OPC
#include <Bridge.h>     // dependendo da versão pode exigir, mas normalmente não
#include <math.h>

// ---------------------------------------------------------------
// Configuração de rede FIXA (ajuste conforme sua LAN)
byte mac[] = { 0xDE,0xAD,0xBE,0xEF,0xFE,0x11 };
IPAddress ip(192,168,0,50);
unsigned int opcPort = 502;  // porta padrão do OPC Server simples da lib

// ---------------------------------------------------------------
OPCServer opcServer;
OPCItem opcTensao;
OPCItem opcCorrente;
OPCItem opcStatus;
OPCItem opcTimestamp;

// ---------------------------------------------------------------
// Sensores (use seus verdadeiros pinos)
#define PIN_ACS   A0
#define PIN_VOLT  A1

const float ADC_REF = 5.0;
const int   ADC_MAX = 1023;
const float ACS712_SENSITIVITY = 0.185;   // ACS712 5A

const int RMS_SAMPLES = 200;
const unsigned int SAMPLE_DELAY_US = 200;

float readRMS(int pin){
  double sumSq = 0;
  for(int i=0;i<RMS_SAMPLES;i++){
    int raw = analogRead(pin);
    float v = (raw * ADC_REF) / ADC_MAX;
    float centered = v - (ADC_REF/2.0);
    sumSq += centered * centered;
    delayMicroseconds(SAMPLE_DELAY_US);
  }
  return sqrt(sumSq / RMS_SAMPLES);
}

float measureVoltage(){
  return readRMS(PIN_VOLT);
}

float measureCurrent(){
  float vrms = readRMS(PIN_ACS);
  return vrms / ACS712_SENSITIVITY;
}

String getTimestamp(){
  unsigned long ms = millis();
  unsigned long s = ms/1000;
  return String(s) + "s";
}

// ---------------------------------------------------------------
void setup(){
  Ethernet.begin(mac, ip);
  delay(500);

  // inicializa o OPC Server
  opcServer.begin(ip, opcPort);

  // cria itens OPC
  opcTensao    = opcServer.addItem("Tensao");
  opcCorrente  = opcServer.addItem("Corrente");
  opcStatus    = opcServer.addItem("Status_OPC");
  opcTimestamp = opcServer.addItem("Timestamp");
}

// ---------------------------------------------------------------
void loop(){
  opcServer.processOPCCommands();  // PROCESSA CLIENTES (Indusoft)

  float V = measureVoltage();
  float I = measureCurrent();

  opcTensao.write(V);
  opcCorrente.write(I);
  opcStatus.write(1);
  opcTimestamp.write(getTimestamp());

  delay(350);   // taxa de atualização
}
