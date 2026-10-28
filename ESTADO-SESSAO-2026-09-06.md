# Estado da sessão — 06/09/2026

Retomada do Trabalho 01 depois da troca de indicador (RSI → DMI/ADX).
Este arquivo existe para retomar a conversa sem perder contexto.

---

## ✅ Bug do lado armado: CORRIGIDO e remedido

Encontrado por leitura de código, **reproduzido em diário real** e corrigido.

### O que era

`g_lado_armado` é estado com validade **de pregão**, mas o único ponto que o
limpava estava dentro de `SinalAtual()` — e os passos 1, 2 e 5 do `OnTick`
(fechamento, trava diária, fora da janela) dão `return` antes de chegar lá.

**Evidência real, não teórica** (diário `t_base_operacao.txt` antigo):

- `ARMADO 2026.03.20 16:30` → `SINAL 2026.03.23 09:15` — armou na sexta,
  entrou na segunda, **3 dias depois** do cruzamento
- `ARMADO 2026.04.07 16:30` → `SINAL 2026.04.08 09:15`

A assinatura aparecia em 5 dos 6 diários.

### A correção

Uma só, em `AtualizarDia()` — a função que já detecta a virada de pregão e
roda na primeira linha do `OnTick`. Desarmar ali cobre os três caminhos de uma
vez, em vez de remendar os três `return`, e não depende de alguém lembrar de
repetir o remendo num `return` futuro. Compila **0 errors, 0 warnings**.

### Verificação

No diário novo do teste base, `[SINAL]` caiu de **23 para 21** — exatamente as
duas entradas fantasma, nenhuma outra mudança. As 7 linhas novas
`[DESARMADO] ... pregão anterior` aparecem às 09:00/09:03, **antes** de a janela
abrir às 09:15.

⚠️ **Cuidado ao reauditar:** um detector ingênuo que só compara datas de
`[ARMADO]` e do evento seguinte continua acusando 7 casos. Não são o bug — são
a própria correção agindo. Filtre as linhas `pregão anterior`.

---

## O robô, como está hoje

**`MQL5/Experts/Robo_ADX_WIN.mq5`** — estratégia "ADX Bússola".
Compila com `0 errors, 0 warnings`. `Robo_RSI_WIN.mq5` continua intacto ao lado,
como plano B.

### Regra de entrada

Cruzamento de DI+ × DI− na barra fechada (deslocamentos 1 e 2):

- **Compra:** `DI+[2] <= DI-[2]` e `DI+[1] > DI-[1]`
- **Venda:** `DI-[2] <= DI+[2]` e `DI-[1] > DI+[1]`

Um indicador só: `iADX` entrega ADX, DI+ e DI− nos buffers 0, 1 e 2 do **mesmo
handle**. Não existe média móvel no código (verificado por `grep`).

### Confirmação de força — e por que ela é ADIADA

O ADX é a média suavizada do `DX = |DI+ − DI−| / (DI+ + DI−)`. No instante do
cruzamento as duas linhas se tocam, `DX ≈ 0` e o **ADX está caindo**. Um ADX
ainda alto naquela barra é resíduo da tendência anterior, não força da nova.

Exigir "cruzou **e** ADX ≥ 25 na mesma barra" seleciona, na prática, reversões
de tendências fortes — o oposto do que a estratégia quer. Por isso o robô arma
o lado no cruzamento e só entra quando o ADX volta a **subir** acima do limiar.

Não ficou na teoria: **cinco dos seis melhores candidatos da otimização têm a
confirmação ligada.**

### Parâmetros entregues (padrões compilados)

| Parâmetro | Valor |
|---|---|
| `InpDMIPeriodo` | 12 |
| `InpUsarConfirmacaoADX` | true |
| `InpADXMinimo` | 25,0 — **travado, fora da otimização** |
| `InpBarrasConfirmacao` | 1 |
| `InpStopLoss` / `InpTakeProfit` | 150 / 375 pontos |
| `InpLote` | 1 contrato |
| `InpHoraInicio` / `Fim` / `Fechamento` | 09:15 / 16:30 / 17:30 |
| `InpGanhoMaxDia` / `InpPerdaMaxDia` | R$ 500 / R$ 300 |
| `InpMagic` | **20262** (era 20261 no robô de RSI) |

14 parâmetros em 6 grupos.

---

## Resultados medidos (remedidos após a correção)

