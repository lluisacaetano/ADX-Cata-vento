# Checklist de testes — Robo_ADX_WIN ("ADX Bússola")

Um caso por requisito do enunciado. **Todos re-executados em 06/09/2026, depois
da correção do bug do lado armado**, no `Robo_ADX_WIN.mq5`, no Strategy Tester,
nunca em conta real.

> Nenhum resultado foi herdado do robô de RSI, nem da rodada anterior à
> correção. Os diários em `Diarios/` foram todos regravados no código atual.

## Ambiente

| Item | Valor |
|---|---|
| Símbolo | `WIN_CONTINUO` (custom, clonado do WIN$N — 372.029 barras M1) |
| Período do gráfico | M15 |
| Modelo | OHLC 1 minuto |
| Depósito | 100.000 BRL, alavancagem 1:1 |
| Casos 5–9, 11, 12, 13 | março–abril/2026 (período curto, para o Diário ficar legível) |
| Casos 1–4, 10 | 2024–2026 completo |

Diários completos de cada caso em `Diarios/`. Relatórios em `Relatorios/`.

---

## 1. Compila sem erros nem avisos — Seção 3, item 1

- [x] **APROVADO** — `Result: 0 errors, 0 warnings, 1261 ms elapsed`

Compilado por linha de comando (MetaEditor headless). O mesmo aparece no
MetaEditor com F7.

## 2. Roda no ativo de referência — Seção 3, item 2

- [x] **APROVADO** — 296 negócios em `WIN_CONTINUO` (2024–2026) e 20 em
      `WINV26_LOCAL` (jun–ago/2026), M15

Ressalva honesta: a estatística principal usa a série contínua do mini índice,
não o contrato WINV26 diretamente, porque o V26 só tem liquidez desde
agosto/2026 (é o contrato de outubro) e não permite amostra estatística. O
WINV26 foi testado à parte e está na tabela de `RESULTADOS.md`.

## 3. Opera nos dois sentidos — Seção 3, item 3

- [x] **APROVADO** — 154 compras e 142 vendas (52,03% / 47,97%)

| Período | Compras | Vendas | Total |
|---|---|---|---|
| 2024 | 56 | 48 | 104 |
| 2025 | 56 | 53 | 109 |
| 2026 | 41 | 40 | 81 |
| WINV26 | 9 | 11 | 20 |

Equilíbrio em todos os períodos. **Diferença importante em relação ao robô de
RSI:** lá foi preciso restringir a busca a faixas simétricas, porque o
otimizador zerava as compras. Aqui a simetria é propriedade da regra — a
condição de compra é a de venda com DI+ e DI− trocados — e não precisou de
nenhuma restrição artificial.

## 4. Sinal vem do DMI, não de média móvel — Seção 3 item 4 e Seção 7

- [x] **APROVADO**

- `grep -E '\biMA\(|MODE_(SMA|EMA|SMMA|LWMA)|ENUM_MA_METHOD|iAMA|iDEMA|iTEMA|iFrAMA|iVIDyA'`
  no fonte: **nenhuma ocorrência**
- Indicador criado no EA: **um só**, `iADX` (linha 712). DI+, DI− e ADX saem dos
  buffers 1, 2 e 0 do mesmo handle
- Todo negócio no Diário é precedido de `[SINAL] COMPRA` ou `[SINAL] VENDA` com
  os valores de DI+, DI− e ADX:
  ```
  2026.03.02 12:15:00   [SINAL] COMPRA | DI+ 28.13 DI- 15.37 | ADX 28.31 subindo (anterior 28.12) | 1 barra(s) apos o cruzamento
  ```

## 5. Toda ordem tem Stop Loss e Take Profit — Seção 3, item 5

- [x] **APROVADO** — 21 de 21 ordens com SL e TP (`Diarios/t_base_operacao.txt`)

```
2026.03.02 12:15:00   COMPRA EXECUTADA | preco 192000 | lote 1.00 | SL 191850 (150 pts) | TP 192375 (375 pts)
2026.03.03 09:15:00   VENDA EXECUTADA | preco 188125 | lote 1.00 | SL 188275 (150 pts) | TP 187750 (375 pts)
```
Ordens sem stop ou sem alvo: **0**.

## 6. Trava diária de resultado — Seção 3, item 6

### 6a. Ganho máximo — `Diarios/t06a_trava_ganho.txt`

- [x] **APROVADO** (`InpGanhoMaxDia = 100`)
```
2026.03.16 12:05:40   TRAVA DIARIA | ganho maximo atingido: R$ 110.00 (limite R$ 100.00)
2026.04.01 15:17:40   TRAVA DIARIA | ganho maximo atingido: R$ 107.00 (limite R$ 100.00)
```

