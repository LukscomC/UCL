% =========================================================
% Melhorias implementadas:
% ✓ Modelo FV ajustado
% ✓ Curva P-V calibrada
% ✓ Fuzzy Gaussiano
% ✓ Incremental Conductance
% ✓ Filtro passa-baixa
% ✓ Ripple reduzido
% ✓ Região morta ampliada
% ✓ Oscilação minimizada
% =========================================================
clc;
clear;
close all;
% =========================================================
% DADOS DO PAINEL FV
% Canadian Solar CS6W-550MS
% =========================================================
Voc = 49.6;
Isc = 14.0;

Vmp = 41.7;
Imp = 13.2;

Pnom = Vmp*Imp;

% =========================================================
% CURVA P-V CALIBRADA
% =========================================================

Vtest = linspace(0,Voc,5000);

Itest = Imp .* ...
       (1 - (Vtest./Voc).^12);

Itest(Itest < 0) = 0;

Ptest = Vtest .* Itest;

Pmax_real = max(Ptest);

% =========================================================
% SIMULAÇÃO
% =========================================================

Ts = 1e-4;

t_final = 5;

t = 0:Ts:t_final;

N = length(t);

% =========================================================
% VARIÁVEIS
% =========================================================

Vpv = zeros(1,N);
Ipv = zeros(1,N);
Ppv = zeros(1,N);

Duty = zeros(1,N);

% Duty inicial próximo do MPP

Duty(1) = 0.16;

Erro = zeros(1,N);
dErro = zeros(1,N);

ErroFilt = zeros(1,N);
dErroFilt = zeros(1,N);

Ef = zeros(1,N);

Pmax_teorica = zeros(1,N);

% =========================================================
% PERFIL DE IRRADIÂNCIA
% =========================================================

G = ones(1,N)*1000;

G(t > 1) = 800;
G(t > 2) = 600;
G(t > 3) = 900;
G(t > 4) = 1000;

% =========================================================
% FILTRO
% =========================================================

alpha = 0.10;

% =========================================================
% LOOP PRINCIPAL
% =========================================================

for k = 2:N

    % =====================================================
    % MODELO FV
    % =====================================================

    Vpv(k) = Voc*(1 - Duty(k-1));

    Vpv(k) = max(min(Vpv(k),Voc),0);

    Ipv(k) = ...
        (G(k)/1000) * ...
        Imp * ...
        (1 - (Vpv(k)/Voc).^12);

    Ipv(k) = max(Ipv(k),0);

    Ppv(k) = Vpv(k)*Ipv(k);

    % =====================================================
    % POTÊNCIA MÁXIMA
    % =====================================================

    Pmax_teorica(k) = ...
        Pmax_real*(G(k)/1000);

    % =====================================================
    % INCREMENTAL CONDUCTANCE
    % =====================================================

    dP = Ppv(k) - Ppv(k-1);

    dV = Vpv(k) - Vpv(k-1);

    if abs(dV) < 1e-9
        dV = 1e-9;
    end

    Erro(k) = dP/dV;

    dErro(k) = Erro(k) - Erro(k-1);

    % =====================================================
    % FILTRO PASSA-BAIXA
    % =====================================================

    ErroFilt(k) = ...
        alpha*Erro(k) + ...
        (1-alpha)*ErroFilt(k-1);

    dErroFilt(k) = ...
        alpha*dErro(k) + ...
        (1-alpha)*dErroFilt(k-1);

    % =====================================================
    % NORMALIZAÇÃO
    % =====================================================

    maxErro = max(abs(ErroFilt(1:k)));

    if maxErro < 1e-6
        maxErro = 1;
    end

    E = ErroFilt(k)/maxErro;

    DE = dErroFilt(k)/maxErro;

    E = max(min(E,1),-1);

    DE = max(min(DE,1),-1);

    % =====================================================
    % FUNÇÕES GAUSSIANAS
    % =====================================================

    sigma = 0.22;

    E_N = gaussmf(E,sigma,-1);
    E_Z = gaussmf(E,sigma,0);
    E_P = gaussmf(E,sigma,1);

    DE_N = gaussmf(DE,sigma,-1);
    DE_Z = gaussmf(DE,sigma,0);
    DE_P = gaussmf(DE,sigma,1);

    % =====================================================
    % REGRAS FUZZY
    % =====================================================

    regras = [];
    saidas = [];

    % Aproxima do MPP

    regras(end+1) = min(E_P,DE_P);
    saidas(end+1) = +0.0002;

    regras(end+1) = min(E_P,DE_Z);
    saidas(end+1) = +0.0001;

    % Mantém próximo do MPP

    regras(end+1) = min(E_Z,DE_Z);
    saidas(end+1) = 0;

    % Afasta do MPP

    regras(end+1) = min(E_N,DE_N);
    saidas(end+1) = -0.0002;

    regras(end+1) = min(E_N,DE_Z);
    saidas(end+1) = -0.0001;

    % =====================================================
    % DEFUZZIFICAÇÃO
    % =====================================================

    numerador = sum(regras .* saidas);

    denominador = sum(regras);

    if denominador == 0

        deltaDuty = 0;

    else

        deltaDuty = numerador/denominador;

    end

    % =====================================================
    % REGIÃO MORTA
    % =====================================================

    if abs(E) < 0.08

        deltaDuty = 0;

    end

    % =====================================================
    % LIMITADOR
    % =====================================================

    deltaDuty = ...
        max(min(deltaDuty,0.0002),-0.0002);

    % =====================================================
    % DUTY CYCLE
    % =====================================================

    Duty(k) = Duty(k-1) + deltaDuty;

    Duty(k) = ...
        max(min(Duty(k),0.90),0.05);

    % =====================================================
    % EFICIÊNCIA
    % =====================================================

    Ef(k) = ...
        (Ppv(k)/Pmax_teorica(k))*100;

