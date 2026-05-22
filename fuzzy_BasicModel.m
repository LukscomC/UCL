% =========================================================
% MPPT FUZZY LOGIC PARA SISTEMA FOTOVOLTAICO
% Controle Fuzzy aplicado a conversor Boost
% COMPARAÇÃO COM O PONTO DE MÁXIMA POTÊNCIA
% =========================================================

clc;
clear;
close all;

% =========================================================
% PARÂMETROS DO PAINEL FV
% =========================================================

Voc = 50;          % Tensão de circuito aberto (V)
Isc = 14;          % Corrente de curto-circuito (A)

Vmp = 41.7;        % Tensão no ponto de máxima potência (V)
Imp = 13;          % Corrente no ponto de máxima potência (A)

Pmax_nominal = Vmp * Imp;

% =========================================================
% PARÂMETROS DA SIMULAÇÃO
% =========================================================

Ts = 0.01;         % Passo de simulação
t_final = 5;       % Tempo total

t = 0:Ts:t_final;

N = length(t);

% =========================================================
% VARIÁVEIS
% =========================================================

Vpv = zeros(1,N);
Ipv = zeros(1,N);
Ppv = zeros(1,N);

Erro = zeros(1,N);
dErro = zeros(1,N);

Duty = zeros(1,N);

% Potência máxima teórica
Pmax_teorica = zeros(1,N);

% Eficiência do rastreamento
eficiencia = zeros(1,N);

% Duty inicial
Duty(1) = 0.5;

% Irradiância variável
G = ones(1,N) * 1000;

% Degrau de irradiância
G(t > 2.5) = 700;

% =========================================================
% LOOP PRINCIPAL
% =========================================================

for k = 2:N

    % =====================================================
    % POTÊNCIA MÁXIMA TEÓRICA
    % =====================================================

    Pmax_teorica(k) = Pmax_nominal * (G(k)/1000);

    % =====================================================
    % MODELO SIMPLIFICADO DO PAINEL FV
    % =====================================================

    % Relação simplificada entre duty e tensão
    Vpv(k) = Voc * (1 - Duty(k-1));

    % Corrente proporcional à irradiância
    Ipv(k) = (G(k)/1000) * Isc * ...
             (1 - (Vpv(k)/Voc));

    % Potência
    Ppv(k) = Vpv(k) * Ipv(k);

    % =====================================================
    % CÁLCULO DO ERRO
    % =====================================================

    dP = Ppv(k) - Ppv(k-1);
    dV = Vpv(k) - Vpv(k-1);

    % Evita divisão por zero
    if abs(dV) < 1e-6
        dV = 1e-6;
    end

    Erro(k) = dP / dV;
    dErro(k) = Erro(k) - Erro(k-1);

    % =====================================================
    % NORMALIZAÇÃO
    % =====================================================

    E  = max(min(Erro(k)/100,1),-1);
    DE = max(min(dErro(k)/100,1),-1);

    % =====================================================
    % FUZZIFICAÇÃO
    % Conjuntos:
    % NB = Negativo Grande
    % NS = Negativo Pequeno
    % ZE = Zero
    % PS = Positivo Pequeno
    % PB = Positivo Grande
    % =====================================================

    % Funções de pertinência triangulares

    mu_E_NB = trimf(E,[-1 -1 -0.5]);
    mu_E_NS = trimf(E,[-1 -0.5 0]);
    mu_E_ZE = trimf(E,[-0.5 0 0.5]);
    mu_E_PS = trimf(E,[0 0.5 1]);
    mu_E_PB = trimf(E,[0.5 1 1]);

    mu_DE_NB = trimf(DE,[-1 -1 -0.5]);
    mu_DE_NS = trimf(DE,[-1 -0.5 0]);
    mu_DE_ZE = trimf(DE,[-0.5 0 0.5]);
    mu_DE_PS = trimf(DE,[0 0.5 1]);
    mu_DE_PB = trimf(DE,[0.5 1 1]);

    % =====================================================
    % BASE DE REGRAS FUZZY
    % =====================================================

    % Regras simplificadas

    regra1 = min(mu_E_PB, mu_DE_PB);
    regra2 = min(mu_E_PS, mu_DE_PS);
    regra3 = min(mu_E_ZE, mu_DE_ZE);
    regra4 = min(mu_E_NS, mu_DE_NS);
    regra5 = min(mu_E_NB, mu_DE_NB);

    % =====================================================
    % SAÍDAS LINGUÍSTICAS
    % =====================================================

    % Grande aumento = +0.02
    % Pequeno aumento = +0.01
    % Zero = 0
    % Pequena redução = -0.01
    % Grande redução = -0.02

    numerador = ...
        regra1*(0.02) + ...
        regra2*(0.01) + ...
        regra3*(0.00) + ...
        regra4*(-0.01) + ...
        regra5*(-0.02);

    denominador = ...
        regra1 + regra2 + regra3 + regra4 + regra5;

    % =====================================================
    % DEFUZZIFICAÇÃO
    % Método Centroide simplificado
    % =====================================================

    if denominador == 0
        deltaDuty = 0;
    else
        deltaDuty = numerador / denominador;
    end

    % =====================================================
    % ATUALIZAÇÃO DO DUTY CYCLE
    % =====================================================

    Duty(k) = Duty(k-1) + deltaDuty;

    % Limites físicos
    Duty(k) = max(min(Duty(k),0.95),0.05);

    % =====================================================
    % EFICIÊNCIA MPPT
    % =====================================================

    if Pmax_teorica(k) > 0
        eficiencia(k) = ...
            (Ppv(k)/Pmax_teorica(k))*100;
    end