### 6b. Perda máxima — `Diarios/t06b_trava_perda.txt`

- [x] **APROVADO** (`InpPerdaMaxDia = 25`)
```
2026.03.02 12:15:40   TRAVA DIARIA | perda maxima atingida: R$ -30.00 (limite R$ -25.00)
2026.03.03 09:18:20   TRAVA DIARIA | perda maxima atingida: R$ -30.00 (limite R$ -25.00)
```

Nota de método: o limite precisou baixar para R$ 25 porque o robô faz cerca de
um negócio a cada dois pregões, e com SL de 150 pontos (R$ 30) duas perdas no
mesmo dia quase nunca acontecem. Com R$ 25, uma única perda já aciona a trava —
que é o que o caso precisa demonstrar.

### 6c. Fecha a posição aberta ao travar — `Diarios/t06a_*.txt` e `t06b_*.txt`

- [x] **APROVADO** — evidência agora vem dos próprios diários da trava, não do
      diário de encerramento
```
2026.03.16 12:05:40   POSICAO FECHADA | ticket 16 | motivo: ganho maximo diario
2026.04.01 15:17:40   POSICAO FECHADA | ticket 28 | motivo: ganho maximo diario
2026.03.02 12:15:40   POSICAO FECHADA | ticket 10 | motivo: perda maxima diaria
```

### 6d. Reset na virada do pregão

- [x] **APROVADO**
```
2026.03.03 09:02:00   === Novo pregao: 2026.03.03 | travas do dia liberadas ===
2026.03.04 09:00:00   === Novo pregao: 2026.03.04 | travas do dia liberadas ===
```

## 7. Parâmetros editáveis na janela de propriedades — Seção 3, item 7

- [x] **APROVADO** — os **14 parâmetros** aparecem no relatório do tester,
      organizados em 6 grupos

| Grupo | Parâmetros |
|---|---|
| Indicador (DMI / ADX) | `InpDMIPeriodo` |
| Confirmação de força (ADX) | `InpUsarConfirmacaoADX`, `InpADXMinimo`, `InpBarrasConfirmacao` |
| Gestão de risco | `InpLote`, `InpStopLoss`, `InpTakeProfit` |
| Horários | `InpHoraInicio`, `InpHoraFim`, `InpHoraFechamento` |
| Trava diária | `InpGanhoMaxDia`, `InpPerdaMaxDia` |
| Execução | `InpMagic`, `InpLogDetalhado` |

- [ ] **Pendente:** print da janela de propriedades do MetaTrader
      (`Evidencias/07-parametros.png`) — só existe na interface. **É este o
      item 14 da Seção 9, que vale 25 pontos na demonstração ao vivo.**

## 8. Horário de funcionamento — Seção 4

- [x] **APROVADO** — janela estreitada para 10:00–11:00
      (`Diarios/t08_janela_estreita.txt`)

Horário de **todas** as entradas do período: `10:30`. Nenhuma fora da janela.
Fora dela o Diário registra:
```
[RECUSA] fora da janela de horario de funcionamento
```

Nota de método: com a janela de uma hora só, o período rende **1 entrada**
(eram 3 antes da correção do lado armado). É a amostra mais fina do checklist,
e não é acidente: **foi neste caso que o bug batia mais forte.** Com a janela
aberta só das 10:00 às 11:00, quase toda barra caía fora dela, e o lado armado
atravessava a noite em vez de ser descartado — 2 das 3 entradas antigas vinham
de cruzamento de outro pregão. O que o caso precisa provar (nenhuma entrada
fora da janela) continua provado.

## 9. Horário de encerramento — Seção 4

- [x] **APROVADO** — 14 posições fechadas por horário
      (`Diarios/t09_encerramento.txt`)
```
2026.03.02 17:30:00   POSICAO FECHADA | ticket 2 | motivo: horario de encerramento
2026.03.09 17:30:00   POSICAO FECHADA | ticket 8 | motivo: horario de encerramento
```
Nenhuma posição atravessa o fim do pregão.

**Correção de um erro do checklist anterior:** a versão antiga afirmava 54
fechamentos. Esse número vinha de um `grep` por `horario de encerramento`, que
também casa com a linha `[RECUSA] fora do horario: passou do horario de
encerramento` — muito mais frequente. O contador certo é
`motivo: horario de encerramento`. No diário antigo o valor real já era 13, não
54. Não era efeito do bug: era contagem errada.

Nota de método: este caso usa SL 3000 / TP 5000 de propósito. Com os stops de
produção (150/375) a posição sempre bate alvo ou stop antes das 17:30, e o
encerramento por horário nunca chegaria a ser exercido.

