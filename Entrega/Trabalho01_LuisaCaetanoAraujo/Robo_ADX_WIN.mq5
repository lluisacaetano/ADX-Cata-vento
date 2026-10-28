//+------------------------------------------------------------------+
//|                                               Robo_ADX_WIN.mq5   |
//|                                                                  |
//|  Trabalho Pratico - Modelagem e Projeto de Algoritmos para o     |
//|  Mercado Financeiro - Ciencia da Computacao                      |
//|                                                                  |
//|  Expert Advisor de compra e venda para o mini indice (WIN).      |
//|  Estrategia "ADX Bussola".                                       |
//|                                                                  |
//|  O sinal de entrada e gerado pelo DMI, sempre avaliado na barra  |
//|  fechada. DI+ e DI- dizem a direcao; a linha ADX diz a forca. Os |
//|  tres vem do MESMO indicador (iADX entrega ADX, DI+ e DI- nos    |
//|  buffers 0, 1 e 2 de um unico handle), entao a entrada e         |
//|  decidida por um indicador so, como exige o enunciado.           |
//|                                                                  |
//|  Modo padrao (ESTADO): entra quando o DI dominante ja esta       |
//|  estabelecido E o ADX esta no minimo e subindo.                  |
//|  Modo alternativo (CRUZAMENTO): entra na virada de DI+ e DI-,    |
//|  com confirmacao de forca opcional nas barras seguintes.         |
//|                                                                  |
//|  Toda ordem sai com Stop Loss e Take Profit. O robo respeita     |
//|  janela de horario, horario de encerramento e trava diaria de    |
//|  ganho e de perda.                                               |
//+------------------------------------------------------------------+
#property copyright "Luisa Caetano"
#property version   "1.00"
#property description "Robo de negociacao para o mini indice (WIN) baseado no DMI."
#property description "Modo padrao ESTADO: entra com o DI dominante estabelecido e o"
#property description "ADX no minimo e subindo. Opera compra e venda, com Stop Loss,"
#property description "Take Profit, trava no zero a zero, janela de horario, horario de"
#property description "encerramento e trava diaria de resultado."

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Tipos                                                            |
//+------------------------------------------------------------------+
enum ENUM_SINAL {
   SINAL_NENHUM,   // nenhum sinal na barra avaliada
   SINAL_COMPRA,   // pressao compradora assumiu
   SINAL_VENDA     // pressao vendedora assumiu
};

// Como o DMI vira entrada. Sao duas leituras diferentes do MESMO indicador.
enum ENUM_MODO_ENTRADA {
   MODO_CRUZAMENTO,  // Cruzamento: entra na virada de DI+ e DI-
   MODO_ESTADO       // Estado: entra com a tendencia ja estabelecida e ganhando forca
};

//+------------------------------------------------------------------+
//| Parametros de entrada                                            |
//+------------------------------------------------------------------+
input group "Indicador (DMI / ADX)"
input int    InpDMIPeriodo = 12;     // Periodos do DMI (vale para DI+, DI- e ADX)
input double InpADXMinimo  = 25.0;   // ADX a partir deste valor = tendencia com forca

input group "Modo de entrada"
// CRUZAMENTO entra no instante em que DI+ e DI- trocam de lado. E o ponto de
// maxima incerteza: as duas linhas se tocando significa que nenhum lado manda.
// A medicao das operacoes mostrou que 62% das perdedoras nunca chegam a andar
// 100 pontos a favor - elas nascem erradas.
//
// ESTADO entra quando a tendencia JA esta estabelecida e ganhando forca
// (DI+ acima de DI-, ADX no minimo e subindo). Entra mais tarde e perde o
// comeco do movimento, mas so entra em movimento que ja se provou.
//
// ESTADO e o padrao. No WINV26, com o historico completo do contrato, ele deu
// fator de lucro 1,36 em 533 operacoes contra 1,23 em 24 do CRUZAMENTO. O que
// muda de patamar nao e o fator - e a amostra, que finalmente sustenta uma
// conclusao. A regra veio do artigo 10715 do MQL5, nao de otimizacao: foram
// testadas quatro combinacoes, nao mil.
input ENUM_MODO_ENTRADA InpModoEntrada = MODO_ESTADO;  // Como o DMI gera a entrada

input group "Confirmacao de forca - SO no modo CRUZAMENTO"
// Estes dois parametros NAO tem efeito no modo ESTADO. Ali a forca ja faz parte
// da condicao de entrada: o ADX precisa estar no minimo E subindo na mesma
// barra avaliada, sem espera nenhuma.
//
// No modo CRUZAMENTO eles governam o mecanismo de armar e confirmar: o
// cruzamento arma um lado e o robo espera ate InpBarrasConfirmacao barras para
// a forca aparecer.
input bool InpUsarConfirmacaoADX = true;   // [CRUZAMENTO] Exigir forca do ADX apos o cruzamento
input int  InpBarrasConfirmacao  = 1;      // [CRUZAMENTO] Barras de espera pela confirmacao

input group "Gestao de risco"
input double InpLote       = 1.0;   // Quantidade de lote (contratos por operacao)
input double InpStopLoss   = 150;   // Stop Loss por operacao (pontos)
input double InpTakeProfit = 375;   // Take Profit por operacao (pontos)

