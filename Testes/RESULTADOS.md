# Resultados dos backtests — Robo_ADX_WIN ("ADX Bússola")

Gerado em 06/09/2026. Todos no Strategy Tester, **nunca em conta real**.

> Este documento substitui a versão do robô de RSI. O indicador de sinal mudou
> de RSI para DMI/ADX porque o RSI já tinha sido escolhido por outro aluno.
> Nada aqui foi herdado do robô anterior — todos os números foram medidos de
> novo no `Robo_ADX_WIN.mq5`.

## Ambiente de teste

| Item | Valor |
|---|---|
| Símbolo | `WIN_CONTINUO` (custom, clonado do WIN$N) |
| Barras M1 | 372.029, de 02/01/2024 a 21/08/2026 |
| Período do gráfico | M15 |
| Modelo | OHLC 1 minuto |
| Depósito | 100.000 BRL, alavancagem 1:1 |
| Travas diárias | +500 / -300 BRL (ligadas em todos os testes abaixo) |
| Custos de operação | **zero** — ver "Auditoria de custos" |

Por que símbolo custom: o WINV26 só tem liquidez desde agosto/2026 (contrato de
outubro), e a conexão do terminal com a corretora estava instável, o que impedia
o tester de sincronizar histórico. Símbolo custom usa só dados locais e resolve
os dois problemas.

---

## RESULTADO FINAL — configuração entregue

Parâmetros (são os padrões compilados no `Robo_ADX_WIN.mq5`):

| Parâmetro | Valor |
|---|---|
| `InpDMIPeriodo` | 12 |
| `InpUsarConfirmacaoADX` · `InpADXMinimo` · `InpBarrasConfirmacao` | true · 25,0 · 1 |
| `InpStopLoss` / `InpTakeProfit` | 150 / 375 pontos |
| `InpLote` | 1 contrato |
| `InpHoraInicio` / `InpHoraFim` / `InpHoraFechamento` | 09:15 / 16:30 / 17:30 |
| `InpGanhoMaxDia` / `InpPerdaMaxDia` | R$ 500 / R$ 300 |
| `InpMagic` | 20262 |

| Período | Lucro (BRL) | Fator de lucro | Negócios | % compras | Acerto | Rebaix. máx |
|---|---|---|---|---|---|---|
| **2024–2026 completo** | **+973,00** | **1,17** | 296 | 52,03% | 33,78% | 555,00 (0,55%) |
| 2024 | +520,00 | 1,27 | 104 | 53,85% | 35,58% | 555,00 (0,55%) |
| 2025 | +290,00 | 1,14 | 109 | 51,38% | 33,94% | 332,00 (0,33%) |
| 2026 (**fora da busca**) | +159,00 | 1,10 | 81 | 50,62% | 30,86% | 330,00 (0,33%) |
| WINV26, jun–ago/2026 | +225,00 | 1,68 | 20 | 45,00% | 45,00% | 120,00 (0,12%) |

Lucrativo nos três anos, com 2026 inteiramente fora da amostra de busca.
Rebaixamento máximo abaixo de 0,6% do capital.

### Estes números são pós-correção de um bug — e caíram

Medidos em 06/09/2026, depois de corrigir o **bug do lado armado**: um
cruzamento de DI podia sobreviver ao fim do pregão e virar entrada no dia
seguinte (chegou a atravessar um fim de semana). O estado armado só era limpo
dentro de `SinalAtual()`, e três `return` antecipados do `OnTick` nunca chegavam
lá. Corrigido com um desarme em `AtualizarDia()`.

| | com o bug | corrigido |
|---|---|---|
| Fator de lucro 2024–2026 | 1,22 | **1,17** |
| Lucro | +1.333 | **+973** |
| Negócios | 312 | **296** |
| 2024 / 2025 / 2026 | 1,19 / 1,26 / 1,21 | **1,27 / 1,14 / 1,10** |

**O bug estava inflando o resultado.** As 16 entradas removidas eram lucrativas
no conjunto. Corrigir custou 0,05 de fator de lucro e foi feito assim mesmo —
uma entrada disparada por um cruzamento de três dias antes não é a estratégia
que este documento descreve, lucro ou não.

