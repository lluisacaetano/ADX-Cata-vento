# Roteiro da apresentação — ADX Cata-vento

Luisa Caetano Araujo · Modelagem e Projeto de Algoritmos para o Mercado Financeiro
Apresentação: 16/09/2026

---

## Como usar este arquivo

**A fala está escrita como se fala**, não como se escreve — frases curtas, repetição
onde ajuda. Leia em voz alta duas vezes antes. Na segunda, você já não vai precisar
do texto, só das âncoras.

**Cada slide tem uma "ponte"** no fim — a frase que emenda no próximo. É o que evita
o silêncio enquanto você aperta a seta.

**Você fala para duas pessoas ao mesmo tempo:** a turma, que não sabe o que é DI, e o
professor, que sabe. A regra é sempre a mesma — **diga em português primeiro, o nome
técnico depois.** Ninguém se perde e o professor ouve os nomes certos.

Tempo total dos slides: **~9 minutos.** O resto é a demonstração ao vivo, onde estão
25 pontos.

---

# PARTE 1 — O que você precisa entender

## 1.1 O robô em uma página

**Nome: ADX Cata-vento.** Um cata-vento mostra continuamente de onde o vento vem, e só
se move quando há vento. É a descrição da regra: **o DI dominante dá a direção, o ADX
dá a licença.**

**Indicador:** uma única chamada `iADX`, período 12. Devolve três linhas nos buffers do
mesmo handle:

| buffer | linha | o que mede |
|---|---|---|
| 0 | ADX | **quanto** manda (força, sem direção) |
| 1 | DI+ | pressão compradora |
| 2 | DI− | pressão vendedora |

Não existe outra chamada de indicador no arquivo e não existe nenhuma média móvel.

**Entrada — modo ESTADO (o que está entregue).** Lido nas barras 1 e 2, ambas fechadas:

- Compra: `DI+ > DI−` **e** `ADX ≥ 25` **e** ADX subindo
- Venda: `DI− > DI+` **e** `ADX ≥ 25` **e** ADX subindo

**Modo alternativo CRUZAMENTO**, por `InpModoEntrada`: entra na virada das linhas,
armando o lado no cruzamento e disparando quando o ADX volta a subir. Está no código,
medido, e não é o que está configurado.

**Saída:** Take Profit 375, Stop Loss 150, trava no zero a zero após 150 pontos a
favor, encerramento às 17:30. Toda ordem sai com stop e alvo.

**Arquitetura — duas velocidades no `OnTick`:**

1. **A cada tick** — encerramento por horário, trava diária, trava no zero a zero.
   São proteções: esperar a barra fechar deixaria a posição desamparada por até 15 min.
2. **Só na barra fechada** — a decisão de entrar. Uma posição por vez, dentro da
   janela de horário, e só então o sinal do indicador.

Mais dois detalhes defensivos: toda varredura de posição filtra por **Magic Number E
símbolo** (`EhPosicaoPropria()`), e o **lado armado morre na virada do pregão** — sem
isso, um cruzamento de sexta às 16:30 virava entrada na segunda.

**Resultado:** WINV26 · M15 · 15/04 a 08/09/2026 · fator de lucro **1,36** em **533
operações**, +2.787,00 BRL, rebaixamento máximo 0,44%.

---

## 1.2 O que são DI e ADX — o sistema DMI de Wilder

Os três vêm do mesmo cálculo, de J. Welles Wilder (1978). A ideia de partida:
**em cada barra, quem se esticou mais — a alta ou a baixa?**

### Passo 1 — o movimento direcional bruto (DM)

- `+DM = máxima_hoje − máxima_ontem` (quanto a alta avançou)
- `−DM = mínima_ontem − mínima_hoje` (quanto a baixa avançou)

E a regra que dá o nome ao sistema: **só o maior dos dois sobrevive**; o outro vira
zero. Se a máxima subiu 30 e a mínima desceu 10, a barra registra `+DM = 30` e
`−DM = 0`. Se ambos forem negativos (barra contida na anterior), os dois zeram — a
barra não tem direção nenhuma. Cada barra vota em um lado só, ou se abstém.

### Passo 2 — normalizar pelo tamanho da barra (DI)

Trinta pontos significam coisas diferentes num dia calmo e num dia violento. Wilder
divide pelo True Range e suaviza ao longo do período (12 barras, no robô):