| Período | Lucro | Fator de lucro | Negócios | Acerto | Rebaix. máx |
|---|---|---|---|---|---|
| **2024–2026** | **+973,00** | **1,17** | 296 (154C/142V) | 33,78% | 555,00 (0,55%) |
| 2024 | +520,00 | 1,27 | 104 | 35,58% | 555,00 (0,55%) |
| 2025 | +290,00 | 1,14 | 109 | 33,94% | 332,00 (0,33%) |
| 2026 (**fora da busca**) | +159,00 | 1,10 | 81 | 30,86% | 330,00 (0,33%) |
| WINV26 jun–ago/2026 | +225,00 | 1,68 | 20 | 45,00% | 120,00 (0,12%) |

### O que a correção custou, e por que dizer isso na defesa

O bug **estava ajudando o resultado**. As 16 entradas fantasma removidas
(312 → 296) eram lucrativas no conjunto: PF caiu de 1,22 para **1,17** e o
lucro de 1.333 para 973.

| | com o bug | corrigido |
|---|---|---|
| PF 2024–2026 | 1,22 | **1,17** |
| Negócios | 312 | 296 |
| 2024 / 2025 / 2026 | 1,19 / 1,26 / 1,21 | **1,27 / 1,14 / 1,10** |

**Continua positivo nos três anos**, e 2024 até melhorou (1,19 → 1,27) — sinal
de que o efeito era ruído, não vantagem. O equilíbrio compra/venda sobreviveu
(154 × 142), que é o requisito da seção 3 item 3.

**Este é um bom ponto de defesa, não uma fraqueza:** achar um bug que
*inflava* o próprio resultado e corrigi-lo mesmo assim é exatamente o método
que a lição do trabalho descreve — conferir o resultado contra os requisitos
em vez de contra a métrica.

**Comparação com o robô de RSI entregue:** PF 1,29. O DMI é pior, e agora por
uma margem maior. Vale dizer isso se a banca comparar.

## O teto é ~1,2, e foi verificado

Três frentes de busca, ~500 configurações, todas sobre 2024–2025 com validação
em 2026. **Nada bateu 1,22.**

1. **Grade estendida.** O primeiro vencedor saiu com SL e TP no piso do
   intervalo testado — sinal de que o ótimo poderia estar fora. Refiz descendo
   até SL 50 / TP 150. Melhor com amostra decente: **1,16**. Não havia nada do
   outro lado da borda.
2. **Timeframes.** M15 22% das configurações lucrativas (mediana 0,92);
   M30 21% (0,93); **H1 49% (0,99)**. O H1 tem vantagem mais **espalhada**, mas
   58 negócios em dois anos é amostra insuficiente. M15 foi escolhido por
   amostra, não por desempenho.
3. **Vizinhança do vencedor — é platô.** TP 325/350/375 e SL 150/175 dão todos
   ~1,2 nos três anos. Só SL 125 quebra (0,91 em 2025): **há um piso real de
   stop perto de 150 pontos**, abaixo do qual o ruído do WIN estopa a operação
   antes de a tendência andar.

**Pico é ruído:** o maior PF da busca inteira foi 1,97 — com **22 negócios**.
Mesmo fenômeno do 1,56 falso do RSI.

⚠️ **Ressalva honesta:** as ~500 configurações foram medidas **com o bug do
lado armado presente**. A conclusão "o teto é ~1,2" continua valendo (o
candidato escolhido caiu de 1,22 para 1,17, ou seja, na mesma faixa), mas o
*ranking* entre configurações pode ter mudado. Refazer a busca inteira custa
horas e **não rende nenhum ponto na nota** — ver o lembrete de prioridade
abaixo. Se a banca perguntar, a resposta certa é esta ressalva, não fingir que
a busca foi feita no código corrigido.

---

## Auditoria de custos (refeita com os números corrigidos)

**O backtest roda sem custo nenhum.** Verificado por dois caminhos: spread `0`
nos três símbolos lido direto do terminal, e a aritmética dos relatórios (lucro
bruto + perda bruta bate exatamente com o líquido). 1 ponto = R$ 0,20/contrato.

Vantagem da estratégia: **R$ 3,29 por negócio** (era R$ 4,27 antes da correção).

| Custo por negócio (ida+volta) | PF | Lucro |
|---|---|---|
| R$ 0,00 (o que os relatórios mostram) | 1,17 | +973 |
| R$ 1,00 | 1,11 | +677 |
| R$ 2,00 | 1,06 | +381 |
| **R$ 3,29** | **1,00** | **0** |