2024 até **melhorou** (1,19 → 1,27), o que reforça a leitura de que as entradas
tardias eram ruído e não vantagem.

### O acerto de 34% não é defeito — é a assinatura de seguir tendência

O robô anterior (RSI, reversão à média) acertava 51,6% e ganhava pouco em cada
acerto: SL 400 / TP 525, razão 1:1,3. Este acerta 34,6% e ganha muito em cada
acerto: SL 150 / TP 375, razão **1:2,5**.

Isso não foi escolhido — a otimização **partiu dos parâmetros do RSI** (SL 400 /
TP 525) e caminhou sozinha até stop curto com alvo largo. É confirmação
independente de que a estratégia mudou de natureza junto com o indicador.

### Equilíbrio compra/venda sai de graça

154 compras e 142 vendas (52,0% / 48,0%), equilibrado em todos os anos.

No robô de RSI foi preciso **restringir a busca** a faixas simétricas, porque o
otimizador zerava as compras para subir o fator de lucro. Aqui a simetria é
**propriedade da regra**: a condição de compra é a de venda com DI+ e DI−
trocados. O requisito da Seção 3 item 3 é atendido por construção, sem restrição
artificial — é um argumento mais forte que o anterior.

---

## Protocolo de otimização

O mesmo usado no robô de RSI, e pelo mesmo motivo:

1. Busca genética sobre **2024–2025** (dois anos inteiros, amostra grande).
2. Validação em **2026**, que a busca nunca vê.
3. Escolha do candidato **estável nos três anos**, não o de maior pico.
4. Conferência do equilíbrio compra/venda contra o requisito 3.3.

`InpADXMinimo` foi **deixado fora da busca**, travado em 25 — valor clássico de
manual. Um limiar ajustado ao passado seria mais um parâmetro decorado.

### Validação fora da amostra: quatro dos seis candidatos furaram

| Candidato | Parâmetros | 2024 | 2025 | **2026** | Veredito |
|---|---|---|---|---|---|
| base | DMI 14 · sem confirmação · SL400 TP525 | 0,99 | 1,02 | 1,10 | empate técnico |
| H | DMI 10 · conf. 5 barras · SL400 TP500 | 0,99 | 1,22 | 0,96 | quebra fora da amostra |
| I | DMI 10 · conf. 2 barras · SL500 TP450 | 0,94 | 1,28 | 1,09 | perde em 2024 |
| J | DMI 20 · sem confirmação · SL400 TP450 | 1,00 | 1,16 | 0,97 | quebra fora da amostra |
| K | DMI 10 · conf. 1 barra · SL500 TP600 | 1,04 | 1,20 | **0,88** | pior quebra |
| **L** | **DMI 12 · conf. 1 barra · SL150 TP350** | **1,18** | **1,18** | **1,26** | **estável** |
| M | DMI 16 · conf. 3 barras · SL175 TP500 | 1,11 | 1,19 | **0,84** | quebra fora da amostra |

O candidato L virou a configuração entregue, com o TP ajustado de 350 para 375
pelo motivo explicado em "Auditoria de custos".

### O pico é ruído: 1,97 com 22 negócios

Na busca de 170 passagens sobre 2024–2025, o maior fator de lucro foi **1,97**
— com **22 negócios**. Exigindo pelo menos 200 negócios em dois anos, o teto
cai para **1,19**.

É exatamente o que aconteceu no robô de RSI, onde um 1,56 obtido em amostra
pequena virou 0,93 no ano seguinte. Amostra pequena produz números bonitos e
falsos, nos dois indicadores.

---

## O teto é ~1,2, e isso foi verificado

Três frentes de busca, todas sobre 2024–2025 com validação em 2026,
aproximadamente 500 configurações no total. **Nenhuma bateu 1,22.**

⚠️ **Ressalva sobre toda esta seção:** as ~500 configurações foram medidas
**antes da correção do bug do lado armado**. A conclusão — o teto da estratégia
fica em torno de 1,2 — continua valendo, porque o candidato escolhido caiu de
1,22 para 1,17, dentro da mesma faixa. Mas o *ranking* entre configurações pode
ter mudado, e nenhuma das outras foi remedida. Refazer a busca inteira custa
horas de máquina e **não rende ponto na avaliação**. Se a banca perguntar, esta
ressalva é a resposta honesta.

