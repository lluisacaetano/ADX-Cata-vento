# Trabalho 01 — ADX Cata-vento, robô de negociação em MQL5

**Estado em 08/09/2026: ENTREGUE.** O zip foi submetido e **não deve mais ser
alterado**: `Entrega/Trabalho01_LuisaCaetanoAraujo.zip`.

O que falta não é arquivo — são os dois itens ao vivo da apresentação.

Trabalho **individual** da disciplina *Modelagem e Projeto de Algoritmos para o
Mercado Financeiro* (Ciência da Computação).
Aluna: Luisa Caetano Araujo · Professor: Dr. Alexandre Pimenta.
Enunciado em `Documentacao/Trabalho-01.pdf`.

---

# NO DIA DA APRESENTAÇÃO — PASSO A PASSO

A seção 9 do enunciado tem cinco itens. **Três estão nos slides** (indicador,
regras, dificuldades). **Dois só existem ao vivo**, e valem 25 pontos diretos
mais boa parte dos 15 da defesa.

## Antes de começar — fazer ANTES, não na hora

1. **Feche qualquer MetaTrader aberto.** Duas instâncias fazem a segunda morrer
   em silêncio, e o teste sai com zero barras. Aconteceu três vezes durante o
   desenvolvimento.
2. Abra o MetaTrader normalmente.
3. Confirme que o robô aparece em **Navegador → Expert Advisors → Trabalho01 →
   `Robo_ADX_WIN`**.
4. Abra um gráfico de **WINV26**, período **M15**.

O `.set` já está nos dois lugares onde o MT5 procura:
`MQL5/Presets/` (botão Carregar da janela de propriedades) e
`MQL5/Profiles/Tester/` (Testador de Estratégia).

## Item 14 — demonstrar os parâmetros (25 pontos)

1. Arraste `Robo_ADX_WIN` do Navegador para o gráfico de WINV26 M15.
2. A janela abre na aba **Comum** — clique em **Parâmetros de Entrada**.
3. Se quiser garantir os valores: **Carregar** → `Parametros_ADX_CataVento.set`.

**É essa tela que vale os pontos.** São 17 parâmetros em 8 grupos.

**O que dizer** — não leia a lista, agrupe:

> "São 17 parâmetros em 8 grupos. O indicador tem dois: o período do DMI e o
> limiar de força. Depois vêm o modo de entrada, a gestão de risco, a trava no
> zero a zero, os horários, a trava diária e a execução. Todos editáveis aqui,
> sem tocar no código-fonte."

Depois aponte **um** parâmetro e explique o critério — isso mostra que você
decidiu, não só implementou:

> "O `InpADXMinimo` é 25. É o valor clássico da literatura e eu o deixei
> deliberadamente **fora de qualquer otimização** — limiar ajustado ao passado
> seria mais um parâmetro decorado."

**Se perguntarem sobre `InpUsarConfirmacaoADX` ou `InpBarrasConfirmacao`:**
o grupo deles se chama "Confirmação de força — SÓ no modo CRUZAMENTO" e cada um
tem o prefixo `[CRUZAMENTO]`. A resposta é:

> "Esses dois pertencem ao modo alternativo de entrada. Na configuração
> entregue, que usa o modo ESTADO, eles não têm efeito — ali a força já faz
> parte da própria condição de entrada, avaliada na mesma barra."

## Item 15 — demonstrar o funcionamento

Use **as duas formas**, nesta ordem:

**Primeiro o visual, para ver operando.** Ctrl+R abre o Testador. Aba
Configurações: Expert `Robo_ADX_WIN`, símbolo **WINV26**, período **M15**,
modelagem **OHLC de 1 minuto**, e marque **Visualização**. Rode e deixe o
gráfico correr — dá para ver as entradas aparecendo com stop e alvo. É o que
mais convence.

**Depois sem visual, para o número.** Desmarque Visualização, rode o período
**15/04/2026 a 08/09/2026** e mostre a aba **Resultados**: fator de lucro 1,36
e 533 operações, os mesmos do slide.

**Aponte também a aba Diário.** Cada recusa tem o motivo escrito — é boa prática
da Seção 6 e reforça a nota de qualidade de código.

## Os dois imprevistos possíveis, e o que dizer

**Se barras ou qualidade saírem diferentes do PDF:**

> "Barras e qualidade do histórico dependem da sincronização com a corretora e
> variam entre execuções. O resultado da estratégia — fator de lucro, número de
> operações e lucro — se manteve idêntico."

É verdade e foi medido: entre duas execuções o histórico mudou de 2.554 para
2.553 barras e de 57% para 55% de qualidade, e **os resultados não se moveram**.

**Se o WINV26 não carregar histórico:** existe `WINV26_LOCAL`, símbolo custom
clonado com os mesmos preços. Não é ideal (o cabeçalho mostra outro nome), mas é
melhor que travar.

## Nota de avaliação — onde estão os pontos

| Critério | Pontos | Onde se ganha |
|---|---|---|
| Funcionamento do robô | 30 | compila, anexa ao gráfico, abre e fecha operações |
| Parâmetros obrigatórios | 25 | **demonstração ao vivo** (item 14) |
| Uso do indicador e lógica | 15 | slides 2 e 3 |
| Qualidade do código | 15 | o `.mq5` |
| Apresentação e defesa | 15 | **ao vivo** |