```
DI+ = 100 × média(+DM, 12) / média(TR, 12)
DI− = 100 × média(−DM, 12) / média(TR, 12)
```

É uma porcentagem: **que fração do movimento total das últimas 12 barras foi para
cima, e que fração foi para baixo.** DI+ em 28 e DI− em 14 quer dizer que a pressão
compradora respondeu pelo dobro do movimento da vendedora.

**DI+ e DI− são a direção.** É a única coisa no sistema que distingue compra de venda.

### Passo 3 — a força, sem direção (ADX)

Primeiro o **DX**, que mede o desequilíbrio entre as duas linhas:

```
DX = 100 × |DI+ − DI−| / (DI+ + DI−)
```

Repare no valor absoluto: **ele apaga o sinal.** DI+ = 30 / DI− = 10 e
DI+ = 10 / DI− = 30 dão exatamente o mesmo DX = 50.

O **ADX é a média suavizada do DX**. Ele responde a uma pergunta só: *as duas linhas
estão bem separadas, e vêm ficando assim?*

| ADX | leitura convencional |
|---|---|
| < 20 | sem tendência, mercado lateral |
| 20 – 25 | zona cinzenta |
| **≥ 25** | **tendência com força — o limiar do robô** |
| > 40 | tendência forte |

### O detalhe que sustenta a escolha do modo ESTADO

**No instante exato do cruzamento, DI+ = DI−.** Olhe o DX: o numerador `|DI+ − DI−|`
vai a zero. Ou seja, **no cruzamento o DX é zero e o ADX está necessariamente caindo.**
Se o ADX ainda estiver alto naquela barra, é resíduo da tendência *anterior*, não força
da nova.

Consequência: exigir "cruzou **e** ADX ≥ 25 na mesma barra" não seleciona tendências
nascendo — seleciona **reversões de tendências fortes**, o oposto do que a estratégia
quer. É a explicação matemática do que foi medido empiricamente (62% das perdedoras do
modo cruzamento nunca andaram 100 pontos a favor).

Está comentado no `ForcaConfirmada()` do fonte.

---

## 1.3 A analogia do cabo de guerra

A turma não conhece DMI, e **o slide 02 não define nada** — ele começa pela conclusão.
Como o pacote já foi entregue e o PDF não deve ser alterado, **a ponte é falada**.

Use uma analogia só, e use esta. Ela tem uma propriedade rara: **é fiel à matemática.**
Cada peça corresponde a uma peça do cálculo.

- "Quanto cada time puxou" **é** a definição do DI.
- "O quanto a corda andou" **é** o cálculo do ADX (o desequilíbrio, normalizado).
- "Não diz para que lado" **é** o valor absoluto na fórmula do DX.

A explicação simples e a técnica são a mesma explicação em dois níveis — ninguém pega
você em contradição.

**E ela paga duas vezes:** no slide 02 explica o indicador, e no slide 08 torna a sua
descoberta óbvia — "o cruzamento é o empate; entrar no empate é apostar antes de saber
quem vai ganhar."

---

## 1.4 Tradução de jargão — traduza na primeira vez que disser

| escrito no slide | diga assim na primeira vez |
|---|---|
| DI+ e DI− | "as duas linhas de direção — quanto cada lado puxou" |
| ADX | "a linha de força — o quanto a disputa está desequilibrada" |
| **iADX** | **"a função do MetaTrader que calcula esse indicador"** — nunca diga "iADX" solto para a turma |
| buffers 0, 1 e 2 | "as três linhas saem todas da mesma chamada" |
| barra fechada | "só uso barras que já terminaram; a que está em formação ainda muda de valor" |
| DMI | "o indicador inteiro, com as três linhas" |
| fator de lucro | "para cada real perdido, quanto o robô ganhou — 1,36 significa R$ 1,36" |
| rebaixamento | "a maior queda do saldo em relação ao pico" |

Depois da primeira tradução, use o nome técnico à vontade. **O professor precisa ouvir
os nomes certos** — a nota de defesa depende disso. A turma só precisa ouvi-los uma vez
explicados.

Caso especial do `iADX`: para o professor essa palavra é o seu argumento mais forte.
Diga assim, que serve aos dois:

> "No código é uma única chamada de função — `iADX` — e é a única chamada de indicador
> do arquivo inteiro. Ela devolve as três linhas de uma vez."

---

# PARTE 2 — Roteiro slide a slide