end

% =========================================================
% RESULTADOS PRINCIPAIS
% =========================================================

figure;

subplot(3,1,1)
plot(t,Ppv,'LineWidth',1.5)
grid on
ylabel('Potência (W)')
title('Potência Fotovoltaica')

subplot(3,1,2)
plot(t,Vpv,'LineWidth',1.5)
grid on
ylabel('Tensão (V)')
title('Tensão do Painel')

subplot(3,1,3)
plot(t,Duty,'LineWidth',1.5)
grid on
ylabel('Duty Cycle')
xlabel('Tempo (s)')
title('Controle MPPT Fuzzy')

% =========================================================
% COMPARAÇÃO:
% POTÊNCIA FUZZY x POTÊNCIA MÁXIMA TEÓRICA
% =========================================================

figure;

plot(t,Ppv,'b','LineWidth',2)
hold on

plot(t,Pmax_teorica,'r--','LineWidth',2)

grid on

xlabel('Tempo (s)')
ylabel('Potência (W)')

title('MPPT Fuzzy x Potência Máxima Teórica')

legend('Potência Rastreamento Fuzzy', ...
       'Potência Máxima Teórica', ...
       'Location','best')

% =========================================================
% GRÁFICO DE EFICIÊNCIA
% =========================================================

figure;

plot(t,eficiencia,'LineWidth',2)

grid on

xlabel('Tempo (s)')
ylabel('Eficiência (%)')

title('Eficiência do Rastreamento MPPT Fuzzy')

ylim([0 110])

% =========================================================
% CURVA P-V COMPARATIVA
% =========================================================

V = linspace(0,Voc,300);

I = Isc * (1 - (V/Voc));

P = V .* I;

figure;

plot(V,P,'LineWidth',2)
hold on

% Ponto máximo teórico
plot(Vmp,Pmax_nominal,'ro', ...
    'MarkerSize',10, ...
    'LineWidth',2)

% Ponto operacional final do fuzzy
plot(Vpv(end),Ppv(end),'ks', ...
    'MarkerSize',10, ...
    'LineWidth',2)

grid on

xlabel('Tensão (V)')
ylabel('Potência (W)')

title('Curva P-V do Painel Fotovoltaico')

legend('Curva P-V', ...
       'Ponto Máximo de Potência', ...
       'Ponto Operacional Fuzzy', ...
       'Location','best')

% =========================================================
% FUNÇÃO TRIANGULAR
% =========================================================

function mu = trimf(x, params)

a = params(1);
b = params(2);
c = params(3);

if x <= a

    mu = 0;

elseif x >= c

    mu = 0;

elseif x == b

    mu = 1;

elseif x > a && x < b

    mu = (x-a)/(b-a);

else

    mu = (c-x)/(c-b);

end

end