input group "Trava no zero a zero"
// Um sistema de tendencia acerta pouco e precisa que os acertos valguem. Na
// medicao do WINV26, 5 das 13 operacoes estopadas tinham chegado a +150 pontos
// ou mais antes de virar - uma delas chegou a +590, mais de uma vez e meia o
// alvo, e ainda assim fechou no stop.
//
// Com esta opcao ligada, assim que a operacao anda o gatilho a favor o stop
// sobe para o preco de entrada, o que elimina a perda PLANEJADA da operacao.
// Em conta real ainda pode sobrar uma diferenca pequena, por spread e
// derrapagem na execucao; no Strategy Tester, com spread zero, o resultado
// dessas operacoes e exatamente zero.
// O gatilho nao saiu de otimizacao - 150 e a distancia do proprio stop, e fica
// acima da maior excursao contraria observada nas operacoes vencedoras (110).
input bool   InpTravaZeroAZero   = true;   // Mover o stop para a entrada apos andar a favor
input double InpGatilhoZeroAZero = 150;    // Pontos a favor que acionam a trava

input group "Horarios (HH:MM, hora do servidor)"
input string InpHoraInicio     = "09:15";  // Horario de inicio (a partir daqui pode abrir posicao)
input string InpHoraFim        = "16:30";  // Horario de fim (ultima entrada permitida)
input string InpHoraFechamento = "17:30";  // Horario de encerramento (fecha toda posicao aberta)

input group "Trava diaria de resultado"
input double InpGanhoMaxDia = 500.0;  // Ganho maximo diario (R$) - 0 desliga a trava
input double InpPerdaMaxDia = 300.0;  // Perda maxima diaria (R$, valor positivo) - 0 desliga a trava

input group "Execucao"
input ulong InpMagic        = 20262;  // Magic Number (identifica as posicoes deste robo)
input bool  InpLogDetalhado = true;   // Registrar no Diario o motivo de cada recusa

//+------------------------------------------------------------------+
//| Constantes                                                       |
//+------------------------------------------------------------------+
// Desvio maximo de preco aceito no envio da ordem (pontos). O mini indice
// e liquido, mas o preco pode andar entre a leitura e o envio.
const ulong DESVIO_MAXIMO_PONTOS = 50;

// Margem somada a distancia minima de stops exigida pelo simbolo.
const long MARGEM_STOPS_PONTOS = 15;

//+------------------------------------------------------------------+
//| Estado global                                                    |
//+------------------------------------------------------------------+
CTrade g_trade;

// DI+, DI- e ADX moram no mesmo handle: UM indicador, tres buffers.
// E o unico indicador do robo - nao existe outra chamada iXxx no codigo.
int    g_dmi_handle = INVALID_HANDLE;  // handle do DMI/ADX, criado no OnInit

double g_ponto     = 0.0;   // SYMBOL_POINT
double g_tick_size = 0.0;   // SYMBOL_TRADE_TICK_SIZE
double g_vol_min   = 0.0;   // volume minimo do simbolo
double g_vol_max   = 0.0;   // volume maximo do simbolo
double g_vol_step  = 0.0;   // passo de volume do simbolo

int g_min_inicio     = 0;   // InpHoraInicio convertido em minutos desde a meia-noite
int g_min_fim        = 0;   // InpHoraFim
int g_min_fechamento = 0;   // InpHoraFechamento

datetime g_barra_avaliada = 0;      // abertura da ultima barra ja avaliada
datetime g_dia            = 0;      // meia-noite do pregao em curso
bool     g_bloqueado_hoje = false;  // trava diaria atingida neste pregao
string   g_ultima_recusa  = "";     // evita repetir o mesmo motivo a cada tick
datetime g_painel_atualizado = 0;  // ultimo segundo em que o painel foi recalculado

// Estado da confirmacao por ADX (so usado quando InpUsarConfirmacaoADX):
// o cruzamento arma um lado e o robo espera a forca aparecer.
ENUM_SINAL g_lado_armado   = SINAL_NENHUM;  // lado armado pelo cruzamento
int        g_barras_armado = 0;             // barras fechadas desde que armou

//+------------------------------------------------------------------+
//| Diario                                                           |
//+------------------------------------------------------------------+
void Log(const string mensagem) {
   Print(mensagem);
}

// Motivos de recusa chegam a cada tick. Registrar so quando o motivo muda
// mantem o Diario legivel sem esconder nenhuma recusa.
void LogRecusa(const string motivo) {
   if(!InpLogDetalhado)
      return;
   if(motivo == g_ultima_recusa)
      return;
   g_ultima_recusa = motivo;
   Print("[RECUSA] ", motivo);
}

//+------------------------------------------------------------------+
//| Horarios                                                         |
//+------------------------------------------------------------------+
bool SomenteDigitos(const string texto) {
   int tamanho = StringLen(texto);
   if(tamanho == 0)
      return false;
   for(int i = 0; i < tamanho; i++) {
      ushort caractere = StringGetCharacter(texto, i);
      if(caractere < '0' || caractere > '9')
         return false;
   }
   return true;
}

