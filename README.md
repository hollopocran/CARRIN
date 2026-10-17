# CARRIN — Sua lista, sem complicação. 🛒

> **Versão:** `1.3.545` (Build `545`) — Outubro de 2026  
> **Status:** Produção Estável  
> **Framework:** Flutter 3.x / Dart 3.x  

O **CARRIN** é um ecossistema mobile inteligente em Flutter para gestão financeira doméstica, compras de supermercado e economia colaborativa comunitária. O aplicativo combina privacidade total em nuvem pessoal com inteligência coletiva de preços.

---

## ✨ Principais Funcionalidades

* 📱 **Privacidade Total com Google Sheets:** Sincronização direta com a planilha pessoal do seu Google Drive via OAuth 2.0 ([`UserSheetsService`](file:///C:/Dev/CARRIN/lib/services/user_sheets_service.dart)). Seus dados nunca passam por servidores de terceiros.
* ⚡ **Arquitetura Offline-First (SQLite):** Todas as operações funcionam instantaneamente mesmo sem sinal no supermercado, com fila resiliente de sincronização em segundo plano.
* 📡 **Radar de Preços Comunitário (Supabase):** 
  - Feed colaborativo em tempo real com distância calculada via GPS.
  - **Comparador Inteligente:** Filtro horizontal de supermercados (`Todos os Mercados`, `Supermercados Guanabara`), cartões consolidados por loja (sem repetição de datas/cards), cálculo de economia percentual (%) e seleção sob demanda por toque.
  - Ranking de supermercados mais econômicos da região.
* 🗺️ **Mapa Geográfico Interativo (OpenStreetMap):** 
  - Renderização fluida com `flutter_map` e `latlong2` nos modos Claro (OSM Standard) e Escuro (CartoDB Dark Matter).
  - Pinos dos **154 supermercados geolocalizados** com endereços físicos reais em Niterói, São Gonçalo, Maricá, Itaboraí e Rio de Janeiro.
  - Destaque supremo do supermercado mais barato da região com uma **Coroa de Ouro (`👑`)**.
  - Barra de busca instantânea por loja ou bairro (ex: *"Tribobó"*, *"Inoã"*, *"Guanabara"*).
  - Carrossel horizontal deslizante sincronizado com o mapa.
  - Traçado de rotas externas direto no **Google Maps** ou **Waze** com 1 toque.
* 📍 **Geofencing & Unificação Canônica:** Reconhecimento automático ao chegar ao supermercado, calibrado e unificado para o *Supermercados Guanabara Niterói*.
* 🧾 **Scanner Duplo Inteligente:**
  - **Código de Barras Zero-Fricção (EAN-13 / EAN-8):** Identificação em camadas via histórico local SQLite e API aberta do **Open Food Facts Brasil** ([`BarcodeLookupService`](file:///C:/Dev/CARRIN/lib/services/barcode_lookup_service.dart)), preenchendo automaticamente nome oficial, marca, categoria sugerida e abrindo direto o formulário de item sem popups intermediários.
  - **Cupom Fiscal / NFC-e (SEFAZ QR Code):** Leitura de notas fiscais com extração automatizada de itens, quantidades fracionárias e valores.
* ⚖️ **Calculadora de Peso (Kg):** Calcula a quantidade comprada automaticamente ao digitar o preço por quilo e o valor total na balança.
* 🧮 **Calculadora Flutuante & Rateio:** Assistente de cálculo rápido em cima da lista e divisão de conta por pessoa com 1 toque.
* 📊 **Análises & Perfil de Comprador:** Gráficos interativos (`fl_chart`) e algoritmo que traça seu perfil de consumo (Econômico, Gourmet, Planejador, etc.).
* 🎨 **Personalização & Acessibilidade:** Temas Claro, Escuro e Pastel, seletor de ícone do app, modos para daltônicos (Protanopia, Deuteranopia, Tritanopia) e controle dinâmico da escala de fonte.
* 📄 **Exportação em PDF:** Gere relatórios profissionais das compras para impressão ou compartilhamento direto no WhatsApp.

---

## 🗺️ Mapa do Aplicativo (5 Abas no Rodapé)

1. **Início ([`DashboardScreen`](file:///C:/Dev/CARRIN/lib/screens/dashboard_screen.dart)):** Medidor circular de orçamento, grid reordenável de métricas, busca rápida de produtos e atalhos.
2. **Carrinhos ([`MonthSelectionScreen`](file:///C:/Dev/CARRIN/lib/screens/month_selection_screen.dart) ➔ [`ShoppingListScreen`](file:///C:/Dev/CARRIN/lib/screens/shopping_list_screen.dart)):** Histórico cronológico orgânico de carrinhos, lista interativa com slivers, leitor de código de barras, leitor de NFC-e, divisão de conta e exportação PDF.
3. **Análises ([`StatisticsScreen`](file:///C:/Dev/CARRIN/lib/screens/statistics_screen.dart)):** Gráficos de evolução mensal, gastos por categoria e diagnóstico de perfil de comprador.
4. **Comunidade ([`CommunityRadarScreen`](file:///C:/Dev/CARRIN/lib/screens/community_radar_screen.dart)):** Feed comunitário, comparador desduplicado por mercado, ranking regional e atalho direto para o mapa geográfico interativo ([`MarketMapScreen`](file:///C:/Dev/CARRIN/lib/screens/market_map_screen.dart)).
5. **Ajustes ([`SettingsScreen`](file:///C:/Dev/CARRIN/lib/screens/settings_screen.dart)):** Paleta de temas, ícone do aplicativo, filtros de acessibilidade visual, backup/restauração do banco SQLite e termos de uso.

---

## 🚀 Como Executar o Projeto

### Pré-requisitos:
- [Flutter SDK](https://flutter.dev) instalado (versão `>=3.0.0 <4.0.0`).
- Dispositivo Android conectado via USB (com depuração ativada) ou emulador.

```bash
# 1. Instalar as dependências
flutter pub get

# 2. Executar em modo debug
flutter run

# 3. Compilar APK de Produção (Release)
flutter build apk --release
```

O arquivo gerado fica localizado em `build/app/outputs/flutter-apk/app-release.apk` (e cópias prontas para instalação em `apks/`).

---

## 📖 Documentação Completa

Para a análise aprofundada da arquitetura de dados (SQLite, Supabase, Google Sheets API), diagrama Mermaid do mapa do app e histórico detalhado de versões, consulte o arquivo [DOCUMENTATION.md](file:///C:/Dev/CARRIN/DOCUMENTATION.md).

