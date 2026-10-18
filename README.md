# CARRIN — Sua lista, sem complicação. 🛒

> **Versão:** `1.3.563` (Build `563`) — Outubro de 2026  
> **Status:** Produção Estável  
> **Framework:** Flutter 3.x / Dart 3.x  

O **CARRIN** é um ecossistema mobile inteligente em Flutter para gestão financeira doméstica, compras de supermercado e economia colaborativa comunitária. O aplicativo combina privacidade total em nuvem pessoal com inteligência coletiva de preços.

---

## ✨ Principais Funcionalidades

* 📱 **Privacidade Total com Google Sheets:** Sincronização direta com a planilha pessoal do seu Google Drive via OAuth 2.0 ([`UserSheetsService`](file:///C:/Dev/CARRIN/lib/services/user_sheets_service.dart)). Seus dados nunca passam por servidores de terceiros.
* ⚡ **Arquitetura Offline-First (SQLite):** Todas as operações funcionam instantaneamente mesmo sem sinal no supermercado, com fila resiliente de sincronização em segundo plano.
* 💵 **Vírgula Automática em Tempo Real (`CurrencyInputFormatter`):** Máscara monetária que caminha os centavos da direita para a esquerda conforme o usuário digita nos teclados numéricos (ex: `1` $\rightarrow$ `0,01`, `12` $\rightarrow$ `0,12`, `1299` $\rightarrow$ `12,99`), presente em todos os diálogos de preço, orçamento, balança e teto financeiro do aplicativo sem precisar caçar a tecla vírgula.
* 📡 **Radar de Preços Comunitário (Supabase):** 
  - Carregamento instantâneo via cache SQLite com sincronização assíncrona em background.
  - **Comparador Inteligente:** Filtro horizontal de supermercados, cartões consolidados por loja, cálculo de economia percentual (%) e seleção sob demanda por toque.
  - **Mercados:** Pesquisa instantânea pelo nome/bairro e filtro por redes de supermercado (`Guanabara`, `Supermarket`, `Rede Economia`, `Assaí`, `Mundial`, `Real`, `Atacadão`, `Grand Marché`, `Prezunic`, `Princesa`, `Extra`, `Dia`, `Hortifruti`, `Extrabom`, etc.).
* 🗺️ **Mapa Geográfico Interativo (Estilo Google Maps + Base Maps.me `.mwm`):** 
  - **Seletor de Tipo de Mapa (Estilo Google Maps):** Escolha entre **Padrão Google (Desenhado)**, **Satélite + Ruas**, **Relevo**, **Mapa Limpo**, **OpenStreetMap** e **Modo Noturno**, com controle para exibir/ocultar pinos e modo de **Escolher Ponto ou Mercado Tocando no Mapa** sem nenhum conflito visual.
  - Renderização ultrarrápida a 60 FPS com pinos leves (`RepaintBoundary`) para **3.484 supermercados e atacadistas geolocalizados** extraídos diretamente dos mapas `.mwm` (Rio de Janeiro, Niterói, São Gonçalo, Maricá, Itaboraí, Região dos Lagos/Serrana/Baixada, Espírito Santo e São Paulo).
  - Exibição limpa somente com pinos: o nome e preço do mercado aparecem sob demanda ao tocar no pino, mantendo o mapa fluido e sem poluição visual.
  - Barra de pesquisa integrada no topo do mapa com autocompletar instantâneo + chips horizontais de filtro por redes de supermercados.
  - Destaque supremo do supermercado mais barato da região com uma **Coroa de Ouro (`👑`)**.
  - Traçado de rotas externas direto no **Google Maps** ou **Waze** com 1 toque.
* 📍 **Geofencing & Unificação Canônica:** Reconhecimento automático ao chegar ao supermercado, calibrado e unificado para o *Supermercados Guanabara Niterói*.
* 🧾 **Scanner Duplo Inteligente:**
  - **Código de Barras Zero-Fricção (EAN-13 / EAN-8):** Abre instantaneamente (0ms) o menu de edição de produto sem nenhum popup intermediário de confirmação, buscando e preenchendo automaticamente nome oficial, marca, categoria sugerida e último preço via histórico local e API aberta do **Open Food Facts / Open Beauty Facts / Open Products Facts** ([`BarcodeLookupService`](file:///C:/Dev/CARRIN/lib/services/barcode_lookup_service.dart)).
  - **Cupom Fiscal / NFC-e (SEFAZ QR Code):** Leitura de notas fiscais com extração automatizada de itens, quantidades fracionárias e valores.
* ⚖️ **Calculadora de Peso (Kg):** Calcula a quantidade comprada automaticamente ao digitar o preço por quilo e o valor total na balança.
* 🧮 **Calculadora Flutuante & Rateio:** Assistente de cálculo rápido em cima da lista e divisão de conta por pessoa com 1 toque.
* 📊 **Análises & Perfil de Comprador:** Gráficos interativos (`fl_chart`) e algoritmo que traça seu perfil de consumo (Econômico, Gourmet, Planejador, etc.).
* 🎓 **Cards de Demonstração e Tutoriais Interativos por Aba (`InteractiveTabTutorial`):** Na primeira visita a cada aba/tela (e nos estados vazios de *Meus Carrinhos* e *Estatísticas*), o usuário conta com simuladores interativos passo a passo ([`InteractiveSectionTutorialCard`](file:///C:/Dev/CARRIN/lib/widgets/interactive_tab_tutorial.dart)) e acesso rápido pelo botão `?` no topo de todas as telas.
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