**Esta é a consequência mais séria da correção.** A folga de custo encolheu 23%.
Com custo realista entre R$ 1,00 e R$ 2,50, o PF real cai para algo entre
**1,04 e 1,11** — antes era 1,10 a 1,15. A vantagem ainda existe, mas é fina, e
é honesto apresentá-la assim.

**Ressalva:** este robô é bem mais sensível a custo que o de RSI, que rendia
R$ 10,63 por negócio. Consequência de virar sistema de tendência com stop curto.

---

## Apresentação — refeita em 06/09/2026

**`Apresentacao/Slides_CataVento.html`** (+ `.pdf`, 10 lâminas). O nome antigo
`Slides_Pendulo.*` saiu; as referências no `CLAUDE.md` foram atualizadas.
O `Slides_Pendulo.pdf` antigo ficou na pasta, junto com o `Robo_RSI_WIN.mq5`,
como plano B.

**Nome: ADX Cata-vento.** Gira para mostrar de onde vem o vento (o cruzamento
DI+ × DI− dá a direção) e só gira quando há vento (o ADX dá a força). Inverte a
metáfora antiga: o pêndulo volta ao centro, o cata-vento vai com o fluxo.
Descartado "ADX Bússola" — bússola aponta sempre para o mesmo norte, o oposto
do que o robô faz. Descartado "ADX Biruta": é a melhor imagem (mostra direção e
intensidade no mesmo objeto) mas "biruta" também quer dizer doido.

### O roteiro das 10 lâminas

| # | Assunto |
|---|---|
| 1 | Capa |
| 2 | **O ADX sozinho não constrói robô nenhum** — mede força sem direção; quem separa compra de venda é DI+ e DI−. Gráfico de dados reais |
| 3 | **O cruzamento arma. A força dispara.** — regras + por que a confirmação é adiada |
| 4 | Os 14 parâmetros na janela de propriedades |
| 5 | Duas velocidades no `OnTick` |
| 6 | **Positivo em todos os períodos medidos** — 1,68 · 1,27 · 1,14 · 1,10 · 1,17 |
| 7 | **O 1,97 que não existia** — pico com 22 negócios |
| 8 | **O bug que estava me ajudando** — achado, medido, corrigido mesmo custando 0,05 |
| 9 | **R$ 3,29 por negócio** — auditoria de custo |
| 10 | Agradecimento |

O slide 6 segue a progressão que a Luisa propôs: contrato do enunciado → ano a
ano → global. Constrói o argumento de **consistência** (positivo em 5 de 5) em
vez de apostar num número só. Traz de propósito a ressalva de que os anos
descem (1,27 · 1,14 · 1,10) e de que 2026 é parcial — para não ser pega de
surpresa na banca.

O gráfico do slide 2 é SVG de **dados reais**, gerado por
`MQL5/Scripts/ExportarBarrasDMI.mq5` (novo, compila 0/0) via
`config/exportar_dmi.ini`. Mostra uma venda de 07/08/2026: DI− cruza DI+ com o
ADX em 21,3 (abaixo do limiar), o ADX sobe para 28,7 duas barras depois, entra
vendido, e o preço anda 2.830 pontos.

### ⚠️ Cuidado ao comparar com o robô de RSI

O **2,01 do RSI era WINV26, 27 negócios, três meses.** O número honesto do RSI
na série contínua era **1,29**. A comparação justa é:

| | RSI Pêndulo | ADX Cata-vento |
|---|---|---|
| WINV26 (~20 negócios) | 2,01 | 1,68 |
| Série contínua (~290 negócios) | 1,29 | 1,17 |

A queda real é 1,29 → 1,17. Não confundir com "caiu de 2,01 para 1,17".

---

## Documentos refeitos nesta sessão

- **`Testes/RESULTADOS.md`** — reescrito do zero para o DMI
- **`Testes/CHECKLIST.md`** — 13 casos **re-executados** no robô novo, nada
  herdado do RSI. Diários novos em `Testes/Diarios/`
- Apagado `Testes/Diarios/t11a_niveis_invertidos.txt` (testava níveis de RSI)

Dois casos precisaram de ajuste de método, documentado nos dois:
- **Trava de perda:** limite baixado para R$ 25, porque com ~1 negócio a cada
  dois pregões e SL de R$ 30, duas perdas no mesmo dia quase nunca acontecem
- **Encerramento por horário:** rodado com SL 3000 / TP 5000, porque com os
  stops de produção a posição sempre fecha antes das 17:30

Ganhos sobre o checklist antigo: caso 11 foi de 5 para 6 validações; caso 13 de
4 para 5 motivos de recusa; casos 3 e 4 ficaram mais fortes (simetria virou
propriedade da regra, e agora é um indicador só no código).

