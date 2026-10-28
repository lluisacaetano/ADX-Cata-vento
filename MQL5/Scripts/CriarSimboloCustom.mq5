//+------------------------------------------------------------------+
//|                                        CriarSimboloCustom.mq5    |
//|                                                                  |
//|  Cria um simbolo CUSTOM clonando as especificacoes e o historico  |
//|  M1 do WIN$N local.                                              |
//|                                                                  |
//|  Motivo: simbolo custom nao sincroniza com o servidor da          |
//|  corretora, entao o Strategy Tester usa apenas o historico em     |
//|  disco. Com a conexao do terminal instavel, e a unica forma de    |
//|  rodar backtest.                                                 |
//+------------------------------------------------------------------+
#property copyright "Luisa Caetano"
#property version   "1.00"
// sem script_show_inputs: o dialogo de parametros travaria a execucao headless

input string InpOrigem  = "WINV26";      // Simbolo de origem (de onde copiar)
input string InpDestino = "WINV26_LOCAL"; // Nome do simbolo custom a criar
input string InpDe      = "2026.06.01"; // Copiar barras a partir de (AAAA.MM.DD)
input string InpAte     = "2026.08.22"; // Copiar barras ate (AAAA.MM.DD)
input string InpApagar  = "";            // Simbolo custom antigo a remover (vazio = nao remove)

void OnStart() {
   datetime de  = StringToTime(InpDe);
   datetime ate = StringToTime(InpAte);

   PrintFormat("=== Criando %s a partir de %s (%s a %s) ===",
               InpDestino, InpOrigem, TimeToString(de), TimeToString(ate));

   // A origem precisa estar no Observacao de Mercado para o historico ficar
   // acessivel ao CopyRates.
   if(!SymbolSelect(InpOrigem, true)) {
      PrintFormat("ERRO: nao foi possivel selecionar %s (erro %d)", InpOrigem, GetLastError());
      return;
   }

   // A forma de 3 argumentos clona TODAS as especificacoes da origem:
   // digitos, tamanho e valor do tick, tamanho de contrato, modo de calculo,
   // moeda. Evita o erro classico de montar o WIN com molde de dolar.
   if(!CustomSymbolCreate(InpDestino, "Custom\\B3", InpOrigem)) {
      int erro = GetLastError();
      if(erro == 5300 || erro == 5304) {
         PrintFormat("%s ja existe, seguindo para atualizar o historico.", InpDestino);
      } else {
         PrintFormat("ERRO: CustomSymbolCreate falhou (erro %d)", erro);
         return;
      }
   }

   MqlRates barras[];
   ArraySetAsSeries(barras, false);

   int copiadas = CopyRates(InpOrigem, PERIOD_M1, de, ate, barras);
   if(copiadas <= 0) {
      PrintFormat("ERRO: CopyRates(%s, M1) retornou %d (erro %d). "
                  "O historico M1 pode nao estar carregado em disco.",
                  InpOrigem, copiadas, GetLastError());
      return;
   }
   PrintFormat("Barras M1 lidas de %s: %d (de %s ate %s)",
               InpOrigem, copiadas,
               TimeToString(barras[0].time), TimeToString(barras[copiadas - 1].time));

   int gravadas = CustomRatesUpdate(InpDestino, barras);
   if(gravadas < 0) {
      PrintFormat("ERRO: CustomRatesUpdate falhou (erro %d)", GetLastError());
      return;
   }
   PrintFormat("Barras gravadas em %s: %d", InpDestino, gravadas);

   if(!SymbolSelect(InpDestino, true))
      PrintFormat("AVISO: nao consegui adicionar %s ao Observacao de Mercado (erro %d)",
                  InpDestino, GetLastError());

   // Remove o simbolo antigo, se houver, para nao deixar lixo no terminal.
   if(StringLen(InpApagar) > 0 && InpApagar != InpDestino) {
      // Simbolo selecionado no Observacao de Mercado nao pode ser apagado (erro 5306).
      SymbolSelect(InpApagar, false);
      if(CustomSymbolDelete(InpApagar))
         PrintFormat("Simbolo antigo %s removido.", InpApagar);
      else
         PrintFormat("AVISO: nao removi %s (erro %d) - pode estar em uso.", InpApagar, GetLastError());
   }

   PrintFormat("=== %s pronto | digitos %d | tick %.5f | valor do tick %.5f | contrato %.2f ===",
               InpDestino,
               (int)SymbolInfoInteger(InpDestino, SYMBOL_DIGITS),
               SymbolInfoDouble(InpDestino, SYMBOL_TRADE_TICK_SIZE),
               SymbolInfoDouble(InpDestino, SYMBOL_TRADE_TICK_VALUE),
               SymbolInfoDouble(InpDestino, SYMBOL_TRADE_CONTRACT_SIZE));
}
//+------------------------------------------------------------------+
