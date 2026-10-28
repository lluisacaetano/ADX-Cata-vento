//+------------------------------------------------------------------+
//|                                          ExportarBarrasDMI.mq5   |
//|                                                                  |
//|  Exporta barras M15 e o DMI (ADX, DI+, DI-) para CSV, para       |
//|  desenhar o grafico do slide 02 com dados reais em vez de uma     |
//|  serie sintetica.                                                 |
//|                                                                   |
//|  Os tres valores saem do MESMO handle iADX, nos buffers 0, 1 e 2 -|
//|  e e por isso que o robo usa um indicador so.                     |
//+------------------------------------------------------------------+
#property copyright "Luisa Caetano"
#property version   "1.00"

input string InpSimbolo = "WINV26_LOCAL";   // Simbolo de origem
input int    InpDMIPer  = 12;               // Periodos do DMI (igual ao robo)
input int    InpBarras  = 700;              // Quantas barras exportar
input string InpArquivo = "barras_dmi.csv"; // Arquivo de saida

void OnStart() {
   if(!SymbolSelect(InpSimbolo, true)) {
      PrintFormat("ERRO: nao consegui selecionar %s (erro %d)", InpSimbolo, GetLastError());
      return;
   }

   int handle = iADX(InpSimbolo, PERIOD_M15, InpDMIPer);
   if(handle == INVALID_HANDLE) {
      PrintFormat("ERRO: iADX falhou (erro %d)", GetLastError());
      return;
   }

   MqlRates barras[];
   ArraySetAsSeries(barras, false);
   int n = CopyRates(InpSimbolo, PERIOD_M15, 0, InpBarras, barras);
   if(n <= 0) {
      PrintFormat("ERRO: CopyRates retornou %d (erro %d)", n, GetLastError());
      IndicatorRelease(handle);
      return;
   }

   double adx[], dip[], dim[];
   ArraySetAsSeries(adx, false);
   ArraySetAsSeries(dip, false);
   ArraySetAsSeries(dim, false);
   int a = CopyBuffer(handle, 0, 0, n, adx);
   int p = CopyBuffer(handle, 1, 0, n, dip);
   int m = CopyBuffer(handle, 2, 0, n, dim);
   IndicatorRelease(handle);
   if(a <= 0 || p <= 0 || m <= 0) {
      PrintFormat("ERRO: CopyBuffer do DMI retornou %d/%d/%d (erro %d)", a, p, m, GetLastError());
      return;
   }

   int menor = MathMin(a, MathMin(p, m));   // os tres buffers tem o mesmo aquecimento
   int desloc = n - menor;

   int arq = FileOpen(InpArquivo, FILE_WRITE|FILE_CSV|FILE_ANSI, ';');
   if(arq == INVALID_HANDLE) {
      PrintFormat("ERRO: nao consegui abrir %s (erro %d)", InpArquivo, GetLastError());
      return;
   }

   FileWrite(arq, "hora", "abertura", "maxima", "minima", "fechamento", "adx", "dimais", "dimenos");
   for(int i = desloc; i < n; i++) {
      int j = i - desloc;
      FileWrite(arq,
                TimeToString(barras[i].time, TIME_DATE|TIME_MINUTES),
                DoubleToString(barras[i].open,  0),
                DoubleToString(barras[i].high,  0),
                DoubleToString(barras[i].low,   0),
                DoubleToString(barras[i].close, 0),
                DoubleToString(adx[j], 2),
                DoubleToString(dip[j], 2),
                DoubleToString(dim[j], 2));
   }
   FileClose(arq);

   PrintFormat("Exportadas %d barras M15 de %s (de %s ate %s) para %s",
               menor, InpSimbolo,
               TimeToString(barras[desloc].time), TimeToString(barras[n-1].time),
               InpArquivo);
}
//+------------------------------------------------------------------+