## SLIDE 01 · Capa — "ADX Cata-vento" · 30s

### O que está acontecendo

Só o nome do robô, grande, e os seus dados. Este slide não tem informação — ele tem
**uma imagem mental que você vai usar o resto da apresentação inteira.** Não desperdice.

### A fala

> "Bom dia. Eu vou apresentar um robô de negociação para o mini índice, o WINV26, e o
> nome dele é **ADX Cata-vento**.
>
> O nome não é decoração, é a estratégia. Um cata-vento faz duas coisas: ele mostra
> continuamente **de onde o vento está vindo**, e ele **só se move quando tem vento**.
> É exatamente isso que o robô faz. Uma parte do indicador diz de que lado o mercado
> está indo. A outra diz se tem força de verdade por trás. Sem força, ele não entra."

**Ponte:** "Então deixa eu explicar como é que um indicador consegue medir essas duas
coisas separadas."

### Âncora

O nome na tela. Se travar: *cata-vento — mostra a direção, só se mexe com vento.*

### Não faça

Não leia seu nome, o do professor e o da disciplina em voz alta. Está escrito. Você
perde 20 segundos e a atenção da sala logo na abertura.

---

## SLIDE 02 · O indicador · 2min — **o slide mais importante**

### O que está acontecendo

O slide diz "O ADX não sabe se é compra ou venda" e mostra três cartões. **O problema:
ele começa pela conclusão.** Para quem nunca ouviu falar de ADX, o título não significa
nada.

A ordem aqui é: **você explica do zero falando, e só depois olha o slide.** O slide vira
confirmação, não fonte.

Este slide responde o item "descrever o indicador" da Seção 9, e é onde mora o risco de
perguntarem se você usou um indicador ou três. Por isso leva dois minutos.

### A fala — parte 1: a analogia (de frente para a sala, não para a tela)

> "Pensem no mercado como um **cabo de guerra**. De um lado o time dos compradores
> puxando, do outro o dos vendedores. A cada barra do gráfico, os dois puxam.
>
> O indicador que eu uso mede exatamente essa disputa, e mede em três números.
>
> Os dois primeiros são **quanto cada time puxou**. Um mede a força do lado comprador,
> o outro a força do lado vendedor. Esses dois se chamam **DI+ e DI−**. Quem estiver
> puxando mais forte diz de que lado o robô vai operar. São a **direção**.
>
> O terceiro número é diferente. Ele mede **o quanto a corda efetivamente andou** — o
> quanto a disputa está desequilibrada. Esse é o **ADX**. É a **força**.
>
> E agora o detalhe que é a chave do trabalho inteiro: **o ADX não diz para que lado a
> corda andou.** Ele diz só que um dos times está ganhando com folga — nunca qual. Se
> os dois estão equilibrados, a corda não sai do lugar: isso é mercado de lado, e não
> vale a pena entrar."

### A fala — parte 2: agora sim, vire para o slide

> "É isso que o título aqui está dizendo. A linha ADX marca 38 tanto numa alta quanto
> numa queda — eu medi isso no próprio WINV26: tem 29 barras subindo e 22 barras caindo
> com o ADX praticamente no mesmo valor. Ele não separa compra de venda. Quem separa são
> as outras duas linhas."

*(aponte os dois primeiros cartões)*

> "Direção e força. Quem manda, e quanto manda."

### A fala — parte 3: o argumento técnico, para o professor

*(aponte o terceiro cartão)*

> "E as três saem da **mesma chamada de função**. No código é uma linha só — `iADX` — e
> ela devolve o ADX, o DI+ e o DI− nos buffers 0, 1 e 2 do mesmo handle. É a única
> chamada de indicador do arquivo inteiro. Não tem média móvel, não tem nada mais: eu
> procurei os seis padrões de média móvel no fonte e dá zero ocorrência.
>
> Então 'usar o ADX' significa, na prática, usar o sistema DMI inteiro. **Não é
> contornar a exigência de um indicador só — é o que o indicador é.** E o ADX está
> nomeado na lista de indicadores adequados da Seção 5 do enunciado."

**Ponte:** "Com direção e força na mão, a regra de entrada fica quase óbvia."

### Âncoras

Os três cartões, na ordem: **quem manda → quanto manda → uma chamada só.** Se travar,
leia o rótulo do cartão e continue.

### Não faça

