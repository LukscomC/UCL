% =========================================================
% MPPT P&O - COMPARACAO ENTRADA x SAIDA
% Resposta ao Degrau de Irradiancia
% =========================================================

clc;
clear;
close all;

% =========================================================
% DADOS DO PAINEL SOLAR
% =========================================================

Vmp_nominal = 41.7;      % Tensao nominal no MPP (V)
Imp_nominal = 13.2;      % Corrente nominal no MPP (A)

% =========================================================
% PARAMETROS DA SIMULACAO
% =========================================================

N = 200;
tempo = 1:N;

% Vetores
V_in  = zeros(1,N);      % Tensao do painel
P_in  = zeros(1,N);      % Potencia do painel

V_out = zeros(1,N);      % Tensao controlada pelo MPPT
P_out = zeros(1,N);      % Potencia apos MPPT

duty_array = zeros(1,N);

% =========================================================
% SIMULACAO
% =========================================================

for k = 1:N

    % -----------------------------------------------------
    % DEGRAU DE IRRADIANCIA
    % -----------------------------------------------------
    %
    % Simula mudanca brusca de irradiacao solar
    %

    if k < 100
        G = 0.7;
    else
        G = 1.0;
    end

    % -----------------------------------------------------
    % ENTRADA DO PAINEL SOLAR
    % -----------------------------------------------------

    Vpv = Vmp_nominal * G;
    Ipv = Imp_nominal * G;

    Pin = Vpv * Ipv;

    % -----------------------------------------------------
    % MPPT P&O
    % -----------------------------------------------------

    duty = mppt_po(Vpv, Ipv);

    % -----------------------------------------------------
    % MODELO SIMPLIFICADO DO CONVERSOR BOOST
    % -----------------------------------------------------
    %
    % Vout = Vin / (1-D)
    %

    Vboost = Vpv / (1 - duty);

    % Potencia de saida aproximada
    %
    % Considerando eficiencia simplificada
    %

    eficiencia = 0.95;

    Pboost = Pin * eficiencia;

    % -----------------------------------------------------
    % ARMAZENAMENTO
    % -----------------------------------------------------

    V_in(k)  = Vpv;
    P_in(k)  = Pin;

    V_out(k) = Vboost;
    P_out(k) = Pboost;

    duty_array(k) = duty;

end

% =========================================================
% GRAFICO - TENSAO ENTRADA x SAIDA
% =========================================================

figure;

plot(tempo, V_in,  'LineWidth',2);
hold on;
plot(tempo, V_out, 'LineWidth',2);

grid on;

title('Tensao - Entrada do Painel x Saida MPPT');
xlabel('Iteracoes');
ylabel('Tensao (V)');

legend('Entrada Painel','Saida MPPT');

% =========================================================
% GRAFICO - POTENCIA ENTRADA x SAIDA
% =========================================================

figure;

plot(tempo, P_in,  'LineWidth',2);
hold on;
plot(tempo, P_out, 'LineWidth',2);

grid on;

title('Potencia - Entrada do Painel x Saida MPPT');
xlabel('Iteracoes');
ylabel('Potencia (W)');

legend('Potencia Painel','Potencia Saida MPPT');

% =========================================================
% GRAFICO - DUTY CYCLE
% =========================================================

figure;

plot(tempo, duty_array, 'LineWidth',2);

grid on;

title('Controle Duty Cycle - MPPT P&O');
xlabel('Iteracoes');
ylabel('Duty Cycle');

% =========================================================
% FUNCAO MPPT P&O
% =========================================================

function duty = mppt_po(Vpv, Ipv)

    persistent V_old P_old duty_old

    % Inicializacao
    if isempty(V_old)

        V_old = 0;
        P_old = 0;
        duty_old = 0.50;

    end

    % -----------------------------------------------------
    % Potencia atual
    % -----------------------------------------------------

    P = Vpv * Ipv;

    % Variacoes
    dV = Vpv - V_old;
    dP = P - P_old;

    % Passo de perturbacao
    step = 0.005;

    % =====================================================
    % ALGORITMO PERTURBA E OBSERVA
    % =====================================================

    if dP > 0

        if dV > 0
            duty = duty_old - step;
        else
            duty = duty_old + step;
        end

    else

        if dV > 0
            duty = duty_old + step;
        else
            duty = duty_old - step;
        end

    end

    % Saturacao
    duty = max(min(duty,0.95),0.05);

    % Atualizacao
    V_old = Vpv;
    P_old = P;
    duty_old = duty;

end