end

% =========================================================
% MÉTRICAS
% =========================================================

Ef_media = mean(Ef(round(N*0.3):end));

Ef_max = max(Ef);

fprintf('\n');

fprintf('=====================================\n');

fprintf('EFICIENCIA MEDIA = %.2f %%\n',Ef_media);

fprintf('EFICIENCIA MAX   = %.2f %%\n',Ef_max);

fprintf('=====================================\n');

% =========================================================
% GRÁFICO DE EFICIÊNCIA
% =========================================================

figure;

plot(t,Ef,'LineWidth',2)

grid on

xlabel('Tempo (s)')

ylabel('Eficiência (%)')

title('Eficiência MPPT Fuzzy')

ylim([80 101])

hold on

yline(95,'r--','95%')

yline(98,'g--','98%')

legend('Eficiência', ...
       '95%', ...
       '98%')

% =========================================================
% POTÊNCIA
% =========================================================

figure;

plot(t,Ppv,'b','LineWidth',2)

hold on

plot(t,Pmax_teorica,'r--','LineWidth',2)

grid on

xlabel('Tempo (s)')

ylabel('Potência (W)')

title('Potência MPPT x Potência Máxima')

legend('Potência MPPT', ...
       'Potência Máxima')

% =========================================================
% CURVA P-V
% =========================================================

figure;

plot(Vtest,Ptest,'LineWidth',2)

hold on

plot(Vpv(end),Ppv(end), ...
    'ro', ...
    'MarkerSize',10, ...
    'LineWidth',2)

grid on

xlabel('Tensão (V)')

ylabel('Potência (W)')

title('Curva P-V')

legend('Curva P-V', ...
       'Ponto Operacional')

% =========================================================
% DUTY CYCLE
% =========================================================

figure;

plot(t,Duty,'LineWidth',2)

grid on

xlabel('Tempo (s)')

ylabel('Duty Cycle')

title('Controle Duty Cycle')

% =========================================================
% FUNÇÃO GAUSSIANA
% =========================================================

function mu = gaussmf(x,sigma,c)

mu = exp(-((x-c).^2)/(2*sigma^2));

end