- Não diga "iADX" solto para a turma sem dizer que é o nome da função.
- Não entre na fórmula do DX. É resposta de pergunta, não conteúdo de slide.
- Não passe deste slide em menos de 1min30. É o alicerce dos slides 03 e 08.

---

## SLIDE 03 · A lógica · 1min30

### O que está acontecendo

Dois blocos: entrada à esquerda, saída à direita. **Este slide se explica sozinho** —
está tudo escrito. Seu trabalho não é informar, é **narrar a estrutura** e destacar as
duas ou três linhas que rendem ponto.

É o item "descrever as regras" da Seção 9.

### A fala

> "A entrada tem três condições, e as três precisam valer ao mesmo tempo.
>
> Para **comprar**: o DI+ tem que estar acima do DI− — ou seja, o time comprador está
> puxando mais. O ADX tem que estar em 25 ou mais — a corda está andando de verdade. E
> o ADX tem que estar **subindo** — está andando cada vez mais, não perdendo fôlego.
>
> Para **vender** é exatamente a mesma regra com os dois times trocados de lugar."

*(aponte a linha pequena embaixo do bloco)*

> "E tem um detalhe aqui que eu faço questão de mostrar: eu leio isso nas **barras 1 e
> 2, as duas já fechadas**. A barra que está em formação eu nunca leio. O valor dela
> muda a cada tick que chega, então um sinal lido ali viraria loteria — entraria e
> sairia sozinho dezenas de vezes dentro da mesma barra."

*(vá para o bloco da direita)*

> "Na saída são quatro portas, e nenhuma é discricionária — o robô nunca decide na hora.
>
> Alvo em 375 pontos. Stop em 150. A **trava no zero a zero**: quando a operação anda
> 150 pontos a favor, o stop sobe para o preço de entrada, então aquela operação já não
> pode mais dar prejuízo. E o encerramento das 17:30 — nenhuma posição atravessa o fim
> do pregão.
>
> E o ponto importante: **toda ordem sai da corretora já com o stop e o alvo junto.** Se
> a minha conexão cair, a proteção continua lá no servidor."

*(aponte a linha da simetria)*

> "Uma última coisa, e essa veio de graça: a regra de compra é a de venda espelhada. No
> teste deram 278 compras e 255 vendas. O enunciado exige que o robô opere nos dois
> sentidos, e aqui esse equilíbrio **não foi imposto nos parâmetros** — ele é
> propriedade da regra."

**Ponte:** "Tudo isso que eu acabei de descrever é ajustável sem tocar no código."

### Âncoras

Bloco esquerdo → as três condições. Bloco direito → quatro portas. Linha de baixo →
simetria.

### Não faça

Não leia as quatro caixas de saída uma por uma com os números. Diga os quatro nomes e
deixe os números na tela.

---

## SLIDE 04 · Os 17 parâmetros · 1min

### O que está acontecendo

Uma tabela grande com 8 grupos. **Ela é ilegível se você tentar ler.** A função dela é
provar volume e organização, não transmitir conteúdo.

⚠️ **Este slide NÃO é o item 14 da nota.** Os 25 pontos de "parâmetros obrigatórios" vêm
da **demonstração ao vivo** no MetaTrader. Aqui você só planta a ideia; a colheita é
depois. Por isso um minuto basta.

### A fala

> "São 17 parâmetros, organizados em 8 grupos."

*(passe o dedo pela coluna da esquerda, de cima a baixo, enquanto fala)*

> "O indicador. O modo de entrada. A gestão de risco. A trava no zero a zero. Os
> horários. A trava diária de resultado. E a execução.
>
> Todos editáveis na janela de propriedades do MetaTrader, sem tocar no código-fonte —
> e eu vou abrir essa janela para vocês daqui a pouco."

*(agora aponte especificamente a primeira linha)*

> "Eu queria destacar **um**, porque ele mostra um critério e não só uma escolha. O
> limiar de força, o `InpADXMinimo`, está em 25. Esse é o valor clássico do manual do
> indicador, e eu o deixei **deliberadamente fora de qualquer otimização**. Se eu
> tivesse ajustado esse número ao passado, ele viraria só mais um parâmetro decorado —
> funcionaria lindamente no teste e não significaria nada."

**Ponte:** "Agora, como é que tudo isso está organizado por dentro."

### Âncora

**A coluna da esquerda é o seu índice.** Os 8 nomes estão escritos lá. Você literalmente
lê os rótulos.