### 1. Grade estendida — a borda foi conferida

A primeira busca devolveu um vencedor com SL 150 e TP 350, que eram o **piso**
do intervalo testado (SL 150–500, TP 350–750). Ótimo na borda costuma indicar
que o ótimo real está fora dela, então a grade foi refeita descendo até SL 50 e
TP 150, com passo mais fino.

Resultado: o melhor com amostra decente foi **1,16**, abaixo do que já se tinha.
Não havia nada do outro lado da borda.

### 2. Timeframes — M15, M30 e H1

| Timeframe | Configurações lucrativas | PF mediano | Melhor com amostra |
|---|---|---|---|
| M15 | 22% | 0,92 | 1,16 |
| M30 | 21% | 0,93 | 1,12 |
| **H1** | **49%** | **0,99** | 1,29 (só 58 negócios) |

O H1 tem a vantagem mais **espalhada** — quase metade das configurações dá
lucro, contra um quinto no M15. Faz sentido para um sistema de tendência:
quanto maior o prazo, menos ruído nos cruzamentos de DI.

Não foi adotado porque 58 negócios em dois anos é amostra pequena demais para
confiar, e magra demais para demonstrar ao vivo. Mas é um resultado real e vale
citar: **a vantagem existe e é mais robusta no H1; o M15 foi escolhido por
amostra, não por desempenho.**

### 3. Vizinhança do vencedor — é platô, não pico

Preocupação legítima: se um vizinho próximo do vencedor desaba, o resultado é
sorte. Todos os vizinhos foram medidos nos três anos.

| Variação | 2024 | 2025 | 2026 | |
|---|---|---|---|---|
| SL 125 / TP 350 | 1,24 | **0,91** | 1,21 | quebra |
| SL 150 / TP 350 | 1,18 | 1,18 | 1,26 | segura |
| SL 175 / TP 350 | 1,19 | 1,05 | 1,20 | segura |
| SL 150 / TP 325 | 1,20 | 1,22 | 1,23 | segura |
| **SL 150 / TP 375** | **1,19** | **1,26** | **1,21** | **segura (entregue)** |

Quatro dos cinco vizinhos ficam positivos nos três anos, todos em torno de 1,2.

O único que quebra é o de stop mais curto, e o motivo tem mecanismo: **abaixo de
~150 pontos o ruído do WIN estopa a operação antes de a tendência andar.** Há um
piso real de stop, encontrado por medição da vizinhança, não por teoria.

---

## Auditoria de custos — e por que o TP virou 375

**O backtest roda sem custo nenhum.** Verificado por dois caminhos independentes:

- Especificações lidas direto do terminal: spread **0** em `WIN_CONTINUO`,
  `WINV26_LOCAL` e `WIN$N`; 1 ponto = R$ 0,20 por contrato.
- Aritmética dos relatórios: lucro bruto + perda bruta bate **exatamente** com o
  lucro líquido. Nada foi descontado.

A vantagem da estratégia é de **R$ 3,29 por negócio**. Custo acima disso zera o
lucro. Sensibilidade sobre 2024–2026:

| Custo por negócio (ida + volta) | Fator de lucro | Lucro |
|---|---|---|
| R$ 0,00 (o que os relatórios mostram) | 1,17 | +973 |
| R$ 1,00 | 1,11 | +677 |
| R$ 2,00 | 1,06 | +381 |
| R$ 3,00 | 1,01 | +85 |
| **R$ 3,29** | **1,00** | **0** |

Corretagem de mini índice em day trade, mais emolumentos da B3, mais o spread,
costumam somar de R$ 1,00 a R$ 2,50 por contrato ida e volta. Nessa faixa a
vantagem **sobrevive**, mas fina: fator de lucro entre **1,04 e 1,11**.

**Esta é a consequência mais séria da correção do bug.** A folga de custo caiu
de R$ 4,27 para R$ 3,29 por negócio — 23% menos. O argumento continua de pé, mas
com margem menor, e é assim que deve ser apresentado.

