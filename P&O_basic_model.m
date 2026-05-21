% =========================================================
% MPPT P&O COMPLETO
% Comparacao Entrada x Saida + Oscilacao no MPP
% Resposta ao Degrau de Irradiancia
% =========================================================

clc;
clear;
close all;

% =========================================================
% DADOS DO PAINEL SOLAR
% =========================================================

Voc = 50;                 % Tensao circuito aberto
Isc = 14;                 % Corrente curto-circuito

Vmp_nominal = 41.7;       % Tensao no MPP
Imp_nominal = 13.2;       % Corrente no MPP

% =========================================================
% PARAMETROS DA SIMULACAO
% =========================================================

N = 300;
tempo = 1:N;

% =========================================================
% VETORES
% =========================================================

V_in   = zeros(1,N);      % Tensao do painel
I_in   = zeros(1,N);      % Corrente do painel
P_in   = zeros(1,N);      % Potencia do painel

V_out  = zeros(1,N);      % Tensao saida boost
P_out  = zeros(1,N);      % Potencia saida boost

duty_array = zeros(1,N);

% Vetores da trajetoria P&O
V_track = zeros(1,N);
P_track = zeros(1,N);

% =========================================================
% TENSAO INICIAL
% =========================================================

Vpv = 25;

% =========================================================
% SIMULACAO
% =========================================================

for k = 1:N

    % -----------------------------------------------------
    % DEGRAU DE IRRADIANCIA
    % -----------------------------------------------------

    if k < 150
        G = 0.7;
    else
        G = 1.0;
    end

    % -----------------------------------------------------
    % MODELO SIMPLIFICADO PAINEL FV
    % -----------------------------------------------------
    %
    % Curva I-V aproximada
    %

    Ipv = (Isc * G) * (1 - (Vpv/(Voc*G))^2);

    % Evita corrente negativa
    Ipv = max(Ipv,0);

    % Potencia entrada
    Pin = Vpv * Ipv;

    % -----------------------------------------------------
    % MPPT P&O
    % -----------------------------------------------------

    [duty, Vnext] = mppt_po(Vpv, Pin);

    % -----------------------------------------------------
    % CONVERSOR BOOST
    % -----------------------------------------------------

    Vboost = Vpv / (1 - duty);

    eficiencia = 0.95;

    Pboost = Pin * eficiencia;

    % -----------------------------------------------------
    % ARMAZENAMENTO
    % -----------------------------------------------------

    V_in(k) = Vpv;
    I_in(k) = Ipv;
    P_in(k) = Pin;

    V_out(k) = Vboost;
    P_out(k) = Pboost;

    duty_array(k) = duty;

    % Trajetoria do P&O
    V_track(k) = Vpv;
    P_track(k) = Pin;

    % Atualiza tensao
    Vpv = Vnext;

end

% =========================================================
% CURVA P-V COMPLETA
% =========================================================

Vcurve = linspace(0,Voc,500);

Icurve = Isc * (1 - (Vcurve/Voc).^2);

Pcurve = Vcurve .* Icurve;

% =========================================================
% GRAFICO 1
% TENSAO ENTRADA x SAIDA
% =========================================================

figure;

plot(tempo, V_in,'LineWidth',2);
hold on;
plot(tempo, V_out,'LineWidth',2);

grid on;

title('Tensao - Entrada x Saida MPPT');
xlabel('Iteracoes');
ylabel('Tensao (V)');

legend('Entrada Painel','Saida Boost');

% =========================================================
% GRAFICO 2
% POTENCIA ENTRADA x SAIDA
% =========================================================

figure;

plot(tempo, P_in,'LineWidth',2);
hold on;
plot(tempo, P_out,'LineWidth',2);

grid on;

title('Potencia - Entrada x Saida MPPT');
xlabel('Iteracoes');
ylabel('Potencia (W)');

legend('Potencia Painel','Potencia Saida');

% =========================================================
% GRAFICO 3
% DUTY CYCLE
% =========================================================

figure;

plot(tempo,duty_array,'LineWidth',2);

grid on;

title('Controle Duty Cycle - P&O');
xlabel('Iteracoes');
ylabel('Duty Cycle');

% =========================================================
% GRAFICO 4
% OSCILACAO AO REDOR DO MPP
% =========================================================

figure;

plot(Vcurve,Pcurve,'LineWidth',2);

hold on;

plot(V_track,P_track,'o-','LineWidth',1.5);

grid on;

title('Oscilacao do Metodo P&O em torno do MPP');

xlabel('Tensao do Painel (V)');
ylabel('Potencia do Painel (W)');

legend('Curva P-V','Trajetoria do P&O');

% =========================================================
% GRAFICO 5
% POTENCIA AO LONGO DO TEMPO
% =========================================================

figure;

plot(P_track,'LineWidth',2);

grid on;

title('Oscilacao da Potencia no MPPT');

xlabel('Iteracoes');
ylabel('Potencia (W)');

% =========================================================
% FUNCAO MPPT P&O
% =========================================================

function [duty, Vnext] = mppt_po(Vpv,Ppv)

    persistent V_old P_old duty_old direction

    % Inicializacao
    if isempty(V_old)

        V_old = Vpv;
        P_old = Ppv;

        duty_old = 0.50;

        direction = 1;

    end

    % -----------------------------------------------------
    % Variacoes
    % -----------------------------------------------------

    dP = Ppv - P_old;

    % Passo perturbacao
    stepV = 0.3;

    stepDuty = 0.005;

    % =====================================================
    % LOGICA P&O
    % =====================================================

    if dP < 0

        % Inverte direcao
        direction = -direction;

    end

    % -----------------------------------------------------
    % Nova tensao perturbada
    % -----------------------------------------------------

    Vnext = Vpv + direction*stepV;

    % Saturacao tensao
    Vnext = max(min(Vnext,48),5);

    % -----------------------------------------------------
    % Ajuste duty cycle
    % -----------------------------------------------------

    if direction > 0
        duty = duty_old + stepDuty;
    else
        duty = duty_old - stepDuty;
    end

    % Saturacao duty
    duty = max(min(duty,0.95),0.05);

    % -----------------------------------------------------
    % Atualizacao
    % -----------------------------------------------------

    V_old = Vpv;
    P_old = Ppv;

    duty_old = duty;

end