### A pergunta de risco deste slide

Se perguntarem sobre os dois parâmetros de confirmação que não fazem nada:

> "Eles pertencem ao modo alternativo de entrada, o modo cruzamento. Na configuração
> entregue, que usa o modo estado, eles não têm efeito — ali a força já faz parte da
> própria condição de entrada, avaliada na mesma barra."

**A última coluna do slide já diz isso.** Você pode simplesmente lê-la em voz alta.

---

## SLIDE 05 · Arquitetura · 1min

### O que está acontecendo

Duas colunas — o que roda a cada tick, o que roda só na barra fechada — e três cartões
de detalhe técnico embaixo.

**É o slide mais técnico e o mais dispensável para a turma.** Ele existe para a nota de
qualidade de código (15 pontos), e essa nota o professor tira lendo o `.mq5`, não
ouvindo você. Então: **um minuto, e é o primeiro a ser cortado se o tempo apertar.**

O título já é o argumento inteiro.

### A fala

> "Uma decisão de arquitetura que eu queria mostrar, porque ela não é detalhe de
> implementação — é uma escolha.
>
> O robô roda em **duas velocidades diferentes**, de propósito."

*(aponte a coluna da esquerda)*

> "Do lado esquerdo, o que roda **a cada tick**, o tempo todo: o encerramento por
> horário, a trava diária e a trava no zero a zero. Tudo isso é **proteção**."

*(coluna da direita)*

> "Do lado direito, o que roda **só quando a barra fecha**: a decisão de entrar.
>
> E o motivo está no título. Esperar a barra fechar para **decidir entrar** é justamente
> o que tira o ruído do sinal — é bom. Mas esperar a barra fechar para **proteger**
> deixaria uma posição aberta desamparada por até quinze minutos. Proteger é urgente.
> Entrar, não."

### Se sobrar tempo — e só se sobrar — pegue UM cartão de baixo

O melhor é o do meio, porque é um erro que quase todo mundo comete:

> "Um cuidado que vale mencionar: o valor booleano que o `OrderSend` devolve só diz que
> a **requisição saiu** — não que ela foi aceita. Quem decide isso é o retcode. É ele
> que o robô verifica, e é ele que vai para o Diário."

**Ponte:** "E o que isso tudo produziu no teste."

### Não faça

Não narre os três cartões de baixo. Eles estão ali para o professor ler.

---

## SLIDE 06 · Resultado · 1min15

### O que está acontecendo

Cinco números grandes e três cartões de contexto. **A tentação é ler os cinco.** Não
leia — leia três, e use os outros dois como resposta se perguntarem.

Movimento importante aqui: **você antecipa as fraquezas antes que perguntem.** Isso muda
completamente como o resultado é recebido.

### A fala

> "O teste foi no WINV26, em barras de 15 minutos, cobrindo **todo o histórico do
> contrato** — de abril a setembro. Cem mil reais de depósito, sem alavancagem, um
> contrato por operação."

*(aponte a fileira de números)*

> "**Fator de lucro 1,36**, em **533 operações**, com rebaixamento máximo de **0,44%**.
>
> Traduzindo: para cada real que o robô perdeu, ele ganhou um real e trinta e seis. E o
> pior momento da curva custou menos de meio por cento do capital."

*(agora, sem que ninguém pergunte)*

> "Duas ressalvas que eu faço questão de dizer. Primeira: isso foi testado **só no
> Strategy Tester**, nunca em conta real. Segunda: o acerto é de 50,84%, ou seja,
> **metade das operações perde**. O ganho não vem de acertar muito — vem de as
> vencedoras valerem mais que as perdedoras. Alvo de 375 contra stop de 150."

**Ponte:** "Dá para ver isso na curva."

### Âncora

Os três números grandes: **1,36 · 533 · 0,44%.** Se travar, leia os três e diga a
tradução do fator de lucro.

### Munição de reserva (só se perguntarem)

- **"55% de qualidade do histórico é pouco, não?"** → "O WINV26 vence em outubro e só
  ganha liquidez em abril, então o histórico tem falhas mesmo. Mas 75% das entradas
  saem na abertura exata da barra e 95% em até cinco minutos — o atraso é o tempo até o
  primeiro tick chegar, não falha da lógica."
- **"Quanto ganhou?"** → "+2.787 reais. Bruto foram +10.597 contra −7.810 de perda. Dá
  R$ 5,23 por operação."