## 10. Magic Number isola o robô — Seção 4 e boas práticas

- [x] **APROVADO** — `InpMagic = 20262` registrado no relatório; ordens marcadas
      com os comentários `DMI Compra` e `DMI Venda`

O Magic mudou de 20261 (robô de RSI) para 20262 de propósito: com o mesmo
número, um robô enxergaria as posições do outro como próprias.

No código, **toda** varredura de posição passa por `EhPosicaoPropria()`, que
exige `POSITION_MAGIC == InpMagic` **e** `POSITION_SYMBOL == _Symbol`.

- [ ] Teste manual pendente: abrir posição manual no mesmo gráfico e confirmar
      que o robô não a fecha. Só é verificável na interface.

## 11. Validação de parâmetros no OnInit — Seção 6, ponto extra

- [x] **APROVADO nos 6 casos** — o robô recusa iniciar e explica o motivo

| Caso | Diário | Mensagem |
|---|---|---|
| `InpDMIPeriodo = 1` | `t11a_dmi_invalido.txt` | "o periodo do DMI deve ser 2 ou maior" |
| `InpStopLoss = 0` | `t11b_stop_zero.txt` | "Stop Loss e Take Profit devem ser maiores que zero" |
| `InpHoraInicio = "9h15"` | `t11c_hora_malformada.txt` | "horario de inicio fora do formato HH:MM" |
| Fim 08:00 antes do início 09:15 | `t11d_fim_antes_inicio.txt` | "o horario de inicio deve ser anterior ao de fim" |
| `InpADXMinimo = 150` | `t11e_adx_fora_faixa.txt` | "o limiar do ADX deve ficar entre 0 e 100" |
| `InpBarrasConfirmacao = -1` | `t11f_barras_negativas.txt` | "as barras de confirmacao nao podem ser negativas" |

Todos retornam `INIT_PARAMETERS_INCORRECT`.

## 12. Avaliação na barra fechada — Seção 6, ponto extra

- [x] **APROVADO** — 21 de 21 entradas na abertura exata de uma barra M15

Horários distintos observados: `09:15`, `09:30`, `09:45`, `10:30`, `11:30`,
`11:45`, `12:00`, `12:15`, `12:30`, `13:30`, `14:30`, `14:45`, `15:15`, `16:00`,
`16:15`. Todos múltiplos de 15 com segundo `00`.

Entradas fora de múltiplo de 15 minutos ou com segundo diferente de zero: **0**.
É a prova direta da trava de nova barra.

## 13. Log do motivo de cada recusa — Seção 6, ponto extra

- [x] **APROVADO** — cinco motivos distintos registrados

```
[RECUSA] ADX 21.4 < 25.0: tendencia sem forca, entrada nao confirmada
[RECUSA] ADX 28.1 nao esta subindo (anterior 30.2): entrada nao confirmada
[RECUSA] fora da janela de horario de funcionamento
[RECUSA] fora do horario: passou do horario de encerramento
[RECUSA] ja existe posicao aberta deste robo
```

Os dois primeiros são novos em relação ao robô de RSI e mostram a confirmação de
força funcionando nas duas condições: força insuficiente e força não crescente.

---

## Resumo

**13 dos 13 casos aprovados por evidência automatizada**, todos regravados no
código já corrigido. Faltam apenas dois itens que só existem na interface do
MetaTrader:

- [ ] Print da janela de propriedades com os parâmetros (caso 7) — **vale 25
      pontos, é o item 14 da Seção 9**
- [ ] Teste de posição manual convivendo com o robô (caso 10)

Resultado da configuração entregue: **fator de lucro 1,17**, +973 BRL, 296
negócios, lucrativo em 2024, 2025 e 2026 — com 2026 inteiramente fora da amostra
de otimização. Detalhes e auditoria de custos em `RESULTADOS.md`.

### O que mudou nesta rodada, e por quê

Corrigido o bug do lado armado: um cruzamento podia sobreviver ao fim do pregão
e virar entrada no dia seguinte. Efeito no checklist:

| Caso | Antes | Depois |
|---|---|---|
| 2 — negócios | 312 / 21 | 296 / 20 |
| 3 — compras × vendas | 164 × 148 | 154 × 142 |
| 5 e 12 — ordens no período base | 23 | 21 |
| 8 — entradas na janela estreita | 3 | 1 |
| 9 — fechamentos por horário | 13 (não 54) | 14 |

O bug **inflava** o resultado: as entradas removidas eram lucrativas no
conjunto, e o fator de lucro caiu de 1,22 para 1,17. Corrigir mesmo assim é o
ponto de método a defender.

Os casos 1, 4, 7, 10 e 11 não dependiam do bug e passaram sem alteração de
conteúdo.