// Converte "HH:MM" em minutos desde a meia-noite. Retorna false se o texto
// nao for um horario valido - o OnInit usa isso para recusar o parametro.
bool ParseHora(const string texto, int &minutos) {
   string partes[];
   if(StringSplit(texto, ':', partes) != 2)
      return false;

   string hora = partes[0];
   string minuto = partes[1];
   StringTrimLeft(hora);
   StringTrimRight(hora);
   StringTrimLeft(minuto);
   StringTrimRight(minuto);

   if(!SomenteDigitos(hora) || !SomenteDigitos(minuto))
      return false;

   int hh = (int)StringToInteger(hora);
   int mm = (int)StringToInteger(minuto);
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return false;

   minutos = hh * 60 + mm;
   return true;
}

int MinutosDoDia(const datetime instante) {
   MqlDateTime partes;
   TimeToStruct(instante, partes);
   return partes.hour * 60 + partes.min;
}

datetime InicioDoDia(const datetime instante) {
   MqlDateTime partes;
   TimeToStruct(instante, partes);
   partes.hour = 0;
   partes.min  = 0;
   partes.sec  = 0;
   return StructToTime(partes);
}

// Janela em que o robo pode ABRIR novas posicoes.
bool DentroDaJanela() {
   int agora = MinutosDoDia(TimeCurrent());
   return (agora >= g_min_inicio && agora <= g_min_fim);
}

// A partir do horario de encerramento nenhuma posicao do robo fica aberta.
bool PassouDoFechamento() {
   return (MinutosDoDia(TimeCurrent()) >= g_min_fechamento);
}

//+------------------------------------------------------------------+
//| Posicoes do robo                                                 |
//|                                                                  |
//| Toda varredura filtra por Magic Number E simbolo, para nunca      |
//| tocar em posicao manual ou de outro robo.                        |
//+------------------------------------------------------------------+
bool EhPosicaoPropria(const ulong ticket) {
   if(ticket == 0)
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;
   if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
      return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return false;
   return true;
}

bool TemPosicaoPropria() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(EhPosicaoPropria(PositionGetTicket(i)))
         return true;
   }
   return false;
}

void FecharPosicoesProprias(const string motivo) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!EhPosicaoPropria(ticket))
         continue;

      g_trade.PositionClose(ticket);

      uint retcode = g_trade.ResultRetcode();
      if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) {
         Log(StringFormat("POSICAO FECHADA | ticket %I64u | motivo: %s", ticket, motivo));
      } else {
         Log(StringFormat("FALHA AO FECHAR | ticket %I64u | motivo: %s | retcode %u (%s)",
                          ticket, motivo, retcode, g_trade.ResultRetcodeDescription()));
      }
   }
}

//+------------------------------------------------------------------+
//| Resultado do dia e trava diaria                                  |
//+------------------------------------------------------------------+
// Soma o resultado realizado do pregao (negocios ja fechados) com o
// resultado em aberto das posicoes do robo.
double ResultadoDoDia() {
   double total = 0.0;

   if(HistorySelect(g_dia, TimeCurrent() + 1)) {
      int negocios = HistoryDealsTotal();
      for(int i = 0; i < negocios; i++) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagic)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;

         total += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                + HistoryDealGetDouble(ticket, DEAL_SWAP)
                + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   } else {
      LogRecusa("nao foi possivel ler o historico de negocios do dia");
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!EhPosicaoPropria(ticket))
         continue;
      total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }

   return total;
}

// Zera a trava na virada do pregao.
//
// O lado armado tambem morre aqui, e isso NAO e detalhe: um cruzamento so
// vale para o pregao em que aconteceu. Sem esta linha o lado armado
// sobrevive a noite, porque os passos 1, 2 e 5 do OnTick (fechamento, trava
// diaria e fora da janela) dao return ANTES de SinalAtual(), que e a unica
// funcao que desarma. Um cruzamento das 16:30 de sexta chegava a virar
// entrada as 09:15 de segunda - tres dias depois do fato que o gerou.
// Desarmar na virada do pregao cobre os tres caminhos de uma vez, no ponto
// em que a informacao "mudou o dia" existe.
void AtualizarDia() {
   datetime hoje = InicioDoDia(TimeCurrent());
   if(hoje == g_dia)
      return;

   if(g_lado_armado != SINAL_NENHUM)
      Log(StringFormat("[DESARMADO] %s armado no pregao anterior: cruzamento nao atravessa o pregao",
                       g_lado_armado == SINAL_COMPRA ? "COMPRA" : "VENDA"));
   DesarmarSinal();

   g_dia = hoje;
   g_bloqueado_hoje = false;
   g_ultima_recusa = "";
   Log(StringFormat("=== Novo pregao: %s | travas do dia liberadas ===",
                    TimeToString(hoje, TIME_DATE)));
}