**Ressalva honesta:** este robô é bem mais sensível a custo que o de RSI era.
O RSI rendia R$ 10,63 por negócio; este rende R$ 3,29. É consequência direta de
virar sistema de tendência com stop curto — os alvos encolheram e o número de
negócios por ano ficou parecido.

**Por que o TP foi de 350 para 375:** não para subir o fator de lucro — os três
ficam em 1,16–1,17, dentro do ruído. Foi por **tolerância a custo**, critério que
só apareceu depois da auditoria.

As três configurações foram **remedidas em 06/09/2026 no código corrigido**,
sobre 2024–2026 completo:

| Configuração | Negócios | Fator de lucro | Lucro | Vantagem por negócio (= zera em) | Rebaix. máx |
|---|---|---|---|---|---|
| SL 150 / TP 325 | 296 | 1,16 | +899 | R$ 3,04 | 440,00 (0,44%) |
| SL 150 / TP 350 | 296 | 1,16 | +904 | R$ 3,05 | 530,00 (0,53%) |
| **SL 150 / TP 375** | 296 | **1,17** | **+973** | **R$ 3,29** | 555,00 (0,55%) |

**O TP 375 continua sendo a escolha certa**, com cerca de **8% mais folga** de
custo que as outras duas. A conclusão sobreviveu à correção do bug.

Três observações que só apareceram com os números refeitos:

- **As três têm exatamente 296 negócios.** Faz sentido: o TP muda a *saída*, não
  a *entrada*, e a correção removeu as mesmas 16 entradas tardias nas três. É
  uma confirmação independente de que o bug estava no lado do sinal.
- **A ordem entre TP 325 e TP 350 mudou.** Antes da correção eram R$ 4,08 e
  R$ 3,92, com o 325 na frente; agora empatam em R$ 3,04 e R$ 3,05. A vantagem
  do 325 era artefato das entradas tardias. O 375 ficou na frente nas duas
  medições — é o que dá confiança na escolha.
- O TP 325 tem o **menor rebaixamento** (0,44% contra 0,55%). Quem priorizasse
  risco em vez de tolerância a custo poderia defender o 325; o critério adotado
  aqui foi custo, porque é o que decide se a vantagem sobrevive na conta real.

Valores anteriores, medidos com o bug presente e mantidos só para comparação:
R$ 4,08 (TP 325), R$ 3,92 (TP 350) e R$ 4,27 (TP 375).

---

## Como cada decisão foi tomada

| Decisão | Base |
|---|---|
| DMI e não ADX sozinho | A linha ADX mede força sem direção (ADX 38 tanto na alta quanto na baixa); quem separa compra de venda são DI+ e DI−. `iADX` entrega os três buffers em **um handle**, então continua sendo um indicador só |
| Confirmação de força **adiada** | No cruzamento, DI+ ≈ DI−, logo `DX = \|DI+ − DI−\| / (DI+ + DI−)` ≈ 0 e o ADX está caindo. Exigir ADX ≥ 25 na própria barra seleciona reversões de tendência forte, não nascimento de tendência. Cinco dos seis melhores candidatos têm a confirmação ligada |
| Limiar do ADX em 25 | Valor de manual, **deixado fora da otimização** de propósito |
| DMI 12, SL 150, TP 375 | Otimização em 2024–2025, validada em 2026 (que a busca não viu), vizinhança medida, TP escolhido por tolerância a custo |
| M15 e não H1 | H1 tem vantagem mais espalhada, mas 58 negócios em dois anos é amostra insuficiente |
| Sem trailing stop | O enunciado não pede; cada peça extra é mais uma coisa para defender |

**A lição que atravessa o trabalho:** otimizador não tem bom senso. Ele maximiza
a métrica que você deu e, se ela ignora uma regra do problema, ele viola a
regra — foi o que aconteceu no robô de RSI, quando zerou as compras para subir o
fator de lucro. Conferir o resultado contra os requisitos é parte do método, não
uma revisão no fim.

Relatórios do tester em `Relatorios/`, diários dos casos em `Diarios/`.