---

## Limpeza do material de RSI — feita em 06/09/2026

A pedido da Luisa, **56 itens do robô de RSI foram para a Lixeira** (não
apagados — recuperáveis): os 28 relatórios e 20 PNGs de agosto em
`Testes/`, o `Robo_RSI_WIN.mq5`/`.ex5`, o `ExportarBarrasRSI.mq5`, o
`Slides_Pendulo.pdf`, os três arquivos de RSI dentro de `Entrega/` e o zip
antigo.

⚠️ **Consequência a saber:** não existe mais plano B no repositório. Se algo
der errado com o Cata-vento antes da apresentação, o robô de RSI só volta pela
Lixeira.

**Descoberta durante a limpeza:** o `Testes/medicao_adx_por_negocio.csv`, citado
duas vezes no `CLAUDE.md` como evidência das 1.129 entradas, **não existia no
disco**. Era material do robô de RSI; as citações foram removidas.

## Entrega refeita

`Entrega/Trabalho01_LuisaCaetanoAraujo.zip` — 16 arquivos, todos do Cata-vento:

- `Robo_ADX_WIN.mq5`
- `Apresentacao_ADX_CataVento.pdf` (10 lâminas)
- `Parametros_ADX_CataVento.set` (cópia byte a byte do `.set` que o tester usou)
- `LEIA-ME.txt` reescrito
- `Evidencias/` — 5 relatórios e 5 gráficos, gerados em 06/09 às 15:22

Atende ao item 11 do enunciado (capturas do Strategy Tester, relatório e
gráfico de resultados).

## Próximos passos, em ordem

1. ~~Corrigir o bug do lado armado e remedir tudo~~ — **FEITO em 06/09/2026.**
   PF 1,22 → **1,17**, 312 → 296 negócios. Tabelas acima já atualizadas.
2. ~~Re-executar os 13 casos do CHECKLIST~~ — **FEITO.** 11 diários regravados.
3. ~~Atualizar `Testes/RESULTADOS.md`~~ — **FEITO.**
4. ~~Refazer os slides~~ — **FEITO.**
5. ~~Atualizar o `CLAUDE.md`~~ — **FEITO.**
6. ~~Refazer o zip de entrega~~ — **FEITO.**
7. **Ensaiar os dois itens ao vivo** — janela de propriedades (item 14, 25
   pontos) e demonstração no tester (item 15). **É o único item que sobra,
   e vale 40 dos 100 pontos.**

### Do enunciado, coisas que não estavam registradas em lugar nenhum

- Seção 8 item 10: **"5 a 10 lâminas"**. O deck tem 10 — está no teto.
- Seção 8 item 11: evidências dos testes são **entregável obrigatório**
  (relatório e gráfico de resultados). Atendido.
- Seção 10: o critério de desempate premia **entrega com maior antecedência**.
  Entregar cedo vale ponto.
- Seção 5: o ADX está nominalmente na lista de indicadores adequados.

**Lembrete de prioridade:** nenhum ponto da nota depende de o robô dar lucro, e
40 dos 100 pontos só existem ao vivo. Ensaiar rende mais que otimizar.

---

## Armadilhas operacionais desta sessão

- **Não rodar o tester com o MT5 aberto na interface.** A segunda instância
  morre em silêncio e o relatório sai com **zero barras e zero negócios**.
  Aconteceu uma vez aqui.
- **Não usar `pkill -f terminal64.exe` em script**, que foi o que fechou o MT5
  da Luisa sem aviso.
- Relatórios do tester saem em **UTF-16LE**; otimização gera `.xml`
  (SpreadsheetML), teste único gera `.htm`.
- Logs do tester ficam em `Tester/Agent-*/logs/AAAAMMDD.log`.

### Comandos

```bash
export WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
export DYLD_FALLBACK_LIBRARY_PATH="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/lib/external:/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/lib:/usr/lib"
cd "$WINEPREFIX/drive_c/Program Files/MetaTrader 5"

# compilar
"/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine" metaeditor64.exe \
  /portable "/compile:MQL5\Experts\Trabalho01\Robo_ADX_WIN.mq5" /log
iconv -f UTF-16LE -t UTF-8 "MQL5/Experts/Trabalho01/Robo_ADX_WIN.log" | tr -d '\r' | tail -3

# backtest headless
"/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine" terminal64.exe \
  /portable "/config:config\bussola_otim.ini"
```
