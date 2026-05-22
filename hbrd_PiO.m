% =========================================================
% MPPT P&O AVANCADO
% Painel: Canadian Solar CS6W-550MS
%
% Recursos implementados:
% - Alta taxa de amostragem
% - Filtro passa-baixa
% - Retroalimentacao positiva
% - Erro = dP/dV
% - Passo adaptativo
% - Conversor Boost
% =========================================================

clc;
clear;
close all;

% =========================================================
% DADOS DO PAINEL
% Canadian Solar CS6W-550MS
% =========================================================

Voc = 49.6;
Isc = 14.0;

Vmp = 41.7;
Imp = 13.2;

Pmpp = 550;

% =========================================================
% PARAMETROS SIMULACAO
% =========================================================

Fs = 10000;              % Alta taxa de amostragem
Ts = 1/Fs;

N = 3000;

tempo = (0:N-1)*Ts;

% =========================================================
% PARAMETROS FILTRO PASSA-BAIXA
% =========================================================
%
% y(k)=alpha*x(k)+(1-alpha)*y(k-1)
%

alpha = 0.08;

% =========================================================
% VETORES
% =========================================================

Vpv_array     = zeros(1,N);
Ipv_array     = zeros(1,N);
Ppv_array     = zeros(1,N);

Vf_array      = zeros(1,N);
Pf_array      = zeros(1,N);

Erro_array    = zeros(1,N);

Duty_array    = zeros(1,N);

Vout_array    = zeros(1,N);
Pout_array    = zeros(1,N);

Step_array    = zeros(1,N);

% =========================================================
% CONDICOES INICIAIS
% =========================================================

Vpv = 20;

Vf_old = Vpv;
Pf_old = 0;

% =========================================================
% LOOP PRINCIPAL
% =========================================================

for k = 1:N

    % -----------------------------------------------------
    % DEGRAU DE IRRADIANCIA
    % -----------------------------------------------------

    if k < 1500
        G = 0.75;
    else
        G = 1.0;
    end

    % =====================================================
    % MODELO FV
    % =====================================================

    Ipv = (Isc*G)*(1 - (Vpv/(Voc*G))^2);

    Ipv = max(Ipv,0);

    Ppv = Vpv * Ipv;

    % =====================================================
    % FILTRO PASSA-BAIXA
    % =====================================================

    if k == 1

        Vf = Vpv;
        Pf = Ppv;

    else

        Vf = alpha*Vpv + (1-alpha)*Vf_old;

        Pf = alpha*Ppv + (1-alpha)*Pf_old;

    end

    % =====================================================
    % ERRO = dP/dV
    % =====================================================

    dP = Pf - Pf_old;

    dV = Vf - Vf_old;

    if abs(dV) < 1e-6
        erro = 0;
    else
        erro = dP/dV;
    end

    % =====================================================
    % PASSO ADAPTATIVO
    % =====================================================

    step = 0.02 + 0.8*(abs(erro)/Pmpp);

    step = max(min(step,0.8),0.01);

    % =====================================================
    % RETROALIMENTACAO POSITIVA
    % =====================================================
    %
    % erro > 0 -> aumenta tensao
    % erro < 0 -> diminui tensao
    %

    ganho = 0.15;

    Vref = Vpv + ganho*erro;

    % Atualizacao perturbacao
    Vpv = Vref + sign(erro)*step;

    % Saturacao
    Vpv = max(min(Vpv,48),5);

    % =====================================================
    % CONVERSOR BOOST
    % =====================================================

    duty = 1 - (Vpv/Vmp);

    duty = max(min(duty,0.95),0.05);

    eficiencia = 0.97;

    Vout = Vpv/(1-duty);

    Pout = Ppv*eficiencia;

    % =====================================================
    % ARMAZENAMENTO
    % =====================================================

    Vpv_array(k) = Vpv;
    Ipv_array(k) = Ipv;
    Ppv_array(k) = Ppv;

    Vf_array(k) = Vf;
    Pf_array(k) = Pf;

    Erro_array(k) = erro;

    Duty_array(k) = duty;

    Vout_array(k) = Vout;
    Pout_array(k) = Pout;

    Step_array(k) = step;

    % =====================================================
    % ATUALIZACAO
    % =====================================================

    Vf_old = Vf;
    Pf_old = Pf;

end

% =========================================================
% CURVA P-V
% =========================================================

Vcurve = linspace(0,Voc,500);

Icurve = Isc*(1-(Vcurve/Voc).^2);

Pcurve = Vcurve.*Icurve;

% =========================================================
% GRAFICO 1
% CURVA P-V + TRAJETORIA MPPT
% =========================================================

figure;

plot(Vcurve,Pcurve,'LineWidth',2);

hold on;

plot(Vpv_array,Ppv_array,'LineWidth',1);

grid on;

title('MPPT P&O Avancado - Trajetoria no MPP');

xlabel('Tensao (V)');
ylabel('Potencia (W)');

legend('Curva P-V','Trajetoria MPPT');

% =========================================================
% GRAFICO 2
% TENSAO ENTRADA x SAIDA
% =========================================================

figure;

plot(tempo,Vpv_array,'LineWidth',2);

hold on;

plot(tempo,Vout_array,'LineWidth',2);

grid on;

title('Entrada x Saida Conversor Boost');

xlabel('Tempo (s)');
ylabel('Tensao (V)');

legend('Vpv','Vout');

% =========================================================
% GRAFICO 3
% POTENCIA
% =========================================================

figure;

plot(tempo,Ppv_array,'LineWidth',2);

hold on;

plot(tempo,Pout_array,'LineWidth',2);

grid on;

title('Potencia Entrada x Saida');

xlabel('Tempo (s)');
ylabel('Potencia (W)');

legend('Pin','Pout');

% =========================================================
% GRAFICO 4
% ERRO dP/dV
% =========================================================

figure;

plot(tempo,Erro_array,'LineWidth',2);

grid on;

title('Erro dP/dV');

xlabel('Tempo (s)');
ylabel('Erro');

% =========================================================
% GRAFICO 5
% PASSO ADAPTATIVO
% =========================================================

figure;

plot(tempo,Step_array,'LineWidth',2);

grid on;

title('Passo Adaptativo');

xlabel('Tempo (s)');
ylabel('Passo');

% =========================================================
% GRAFICO 6
% DUTY CYCLE
% =========================================================

figure;

plot(tempo,Duty_array,'LineWidth',2);

grid on;

title('Duty Cycle');

xlabel('Tempo (s)');
ylabel('Duty');
