# Laboratório de Regimes — contexto técnico

Ferramenta de backtest de estratégias cripto por regime de mercado. Uma página HTML única, sem servidor:
todo o cálculo roda no navegador, com os candles diários embutidos.

## Arquivos
- `template.html`: código-fonte da página (HTML, CSS e JS inline). O marcador `/*DATA*/` recebe os dados.
- `data/all.json`: `{BTCUSDT:[[dia,o,h,l,c],...], ETHUSDT:..., SOLUSDT:...}`. `dia` = dias desde 1970-01-01 (UTC).
  Candles diários da API pública da Binance (`https://data-api.binance.vision/api/v3/klines?interval=1d`),
  de 2018-08-31 (SOL desde 2020-08-11) até 2026-11-15.
- `data/<PAR>.json`: o mesmo, um arquivo por par.
- `build.sh`: injeta `data/all.json` no template e gera `laboratorio-regimes.html` (precisa só de `perl`).
- `laboratorio-regimes.html`: página pronta (≈586 KB). Já foi publicada como artifact no claude.ai (versão 5).

## Ambiente desta máquina
- Não há Python, Node nem Xcode Command Line Tools. Há `perl`, `jq`, `curl`, `ruby` 2.6 e `osascript`.
- Para testar a lógica sem navegador: extraia o `<script>` e rode com `osascript -l JavaScript` (JXA).
- Para ver a página: `ruby -run -e httpd -- --port=8765 <pasta>` e abra no navegador do app.
- `git` 2.39 funciona. Não há `gh` nem chave SSH.

## Como o motor funciona (template.html)
- **Regime** (`regimes()`): tendência = preço vs SMA(200) com faixa de ±5% e inclinação da SMA em 20 dias
  (alta, baixa, lateral). Volatilidade = vol. realizada de 30 dias vs mediana dos 365 dias anteriores.
  Usa só dados até o dia, sem olhar o futuro.
- **Estratégias** (`signals()`): buy & hold, cruzamento de SMAs, filtro de média, momentum (ROC), MACD,
  Donchian, reversão por RSI, reversão por Bollinger. Sinal no fechamento, posição a partir do dia seguinte.
- **Filtro de tendência** (`trendFilter()`): comprado só em alta, vendido só em baixa (se o short estiver
  ligado), fora na lateral (modo estrito) ou livre na lateral. Ligado por padrão.
- **Simulador** (`simulate()`): por operação, com custo por lado, stop e alvo checados pelo open/high/low
  do dia (gap → sai na abertura; stop e alvo no mesmo candle → conta o stop). Depois de stop ou alvo,
  espera o sinal sair daquele lado antes de reentrar.
- **Otimização de stop/alvo** (`optimize()`): grade de 13 stops × 16 alvos, só no treino, pelo critério
  "mais wins" (padrão, pedido pelo usuário), "melhor expectativa" ou "melhor Sharpe"; mínimo de 8 operações.
- **Treino/teste**: corte único (70/30 por padrão). A estratégia adaptativa usa, em cada regime,
  a vencedora do treino.
- Seções da página: resumo, preço com regimes, matriz estratégia × cenário, stop/alvo com mapa de calor,
  lista de entradas com filtro de período, curvas de capital, métricas, parâmetros.

## O que os testes mostraram
- "Mais wins" escolhe quase sempre alvo de 1% com stop de 10–15%: acerto de 75–95%, expectativa negativa.
  No BTC (teste), o cruzamento de médias cai de +12,8% para -3,4% ao ano com esses níveis.
- O corte único de treino/teste é frágil; por isso walk-forward é a próxima melhoria.

## Melhorias combinadas com o usuário (em ordem)
Status em 16/11/2026: 1 a 4 feitas e publicadas; 5 pendente (exige Python, ausente nesta máquina).
1. Walk-forward com várias janelas (implementação própria). **Feito.**
2. Saídas no estilo Freqtrade: trailing stop, stop por ATR, alvo que diminui com o tempo (tabela de ROI). **Feito** (stop móvel, stop por ATR, alvo decrescente).
3. Mais estratégias com indicadores (ADX, Supertrend, Ichimoku), por exemplo portando da `cinar/indicatorts` (MIT). **Feito** (ADX + DMI, Supertrend, Ichimoku; escritos das definições clássicas).
4. Regime por HMM, portando a lógica da `hmmlearn` (BSD-3). **Feito** (HMM gaussiano de 3 estados, Baum-Welch próprio, ajuste só antes do teste, filtragem para frente). Fora da amostra, os estados separam mais volatilidade do que direção; por isso a média móvel segue como padrão.
5. Validar o motor contra `kernc/backtesting.py` e baixar outras moedas e timeframes com `ccxt` (exigem Python).

Licenças: MIT/BSD podem ser adaptadas mantendo o aviso. GPL/AGPL (freqtrade, backtesting.py) só como
referência de ideias ou validação externa. Repositórios sem licença: só leitura.