---

## SLIDE 07 · A curva de capital · 45s

### O que está acontecendo

Um gráfico e três frases curtas. **É o slide mais fácil da apresentação** — você não
explica nada, você descreve o que está na tela. Use-o para respirar.

### A fala

> "Essa é a curva de capital que o Strategy Tester devolveu."

*(aponte o desenho)*

> "Ela sobe **oscilando**, não em linha reta. E com 50,84% de acerto não poderia ser
> diferente — metade das operações perde, então a curva sobe dois passos e desce um.
>
> O pior momento foi esse rebaixamento aqui, de 450 reais. E a pior sequência de azar
> foram **7 perdas seguidas**, que custaram 210 reais."

*(esta leitura vale a pena, e não está escrita no slide)*

> "E essa comparação diz uma coisa boa: a pior sequência custou **menos da metade** do
> pior rebaixamento. Ou seja, o pior momento do robô não veio de uma sequência de azar —
> veio da oscilação normal. Ele não tem um modo de falhar catastrófico."

**Ponte:** "Mas ele não começou assim. A primeira versão perdia dinheiro."

### Âncora

O gráfico. *Sobe oscilando · pior queda 450 · pior sequência 7 perdas, 210.*

---

## SLIDE 08 · Dificuldades · 2min — **o que mais rende nota de defesa**

### O que está acontecendo

Duas tabelas e uma história. **É o slide onde você deixa de parecer alguém que
implementou e passa a parecer alguém que investigou.** É também o item "dificuldades
encontradas" da Seção 9.

Conte como história, em três tempos, e **não corra**. Dois minutos.

### A fala — tempo 1: o problema

> "A primeira versão do robô entrava no **cruzamento** — no momento exato em que o DI+
> passava o DI−, ou seja, quando um time ultrapassava o outro. Parecia a coisa mais
> natural do mundo.
>
> E perdia dinheiro. Eu podia ter simplesmente trocado a regra até dar certo. Em vez
> disso eu quis saber **por quê** — então reconstruí o trajeto de cada operação
> perdedora, uma por uma, para ver quanto ela chegou a andar antes de morrer no stop."

### A fala — tempo 2: o achado

*(aponte a tabela da esquerda, linha do meio)*

> "Foram 13 operações que morreram no stop. E **8 dessas 13 nunca chegaram a andar nem
> 100 pontos a favor**. Sessenta e dois por cento delas não devolveram lucro — elas
> **nasceram erradas**. Entraram e já foram contra na hora.
>
> E aí a explicação ficou óbvia, voltando ao cabo de guerra: **o cruzamento é o instante
> em que os dois times estão empatados.** É exatamente onde as duas linhas se tocam. Eu
> estava apostando **no empate** — no único momento em que ninguém manda."

*(se o professor parecer interessado, acrescente; se não, pule)*

> "E tem uma consequência matemática disso, que eu só entendi depois: como o ADX é
> calculado pela **diferença** entre as duas linhas, no cruzamento essa diferença é
> zero. Então no cruzamento o ADX está necessariamente **caindo**. Se ele ainda estiver
> alto naquela barra, aquilo é resíduo da tendência **anterior** — não força da nova."

### A fala — tempo 3: a correção e a medida

> "A correção foi trocar o gatilho. Em vez de entrar na virada, entrar quando a
> tendência **já está estabelecida e ganhando força** — que é a regra que eu mostrei no
> slide 3. Ela não é invenção minha: veio do artigo 10715 do MQL5, implementada como
> está publicada. E eu testei quatro combinações, não centenas."

*(aponte a tabela de baixo)*

> "O efeito, no mesmo contrato e no mesmo período: cruzamento dá 1,23 em 24 operações.
> Estado dá 1,36 em 533."

*(pausa — e então o remate)*

> "E o que muda de patamar aí **não é o fator de lucro. É a amostra.** Vinte e quatro
> operações não sustentam conclusão nenhuma sobre coisa alguma."

### Se sobrar tempo — o cartão da direita

> "E eu queria mostrar que o resultado não depende de eu ter escolhido o número certo.
> Variando o período do indicador de 8 até 20, com todo o resto fixo, o fator de lucro
> fica entre 1,24 e 1,42 — sete de sete, sem nenhum vale. Eu escolhi 12 por ele ter o
> **menor rebaixamento** da faixa, não o maior fator de lucro. O critério foi risco."