// Retorna true quando o robo esta bloqueado para o resto do dia. Ao atingir
// o limite pela primeira vez, encerra as posicoes abertas.
bool TravaDiariaAtingida() {
   if(g_bloqueado_hoje)
      return true;

   double resultado = ResultadoDoDia();

   if(InpGanhoMaxDia > 0 && resultado >= InpGanhoMaxDia) {
      g_bloqueado_hoje = true;
      Log(StringFormat("TRAVA DIARIA | ganho maximo atingido: R$ %.2f (limite R$ %.2f)",
                       resultado, InpGanhoMaxDia));
      FecharPosicoesProprias("ganho maximo diario");
      return true;
   }

   if(InpPerdaMaxDia > 0 && resultado <= -InpPerdaMaxDia) {
      g_bloqueado_hoje = true;
      Log(StringFormat("TRAVA DIARIA | perda maxima atingida: R$ %.2f (limite R$ -%.2f)",
                       resultado, InpPerdaMaxDia));
      FecharPosicoesProprias("perda maxima diaria");
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Sinal                                                            |
//+------------------------------------------------------------------+
// True apenas no primeiro tick de uma barra nova, ou seja, quando a barra
// anterior acabou de fechar.
bool NovaBarra() {
   datetime abertura = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(abertura == 0)
      return false;
   if(abertura == g_barra_avaliada)
      return false;
   g_barra_avaliada = abertura;
   return true;
}

// Le o DMI das duas ultimas barras FECHADAS (deslocamentos 1 e 2). A barra 0
// ainda esta em formacao e seu valor muda a cada tick.
//
// Os tres buffers saem do mesmo handle do iADX:
//   0 = ADX (forca da tendencia)   1 = DI+ (pressao compradora)   2 = DI- (vendedora)
bool LerDMI(double &adx, double &adx_ant,
            double &dip, double &dip_ant,
            double &dim, double &dim_ant) {
   double buf_adx[], buf_dip[], buf_dim[];
   ArraySetAsSeries(buf_adx, true);
   ArraySetAsSeries(buf_dip, true);
   ArraySetAsSeries(buf_dim, true);

   if(CopyBuffer(g_dmi_handle, 0, 1, 2, buf_adx) < 2 ||
      CopyBuffer(g_dmi_handle, 1, 1, 2, buf_dip) < 2 ||
      CopyBuffer(g_dmi_handle, 2, 1, 2, buf_dim) < 2) {
      LogRecusa(StringFormat("DMI indisponivel (erro %d)", GetLastError()));
      return false;
   }

   adx = buf_adx[0];  adx_ant = buf_adx[1];
   dip = buf_dip[0];  dip_ant = buf_dip[1];
   dim = buf_dim[0];  dim_ant = buf_dim[1];
   return true;
}

// Esquece o lado armado. Chamado quando o robo abre posicao ou reinicia, para
// que um cruzamento antigo nao dispare uma entrada muito depois do fato.
void DesarmarSinal() {
   g_lado_armado   = SINAL_NENHUM;
   g_barras_armado = 0;
}

// Confirmacao opcional de forca, medida na barra fechada.
//
// Por que a confirmacao e ADIADA e nao lida na propria barra do cruzamento:
// o ADX e a media suavizada do DX, e DX = |DI+ - DI-| / (DI+ + DI-). No
// instante em que DI+ cruza DI-, as duas linhas se tocam, DX vai a zero e o
// ADX esta CAINDO. Um ADX ainda alto naquela barra e residuo da tendencia
// ANTERIOR, nao forca da nova. Exigir "cruzou e ADX >= 25 na mesma barra"
// seleciona, na pratica, reversoes de tendencias fortes - o oposto do que a
// estrategia quer. Por isso o robo arma o lado no cruzamento e so entra
// quando o ADX volta a SUBIR acima do limiar.
//
// Com InpBarrasConfirmacao = 0 a confirmacao volta a ser exigida na propria
// barra do cruzamento, o que permite medir esse efeito no Strategy Tester.
bool ForcaConfirmada(const double adx, const double adx_ant) {
   if(adx < InpADXMinimo) {
      LogRecusa(StringFormat("ADX %.1f < %.1f: tendencia sem forca, entrada nao confirmada",
                             adx, InpADXMinimo));
      return false;
   }
   if(adx <= adx_ant) {
      LogRecusa(StringFormat("ADX %.1f nao esta subindo (anterior %.1f): entrada nao confirmada",
                             adx, adx_ant));
      return false;
   }
   return true;
}

// O DMI gera o sinal sozinho. DI+ e DI- dizem QUEM manda (a direcao) e a linha
// ADX diz QUANTO manda (a forca) - as tres do mesmo indicador.
//
// Isso e o que a linha ADX isolada nao consegue fazer: ela mede forca sem
// direcao (ADX 38 tanto numa alta quanto numa baixa), e por isso nao separa
// compra de venda. Quem separa sao DI+ e DI-, e e por isso que "usar o ADX"
// significa, na pratica, usar o sistema DMI inteiro.
//
// Simetria: a regra de compra e a de venda sao a mesma expressao com os papeis
// de DI+ e DI- trocados. Os dois sentidos sao equiprovaveis por construcao,
// o que atende a exigencia de operar na compra e na venda sem precisar de
// nenhuma restricao artificial nos parametros.
ENUM_SINAL SinalAtual() {
   double adx = 0.0, adx_ant = 0.0;
   double dip = 0.0, dip_ant = 0.0;
   double dim = 0.0, dim_ant = 0.0;
   if(!LerDMI(adx, adx_ant, dip, dip_ant, dim, dim_ant))
      return SINAL_NENHUM;

   // --- MODO ESTADO ------------------------------------------------
   // Nao espera a virada: entra quando a tendencia ja esta estabelecida
   // (um DI acima do outro) E o ADX confirma que ela esta ganhando forca.
   // Nao usa o mecanismo de armar/confirmar - aqui a forca faz parte da
   // propria condicao de entrada, avaliada na mesma barra fechada.
   if(InpModoEntrada == MODO_ESTADO) {
      if(adx < InpADXMinimo) {
         LogRecusa(StringFormat("ADX %.1f < %.1f: tendencia sem forca", adx, InpADXMinimo));
         return SINAL_NENHUM;
      }
      if(adx <= adx_ant) {
         LogRecusa(StringFormat("ADX %.1f nao esta subindo (anterior %.1f)", adx, adx_ant));
         return SINAL_NENHUM;
      }
      ENUM_SINAL lado = SINAL_NENHUM;
      if(dip > dim)      lado = SINAL_COMPRA;
      else if(dim > dip) lado = SINAL_VENDA;
      if(lado == SINAL_NENHUM) {
         LogRecusa("DI+ e DI- empatados: sem direcao definida");
         return SINAL_NENHUM;
      }
      Log(StringFormat("[SINAL] %s por ESTADO | DI+ %.2f DI- %.2f | ADX %.2f subindo (anterior %.2f)",
                       lado == SINAL_COMPRA ? "COMPRA" : "VENDA", dip, dim, adx, adx_ant));
      return lado;
   }

   // --- 1. cruzamento: quem estava por baixo passou para cima -------
   ENUM_SINAL cruzamento = SINAL_NENHUM;
   if(dip_ant <= dim_ant && dip > dim)
      cruzamento = SINAL_COMPRA;
   else if(dim_ant <= dip_ant && dim > dip)
      cruzamento = SINAL_VENDA;

   // --- 2. sem confirmacao: o cruzamento ja e a entrada --------------
   if(!InpUsarConfirmacaoADX) {
      if(cruzamento == SINAL_NENHUM)
         return SINAL_NENHUM;
      Log(StringFormat("[SINAL] %s | DI+ %.2f DI- %.2f (antes %.2f / %.2f) | ADX %.2f",
                       cruzamento == SINAL_COMPRA ? "COMPRA" : "VENDA",
                       dip, dim, dip_ant, dim_ant, adx));
      return cruzamento;
   }

   // --- 3. com confirmacao: o cruzamento arma, a forca dispara -------
   if(cruzamento != SINAL_NENHUM) {
      g_lado_armado   = cruzamento;
      g_barras_armado = 0;
      Log(StringFormat("[ARMADO] %s | DI+ %.2f DI- %.2f | aguardando ADX >= %.1f e subindo",
                       cruzamento == SINAL_COMPRA ? "COMPRA" : "VENDA",
                       dip, dim, InpADXMinimo));
   }

   if(g_lado_armado == SINAL_NENHUM)
      return SINAL_NENHUM;

   // A direcao precisa continuar valendo enquanto se espera a forca.
   bool direcao_mantida = (g_lado_armado == SINAL_COMPRA) ? (dip > dim) : (dim > dip);
   if(!direcao_mantida) {
      Log(StringFormat("[DESARMADO] DI+ %.2f DI- %.2f: direcao se inverteu antes da confirmacao",
                       dip, dim));
      DesarmarSinal();
      return SINAL_NENHUM;
   }

   if(ForcaConfirmada(adx, adx_ant)) {
      ENUM_SINAL sinal = g_lado_armado;
      Log(StringFormat("[SINAL] %s | DI+ %.2f DI- %.2f | ADX %.2f subindo (anterior %.2f) | %d barra(s) apos o cruzamento",
                       sinal == SINAL_COMPRA ? "COMPRA" : "VENDA",
                       dip, dim, adx, adx_ant, g_barras_armado));
      DesarmarSinal();
      return sinal;
   }

   // Nao confirmou nesta barra: conta o tempo de espera e desiste no limite.
   g_barras_armado++;
   if(g_barras_armado > InpBarrasConfirmacao) {
      Log(StringFormat("[DESARMADO] %d barra(s) sem confirmacao do ADX (limite %d)",
                       g_barras_armado, InpBarrasConfirmacao));
      DesarmarSinal();
   }
   return SINAL_NENHUM;
}

//+------------------------------------------------------------------+
//| Normalizacao de volume e de stops                                |
//+------------------------------------------------------------------+
double NormalizarVolume(double volume) {
   double minimo = g_vol_min;
   if(g_vol_step > g_vol_min && g_vol_step > 0)
      minimo = g_vol_step;

   if(volume < minimo)
      volume = minimo;

   if(g_vol_step > 0) {
      volume = MathRound(volume / g_vol_step) * g_vol_step;
      if(volume <= 0)
         volume = minimo;
   }

   if(g_vol_max > 0 && volume > g_vol_max)
      volume = g_vol_max;

   return NormalizeDouble(volume, 2);
}

// Afasta stop e alvo ate a distancia minima exigida pelo simbolo e arredonda
// os precos para o passo de tick. Sem isso a corretora recusa a ordem.
void AjustarStops(const double preco_entrada, double &sl, double &tp, const bool compra) {
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long spread      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   long distancia_pontos = stops_level + MARGEM_STOPS_PONTOS;
   double distancia = distancia_pontos * g_ponto;

   // Mesmo com stops_level zerado, colar o stop no spread nao sobrevive.
   double minimo_por_spread = spread * g_ponto * 3;
   if(distancia < minimo_por_spread)
      distancia = minimo_por_spread;

   if(compra) {
      if(preco_entrada - sl < distancia)
         sl = preco_entrada - distancia;
      if(tp - preco_entrada < distancia)
         tp = preco_entrada + distancia;
   } else {
      if(sl - preco_entrada < distancia)
         sl = preco_entrada + distancia;
      if(preco_entrada - tp < distancia)
         tp = preco_entrada - distancia;
   }

   if(g_tick_size > 0) {
      sl = MathRound(sl / g_tick_size) * g_tick_size;
      tp = MathRound(tp / g_tick_size) * g_tick_size;

      // O arredondamento pode ter trazido o preco de volta para dentro da
      // distancia minima; um tick a mais resolve.
      double dist_sl = compra ? (preco_entrada - sl) : (sl - preco_entrada);
      double dist_tp = compra ? (tp - preco_entrada) : (preco_entrada - tp);

      if(dist_sl < distancia)
         sl += compra ? -g_tick_size : g_tick_size;
      if(dist_tp < distancia)
         tp += compra ? g_tick_size : -g_tick_size;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
}

// Move o stop para o preco de entrada quando a operacao ja andou o gatilho a
// favor. Roda a cada tick, porque o preco pode fazer o percurso inteiro dentro
// de uma barra - esperar a barra fechar perderia justamente os casos que a
// trava existe para salvar.
//
// So sobe o stop, nunca desce: se ele ja esta no zero a zero ou melhor, nao
// mexe. E respeita a distancia minima exigida pelo simbolo, senao a corretora
// recusa a modificacao.
void AplicarTravaZeroAZero() {
   if(!InpTravaZeroAZero)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!EhPosicaoPropria(ticket))
         continue;

      long   tipo    = PositionGetInteger(POSITION_TYPE);
      double entrada = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl      = PositionGetDouble(POSITION_SL);
      double tp      = PositionGetDouble(POSITION_TP);
      bool   compra  = (tipo == POSITION_TYPE_BUY);

      double atual = compra ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(atual <= 0)
         continue;

      double favor_pts = (compra ? (atual - entrada) : (entrada - atual)) / g_ponto;
      if(favor_pts < InpGatilhoZeroAZero)
         continue;

      // Ja protegida? Nada a fazer.
      if(sl > 0 && ((compra && sl >= entrada) || (!compra && sl <= entrada)))
         continue;

      // A corretora exige distancia minima entre o stop e o preco corrente.
      long   stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double distancia   = (stops_level + MARGEM_STOPS_PONTOS) * g_ponto;
      double folga       = compra ? (atual - entrada) : (entrada - atual);
      if(folga < distancia)
         continue;

      double novo_sl = NormalizeDouble(entrada, _Digits);
      if(g_trade.PositionModify(ticket, novo_sl, tp)) {
         Log(StringFormat("ZERO A ZERO | ticket %I64u | stop movido para a entrada %s (%.0f pts a favor)",
                          ticket, DoubleToString(novo_sl, _Digits), favor_pts));
      } else {
         LogRecusa(StringFormat("falha ao mover o stop para o zero a zero: retcode %u (%s)",
                                g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
      }
   }
}

//+------------------------------------------------------------------+
//| Envio de ordem                                                   |
//+------------------------------------------------------------------+
bool EnviarOrdem(const bool compra) {
   double preco = compra ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(preco <= 0) {
      LogRecusa("preco de mercado indisponivel");
      return false;
   }

   double sl = compra ? preco - InpStopLoss   * g_ponto
                      : preco + InpStopLoss   * g_ponto;
   double tp = compra ? preco + InpTakeProfit * g_ponto
                      : preco - InpTakeProfit * g_ponto;
   AjustarStops(preco, sl, tp, compra);

   double lote = NormalizarVolume(InpLote);
   string comentario = compra ? "DMI Compra" : "DMI Venda";

   bool retorno_funcao = compra
                       ? g_trade.Buy(lote, _Symbol, 0.0, sl, tp, comentario)
                       : g_trade.Sell(lote, _Symbol, 0.0, sl, tp, comentario);

   // O booleano acima diz apenas que a requisicao saiu. Quem confirma que o
   // servidor aceitou a ordem e o retcode.
   uint retcode = g_trade.ResultRetcode();
   if(retcode != TRADE_RETCODE_DONE && retcode != TRADE_RETCODE_PLACED) {
      Log(StringFormat("ORDEM RECUSADA | %s | retorno da funcao: %s | retcode %u (%s)",
                       comentario,
                       retorno_funcao ? "true" : "false",
                       retcode,
                       g_trade.ResultRetcodeDescription()));
      return false;
   }

   double preco_executado = g_trade.ResultPrice();
   if(preco_executado <= 0)
      preco_executado = preco;
   double pontos_sl = MathAbs(preco_executado - sl) / g_ponto;
   double pontos_tp = MathAbs(tp - preco_executado) / g_ponto;
   Log(StringFormat("%s EXECUTADA | preco %s | lote %.2f | SL %s (%.0f pts) | TP %s (%.0f pts)",
                    compra ? "COMPRA" : "VENDA",
                    DoubleToString(preco_executado, _Digits),
                    lote,
                    DoubleToString(sl, _Digits), pontos_sl,
                    DoubleToString(tp, _Digits), pontos_tp));
   return true;
}

//+------------------------------------------------------------------+
//| Painel do grafico (visivel tambem no Strategy Tester visual)      |
//+------------------------------------------------------------------+
void AtualizarPainel() {
   datetime agora = TimeCurrent();
   if(agora == g_painel_atualizado)
      return;
   g_painel_atualizado = agora;

   double adx = 0.0, adx_ant = 0.0;
   double dip = 0.0, dip_ant = 0.0, dim = 0.0, dim_ant = 0.0;
   string dmi_texto = LerDMI(adx, adx_ant, dip, dip_ant, dim, dim_ant)
                    ? StringFormat("DI+ %.1f | DI- %.1f | ADX %.1f", dip, dim, adx)
                    : "--";

   string armado_texto = "-";
   if(InpUsarConfirmacaoADX && g_lado_armado != SINAL_NENHUM)
      armado_texto = StringFormat("%s ha %d barra(s)",
                                  g_lado_armado == SINAL_COMPRA ? "COMPRA" : "VENDA",
                                  g_barras_armado);

   string estado;
   if(g_bloqueado_hoje)
      estado = "BLOQUEADO (trava diaria)";
   else if(PassouDoFechamento())
      estado = "ENCERRADO (horario)";
   else if(!DentroDaJanela())
      estado = "FORA DA JANELA";
   else if(TemPosicaoPropria())
      estado = "POSICAO ABERTA";
   else
      estado = "AGUARDANDO SINAL";

   Comment(StringFormat(
      "ADX Bussola - %s\n"
      "-----------------------------\n"
      "Estado:          %s\n"
      "DMI (fechada):   %s\n"
      "Sinal armado:    %s\n"
      "Resultado do dia: R$ %.2f\n"
      "Limites:         +%.2f / -%.2f\n"
      "Janela:          %s as %s | encerra %s\n"
      "-----------------------------",
      _Symbol,
      estado,
      dmi_texto,
      armado_texto,
      ResultadoDoDia(),
      InpGanhoMaxDia, InpPerdaMaxDia,
      InpHoraInicio, InpHoraFim, InpHoraFechamento));
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   // --- validacao dos parametros -----------------------------------
   if(InpDMIPeriodo < 2) {
      Log("Parametro invalido: o periodo do DMI deve ser 2 ou maior.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUsarConfirmacaoADX) {
      if(InpADXMinimo <= 0 || InpADXMinimo >= 100) {
         Log("Parametro invalido: o limiar do ADX deve ficar entre 0 e 100.");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(InpBarrasConfirmacao < 0) {
         Log("Parametro invalido: as barras de confirmacao nao podem ser negativas.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(InpLote <= 0) {
      Log("Parametro invalido: a quantidade de lote deve ser maior que zero.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpStopLoss <= 0 || InpTakeProfit <= 0) {
      Log("Parametro invalido: Stop Loss e Take Profit devem ser maiores que zero.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTravaZeroAZero && InpGatilhoZeroAZero <= 0) {
      Log("Parametro invalido: o gatilho da trava no zero a zero deve ser maior que zero.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpGanhoMaxDia < 0 || InpPerdaMaxDia < 0) {
      Log("Parametro invalido: os limites diarios nao podem ser negativos (use 0 para desligar).");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!ParseHora(InpHoraInicio, g_min_inicio)) {
      Log("Parametro invalido: horario de inicio fora do formato HH:MM.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!ParseHora(InpHoraFim, g_min_fim)) {
      Log("Parametro invalido: horario de fim fora do formato HH:MM.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!ParseHora(InpHoraFechamento, g_min_fechamento)) {
      Log("Parametro invalido: horario de encerramento fora do formato HH:MM.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(g_min_inicio >= g_min_fim) {
      Log("Parametro invalido: o horario de inicio deve ser anterior ao de fim.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(g_min_fechamento < g_min_fim) {
      Log("Parametro invalido: o horario de encerramento nao pode ser anterior ao de fim.");
      return INIT_PARAMETERS_INCORRECT;
   }

   // --- especificacoes do simbolo ----------------------------------
   g_ponto     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_vol_min   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_vol_max   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_vol_step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(g_ponto <= 0) {
      Log(StringFormat("Nao foi possivel ler as especificacoes de %s.", _Symbol));
      return INIT_FAILED;
   }
   if(g_vol_max > 0 && InpLote > g_vol_max) {
      Log(StringFormat("Parametro invalido: lote %.2f acima do maximo de %.2f para %s.",
                       InpLote, g_vol_max, _Symbol));
      return INIT_PARAMETERS_INCORRECT;
   }

   // --- indicador ---------------------------------------------------
   // O handle e criado uma unica vez aqui e liberado no OnDeinit; criar
   // indicador dentro do OnTick vaza recurso a cada tick.
   // Um unico iADX cobre a estrategia inteira: buffer 0 = ADX, 1 = DI+, 2 = DI-.
   g_dmi_handle = iADX(_Symbol, PERIOD_CURRENT, InpDMIPeriodo);
   if(g_dmi_handle == INVALID_HANDLE) {
      Log(StringFormat("Falha ao criar o indicador DMI/ADX (erro %d).", GetLastError()));
      return INIT_FAILED;
   }
   // --- objeto de negociacao ---------------------------------------
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(DESVIO_MAXIMO_PONTOS);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   long modo_conta = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(modo_conta != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Log("AVISO: conta nao e hedging; em netting, posicoes manuais e do robo podem ser agregadas por simbolo.");

   // --- estado ------------------------------------------------------
   g_dia = InicioDoDia(TimeCurrent());
   g_bloqueado_hoje = false;
   g_barra_avaliada = 0;
   g_ultima_recusa = "";
   g_painel_atualizado = 0;
   DesarmarSinal();

   Log(StringFormat("ADX Bussola iniciado em %s | DMI(%d) | lote %.2f | SL %.0f / TP %.0f pts",
                    _Symbol, InpDMIPeriodo, InpLote, InpStopLoss, InpTakeProfit));
   Log(InpUsarConfirmacaoADX
       ? StringFormat("Confirmacao por ADX LIGADA: exige ADX >= %.1f e subindo, ate %d barra(s) apos o cruzamento",
                      InpADXMinimo, InpBarrasConfirmacao)
       : "Confirmacao por ADX DESLIGADA: o cruzamento de DI+ e DI- ja e a entrada");
   Log(InpModoEntrada == MODO_ESTADO
       ? StringFormat("Modo de entrada: ESTADO (DI dominante + ADX >= %.1f e subindo)", InpADXMinimo)
       : "Modo de entrada: CRUZAMENTO (virada de DI+ e DI-)");
   if(InpTravaZeroAZero)
      Log(StringFormat("Trava no zero a zero LIGADA: stop vai para a entrada apos %.0f pts a favor",
                       InpGatilhoZeroAZero));
   Log(StringFormat("Janela %s as %s | encerramento %s | limites diarios +%.2f / -%.2f",
                    InpHoraInicio, InpHoraFim, InpHoraFechamento,
                    InpGanhoMaxDia, InpPerdaMaxDia));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(g_dmi_handle != INVALID_HANDLE) {
      IndicatorRelease(g_dmi_handle);
      g_dmi_handle = INVALID_HANDLE;
   }
   Comment("");
   Log(StringFormat("ADX Bussola finalizado (motivo %d).", reason));
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//|                                                                  |
//| Protecao (encerramento por horario e trava diaria) roda a cada    |
//| tick. A decisao de entrar roda so na barra fechada.               |
//+------------------------------------------------------------------+
void OnTick() {
   AtualizarDia();
   AtualizarPainel();

   // 1. Horario de encerramento: nenhuma posicao do robo atravessa o fim do
   //    pregao, mesmo que o alvo ainda nao tenha sido atingido.
   if(PassouDoFechamento()) {
      if(TemPosicaoPropria())
         FecharPosicoesProprias("horario de encerramento");
      LogRecusa("fora do horario: passou do horario de encerramento");
      return;
   }

   // 2. Trava diaria de resultado.
   if(TravaDiariaAtingida()) {
      LogRecusa("trava diaria atingida: sem novas entradas ate o proximo pregao");
      return;
   }

   // 3. Protecao da posicao aberta: tambem roda a cada tick, pelo mesmo
   //    motivo do encerramento por horario - esperar a barra fechar deixaria
   //    a posicao desamparada por ate 15 minutos.
   AplicarTravaZeroAZero();

   // 4. Daqui para baixo, so na barra fechada.
   if(!NovaBarra())
      return;

   // 5. Uma posicao por vez. Com posicao aberta o robo nao avalia sinal, entao
   //    um lado armado antes dela ficaria congelado e dispararia muito depois
   //    do cruzamento que o gerou. Esquecer aqui evita essa entrada tardia.
   if(TemPosicaoPropria()) {
      DesarmarSinal();
      LogRecusa("ja existe posicao aberta deste robo");
      return;
   }

   // 6. Janela de funcionamento.
   if(!DentroDaJanela()) {
      LogRecusa("fora da janela de horario de funcionamento");
      return;
   }

   // 7. Sinal do indicador.
   ENUM_SINAL sinal = SinalAtual();
   if(sinal == SINAL_NENHUM)
      return;

   g_ultima_recusa = "";
   EnviarOrdem(sinal == SINAL_COMPRA);
}
//+------------------------------------------------------------------+