**Nenhum ponto depende de o robô ser lucrativo.** Ensaiar rende mais que
otimizar.

---

## O robô, em uma página

**Nome: ADX Cata-vento.** Um cata-vento mostra continuamente de onde o vento
vem, e só se move quando há vento. É a descrição da regra: o DI dominante dá a
direção, o ADX dá a licença.

**Indicador: DMI/ADX, uma única chamada `iADX`.** Ela entrega ADX, DI+ e DI− nos
buffers 0, 1 e 2 do mesmo handle. Não existe outra chamada de indicador no
arquivo, e não existe nenhuma média móvel (`grep` dos 6 padrões: 0 ocorrências).

**Entrada — modo ESTADO (padrão):**

- Compra: `DI+ > DI−` **e** `ADX ≥ 25` **e** ADX subindo
- Venda: `DI− > DI+` **e** `ADX ≥ 25` **e** ADX subindo

Lido nas barras **1 e 2**, ambas fechadas.

**Modo alternativo CRUZAMENTO**, selecionável por `InpModoEntrada`: entra na
virada de DI+ e DI−, com o mecanismo de armar e confirmar.

**Saída:** Take Profit 375, Stop Loss 150, trava no zero a zero após 150 pontos
a favor, e encerramento às 17:30. Toda ordem sai com stop e alvo.

**Duas velocidades no `OnTick`:** proteção (encerramento, trava diária, trava no
zero a zero) roda a cada tick; a decisão de entrar roda só na barra fechada.

**Toda varredura de posição filtra por Magic Number E símbolo**
(`EhPosicaoPropria()`).

**O lado armado morre na virada do pregão** (`AtualizarDia()`). Sem isso um
cruzamento de sexta às 16:30 virava entrada na segunda.

---

## Resultado entregue

WINV26 · M15 · OHLC 1 minuto · 100.000 BRL sem alavancagem · 1 contrato ·
**15/04/2026 a 08/09/2026** (todo o histórico do contrato).

| | |
|---|---|
| Lucro | **+2.787,00 BRL** |
| Fator de lucro | **1,36** |
| Negociações | **533** — 278 compras, 255 vendas |
| Acerto | 50,84% |
| Rebaixamento máximo | 450,00 (0,44%) |
| Retorno por operação | R$ 5,23 |
| Barras / qualidade | 2.553 / 55% |

---

## As perguntas prováveis, e as respostas

**"O enunciado fala em um indicador. Você usou dois?"**
Não. `iADX` é **um** indicador — entrega as três linhas nos buffers 0, 1 e 2 do
mesmo handle. E a linha ADX isolada não constrói robô nenhum porque mede força
**sem direção**: medi no próprio WINV26 e há 29 barras em alta e 22 em baixa com
ADX ≈ 38. Quem separa compra de venda são DI+ e DI−. O ADX está nomeado na
lista da Seção 5 do enunciado.

**"Por que entrar por estado e não no cruzamento?"**
Foi medido, não suposto. Reconstruí o trajeto de cada operação no modo
cruzamento: **62% das perdedoras nunca chegaram a andar 100 pontos a favor**.
Faz sentido — o cruzamento é o instante em que as duas linhas se tocam, ou seja,
o ponto em que nenhum lado manda. No mesmo contrato e período: cruzamento dá
1,23 em 24 operações, estado dá 1,36 em 533.

**"Por que DMI 12?"**
O resultado não depende disso. Variando de 8 a 20 com todo o resto fixo, o fator
de lucro fica entre **1,24 e 1,42** — sete de sete, sem nenhum vale. Escolhi 12
por ter o **menor rebaixamento** da faixa (0,51%), não o maior fator de lucro
(que seria o DMI 20). O critério foi risco.

**"De onde veio a regra do modo estado?"**
Do artigo 10715 do MQL5, implementada como está publicada. Testei **quatro
combinações** (dois modos × trava ligada/desligada), não centenas.

**"E a validação fora da amostra?"**
Não existe para o WINV26, e não é escolha: contrato futuro vence e a corretora
não mantém no cadastro os contratos de 2024 e 2025. Não há outro período do
mesmo ativo para validar. O que fiz no lugar foi a varredura de robustez do
período do DMI, dentro do próprio contrato.

**A pergunta que eu faria, e que vale ponto:**
Durante a revisão achei um bug que **inflava meu próprio resultado** — o lado
armado por um cruzamento sobrevivia ao fim do pregão e podia disparar no dia
seguinte. Corrigir **piorou** o número. Corrigi assim mesmo: uma entrada
disparada por um cruzamento de três dias antes não é a estratégia que eu estou
apresentando, dando lucro ou não.

---

## Como compilar

Sem abrir o MetaEditor. As três partes são obrigatórias — faltando qualquer
uma, o comando sai com exit 0 **sem gerar `.ex5` nem log** (falha silenciosa):