**Ponte:** "E tem mais uma coisa que eu queria contar antes de terminar."

### Âncoras

Tabela esquerda → **8 de 13**. Tabela baixo → **1,23 em 24 · 1,36 em 533**. Remate →
**não é o fator, é a amostra**.

---

## SLIDE 09 · Encerramento · 45s

### O que está acontecendo

Só "Agradeço a atenção". **Não leia isso em voz alta** — está escrito, e dizer é
redundante.

Use estes 45 segundos para algo que provavelmente ninguém mais vai fazer, e que te dá o
controle sobre como as perguntas começam.

### A fala

> "Antes das perguntas, tem uma última coisa.
>
> Durante a revisão do código eu achei um bug que **inflava o meu próprio resultado**.
> Quando o robô armava um lado esperando confirmação, esse lado armado **sobrevivia ao
> fim do pregão** — então um cruzamento que aconteceu numa sexta-feira às 16:30 podia
> virar uma entrada na segunda de manhã, três dias depois do fato.
>
> Eu corrigi. E corrigir **piorou** o número.
>
> Corrigi assim mesmo, porque uma entrada disparada por um cruzamento de três dias antes
> não é a estratégia que eu estou apresentando aqui — dando lucro ou não.
>
> Agora, se puder, eu queria mostrar o robô funcionando de verdade."

E **vá direto para o MetaTrader.** Não espere ser convidada — os itens 14 e 15 valem 25
pontos e não podem ficar de fora por timidez.

---

# PARTE 3 — Resumo de bolso

Se você só olhar uma coisa antes de entrar, olhe esta tabela:

| slide | a ideia única, em cinco palavras | tempo |
|---|---|---|
| 01 | cata-vento: direção e força | 30s |
| 02 | **cabo de guerra: DI puxa, ADX mede o desequilíbrio** | 2min |
| 03 | três condições, quatro portas de saída | 1min30 |
| 04 | 17 parâmetros, 8 grupos, 25 fora da otimização | 1min |
| 05 | proteger é urgente, entrar não | 1min |
| 06 | 1,36 em 533, metade perde | 1min15 |
| 07 | sobe oscilando, sem falha catastrófica | 45s |
| 08 | **o cruzamento é o empate — e a amostra é que muda** | 2min |
| 09 | achei o bug que me favorecia e corrigi | 45s |

## As duas únicas frases que vale decorar literalmente

1. *"Usar o ADX significa usar o sistema DMI inteiro — não é contornar a exigência de um
   indicador só, é o que o indicador é."*
2. *"O que muda de patamar não é o fator de lucro, é a amostra."*

## Mapa de emergência

Se der branco em qualquer lâmina, o número do slide está no canto e cada um responde a
uma pergunta só:

| slide | a pergunta que ele responde |
|---|---|
| 02 | *que* indicador |
| 03 | *quando* entra e sai |
| 04 | o que dá pra *mudar* |
| 05 | *como* está organizado |
| 06–07 | o que *deu* |
| 08 | o que *deu errado* antes |

Diga a pergunta em voz alta e comece a responder — funciona melhor que tentar lembrar a
frase.

---

# PARTE 4 — As perguntas prováveis

**"O enunciado fala em um indicador. Você usou dois?"**
Não. `iADX` é **um** indicador — entrega as três linhas nos buffers 0, 1 e 2 do mesmo
handle. E a linha ADX isolada não constrói robô nenhum porque mede força **sem
direção**: medi no próprio WINV26 e há 29 barras em alta e 22 em baixa com ADX ≈ 38.
Quem separa compra de venda são DI+ e DI−. O ADX está nomeado na lista da Seção 5.

**"Por que entrar por estado e não no cruzamento?"**
Foi medido, não suposto. Reconstruí o trajeto de cada operação no modo cruzamento: 62%
das perdedoras nunca chegaram a andar 100 pontos a favor. Faz sentido — o cruzamento é o
instante em que as duas linhas se tocam, o ponto em que nenhum lado manda. No mesmo
contrato e período: cruzamento dá 1,23 em 24 operações, estado dá 1,36 em 533.

**"Por que DMI 12?"**
O resultado não depende disso. Variando de 8 a 20 com todo o resto fixo, o fator de
lucro fica entre 1,24 e 1,42 — sete de sete, sem nenhum vale. Escolhi 12 por ter o
**menor rebaixamento** da faixa (0,51%), não o maior fator de lucro. O critério foi
risco.

**"De onde veio a regra do modo estado?"**
Do artigo 10715 do MQL5, implementada como está publicada. Testei **quatro combinações**
(dois modos × trava ligada/desligada), não centenas.

**"E a validação fora da amostra?"**
Não existe para o WINV26, e não é escolha: contrato futuro vence e a corretora não mantém
no cadastro os contratos de 2024 e 2025. Não há outro período do mesmo ativo para
validar. O que fiz no lugar foi a varredura de robustez do período do DMI, dentro do
próprio contrato.

**"Por que não perseguiu um fator de lucro maior?"**
Uma otimização de 1.120 combinações achou 2,39 no WINV26; testada em dado que a busca
nunca viu, virou 0,87 — perdendo dinheiro em 430 operações. O número alto existe e não
sobrevive.

---

# PARTE 5 — A demonstração ao vivo

São **25 pontos diretos** mais boa parte dos 15 da defesa, e **só existem ao vivo**.

## Antes de começar — fazer ANTES, não na hora

1. **Feche qualquer MetaTrader aberto.** Duas instâncias fazem a segunda morrer em
   silêncio, e o teste sai com zero barras. Aconteceu três vezes durante o
   desenvolvimento.
2. Abra o MetaTrader normalmente.
3. Confirme que o robô aparece em **Navegador → Expert Advisors → Trabalho01 →
   `Robo_ADX_WIN`**.
4. Abra um gráfico de **WINV26**, período **M15**.

O `.set` já está nos dois lugares onde o MT5 procura: `MQL5/Presets/` (botão Carregar da
janela de propriedades) e `MQL5/Profiles/Tester/` (Testador de Estratégia).

## Item 14 — demonstrar os parâmetros (25 pontos)

1. Arraste `Robo_ADX_WIN` do Navegador para o gráfico de WINV26 M15.
2. A janela abre na aba **Comum** — clique em **Parâmetros de Entrada**.
3. Se quiser garantir os valores: **Carregar** → `Parametros_ADX_CataVento.set`.

**É essa tela que vale os pontos.** Não leia a lista — agrupe, e depois aponte **um**
parâmetro e explique o critério (o `InpADXMinimo` = 25, fora de qualquer otimização).

## Item 15 — demonstrar o funcionamento

Use **as duas formas**, nesta ordem:

**Primeiro o visual, para ver operando.** Ctrl+R abre o Testador. Aba Configurações:
Expert `Robo_ADX_WIN`, símbolo **WINV26**, período **M15**, modelagem **OHLC de 1
minuto**, e marque **Visualização**. Rode e deixe o gráfico correr — dá para ver as
entradas aparecendo com stop e alvo. É o que mais convence.

**Depois sem visual, para o número.** Desmarque Visualização, rode o período
**15/04/2026 a 08/09/2026** e mostre a aba **Resultados**: fator de lucro 1,36 e 533
operações, os mesmos do slide.

**Aponte também a aba Diário.** Cada recusa tem o motivo escrito — é boa prática da
Seção 6 e reforça a nota de qualidade de código.

## Os dois imprevistos possíveis

**Se barras ou qualidade saírem diferentes do PDF:**

> "Barras e qualidade do histórico dependem da sincronização com a corretora e variam
> entre execuções. O resultado da estratégia — fator de lucro, número de operações e
> lucro — se manteve idêntico."

É verdade e foi medido: entre duas execuções o histórico mudou de 2.554 para 2.553 barras
e de 57% para 55% de qualidade, e os resultados não se moveram.

**Se o WINV26 não carregar histórico:** existe `WINV26_LOCAL`, símbolo custom clonado com
os mesmos preços. Não é ideal (o cabeçalho mostra outro nome), mas é melhor que travar.

---

# Onde estão os pontos

| Critério | Pontos | Onde se ganha |
|---|---|---|
| Funcionamento do robô | 30 | compila, anexa ao gráfico, abre e fecha operações |
| Parâmetros obrigatórios | 25 | **demonstração ao vivo** (item 14) |
| Uso do indicador e lógica | 15 | slides 2 e 3 |
| Qualidade do código | 15 | o `.mq5` |
| Apresentação e defesa | 15 | **ao vivo** |

**Nenhum ponto depende de o robô ser lucrativo.** Ensaiar rende mais que otimizar.