1. `DYLD_FALLBACK_LIBRARY_PATH` apontando pras libs do Wine da MetaQuotes
2. a flag `/portable`
3. rodar **de dentro** da pasta do MT5, com caminho **relativo** no `/compile:`

```bash
export WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
export DYLD_FALLBACK_LIBRARY_PATH="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/lib/external:/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/lib:/usr/lib"
cd "$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
"/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine" metaeditor64.exe \
  /portable "/compile:MQL5\Experts\Trabalho01\Robo_ADX_WIN.mq5" /log
iconv -f UTF-16LE -t UTF-8 "MQL5/Experts/Trabalho01/Robo_ADX_WIN.log" | tr -d '\r' | tail -3
```

O log sai em **UTF-16LE**. Último resultado: **0 errors, 0 warnings**.

## Como rodar backtest headless

```bash
cd "$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
"/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine" terminal64.exe \
  /portable "/config:config\oficial_v2.ini"
```

O relatório sai como `<Report>.htm` na raiz do MT5, com os PNGs ao lado.

---

## ARMADILHAS — todas custaram tempo, nenhuma deve se repetir

**Não rode o tester com o MT5 aberto.** A segunda instância morre em silêncio e
o relatório sai com zero barras. Aconteceu três vezes.

**Não use `pkill -f terminal64.exe` em script.** Foi o que fechou o MT5 sem
aviso. Espere o processo sair, ou peça para fechar.

**`ToDate` corta o dia.** `ToDate=2026.09.04` exclui o pregão inteiro de 04/09 —
o MT5 lê como "até o início do dia". Isso gerou um relatório com 2.515 barras em
vez de 2.554 e números que não batiam com a execução pela interface. **Use data
final posterior ao último pregão desejado.**

**Sem `ExpertParameters` no `.ini`, o tester usa os últimos inputs em cache.**
Sempre passe o `.set` e confira no relatório quais parâmetros ele registrou.

**Crie os arquivos de configuração ANTES de qualquer verificação que possa
abortar o script.** Um `pgrep` no topo abortou a criação dos `.set` e `.ini`, e
o terminal foi lançado apontando para arquivos inexistentes — sem erro visível.

**Relatórios do tester referenciam os PNGs como arquivos externos.** Renomear os
PNGs quebra as imagens. A entrega usa gráficos **embutidos em base64**, então o
HTML é autocontido.

**O Chrome headless abre em 800px.** Medir altura de slide sem
`--window-size=1400,900` dá falso positivo de estouro em quase todas as lâminas.

**O histórico da corretora muda entre execuções.** Barras e qualidade variam;
os resultados de negociação, não.

---

## Estrutura

```
Entrega/Trabalho01_LuisaCaetanoAraujo.zip   <- ENTREGUE, não mexer
Entrega/Trabalho01_LuisaCaetanoAraujo/      os 9 arquivos
MQL5/Experts/Robo_ADX_WIN.mq5               fonte do EA (arquivo único)
MQL5/Scripts/CriarSimboloCustom.mq5         cria símbolos custom
MQL5/Scripts/ExportarBarrasDMI.mq5          exporta barras+DMI (gráfico do slide 2)
Apresentacao/Slides_CataVento.html          deck editável, com modo apresentação
Apresentacao/Slides_CataVento.pdf           9 lâminas, o que foi entregue
Testes/CHECKLIST.md                         13 casos (do robô anterior, desatualizado)
Testes/RESULTADOS.md                        histórico de candidatos (desatualizado)
Testes/Relatorios/WINV26_oficial.htm        o relatório entregue
Testes/Relatorios/WINV26_varredura_DMI.xml  a varredura de 8 a 20
Testes/Diarios/                             diários dos casos
Documentacao/Trabalho-01.pdf                enunciado
```

⚠️ `Testes/CHECKLIST.md` e `Testes/RESULTADOS.md` **não foram atualizados** para
a versão final (modo ESTADO, 533 operações). Eles descrevem o robô de cruzamento
com 24 operações. Não fazem parte da entrega, mas não sirva-se deles como
referência sem reler.

## Decisões que não devem ser refeitas

**O ATR foi implementado e removido.** Adicionava 4 parâmetros desligados e uma
segunda chamada de indicador, que enfraquecia o argumento de "um indicador só".
Remover não mudou nenhum número — regressão conferida.

**A trava no zero a zero sozinha PIORA o modo cruzamento** (1,23 → 0,75) e
**ajuda o modo estado** (1,26 → 1,34). Minha análise de papel dizia o contrário:
ela olhava a excursão contrária da operação inteira, que não tem ordem no tempo.
Uma vencedora pode ir a +150, voltar até a entrada acionando a trava, e só
depois seguir para o alvo.

**Não perseguir fator de lucro alto.** Uma otimização de 1.120 combinações achou
2,39 no WINV26; testada em dado que a busca nunca viu, virou **0,87** — perdendo
dinheiro em 430 operações. O número alto existe e não sobrevive.

**Escopo fechado no WINV26.** Nada de `WIN_CONTINUO` nem `WIN$N` na entrega, por
decisão da Luisa: o enunciado nomeia o WINV26, a série contínua é sintética e os
ticks dela não batem com as barras (71.177 minutos divergentes).
