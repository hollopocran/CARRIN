# Documentação Técnica e Arquitetural: CARRIN

> **Versão Atual:** `1.3.583` (Build `583`) — Outubro de 2026  
> **Status:** Produção Estável  
> **Slogan:** *"Sua lista, sem complicação."*

---

## 1. Visão Geral do Projeto

O **CARRIN** é um ecossistema mobile inteligente em Flutter para gestão financeira doméstica, compras de supermercado e economia colaborativa comunitária. O aplicativo une privacidade total com poder analítico:
1. **Privacidade Absoluta & Nuvem Pessoal:** Cada usuário sincroniza suas listas diretamente com sua própria planilha do **Google Sheets** via OAuth 2.0 ([`UserSheetsService`](file:///C:/Dev/CARRIN/lib/services/user_sheets_service.dart)), sem servidores intermediários ou acesso de terceiros aos seus dados pessoais.
2. **Arquitetura Offline-First (SQLite):** Todas as operações (adicionar, riscar, editar, excluir, calcular) funcionam instantaneamente sem internet com persistência em banco local e sincronização resiliente em fila (`sync_queue`).
3. **Radar de Preços & Comunidade (Supabase):** Rede colaborativa de preços em tempo real onde os produtos comprados alimentam a base comunitária, permitindo comparação de preços por produto, agrupamento por mercado único, identificação do estabelecimento mais barato da região e cálculo de economia potencial via GPS.
4. **Geolocalização, Mapa em Tempo Real Estilo Google Maps & Catálogo de 3.484 Supermercados (Base Maps.me `.mwm`):** Mapa geográfico interativo com rastreamento GPS contínuo ao vivo, marcador animado estilo radar/pulso ([`PulsingUserLocationMarker`](file:///C:/dev/CARRIN/lib/widgets/pulsing_user_location_marker.dart)), orientação por feixe de bússola, modo seguir usuário (com travamento suave da câmera no trajeto), recálculo dinâmico de distâncias aos mercados em tempo real, seletor de 6 estilos de camadas (**Padrão Google Desenhado**, **Satélite + Ruas**, **Relevo**, **Mapa Limpo**, **OpenStreetMap** e **Noturno**), seleção de ponto no mapa, rotas externas (Google Maps/Waze) e geofencing calibrado.
5. **Scanner Duplo Inteligente:**
   - **Leitor de Código de Barras (EAN-13 / EAN-8):** Identificação em camadas via histórico local do SQLite e consulta à API aberta do **Open Food Facts Brasil** ([`BarcodeLookupService`](file:///C:/Dev/CARRIN/lib/services/barcode_lookup_service.dart)), com abertura direta do formulário de item sem popups intermediários intrusivos.
   - **Leitor de Cupom Fiscal / NFC-e SEFAZ:** Leitura automatizada via QR Code com extração inteligente de produtos, quantidades, unidades e valores.

---

## 2. Mapa Completo do Aplicativo (App Sitemap)

### 2.1 Diagrama de Navegação e Fluxo de Telas (Mermaid)

> [!TIP]
> Os diagramas abaixo foram modularizados por áreas de fluxo do aplicativo. Dessa forma, cada diagrama é renderizado em escala natural de 100%, com fontes grandes, nítidas e legíveis sem necessidade de dar zoom na tela.

#### 2.1.1 Arquitetura Geral de Navegação (Hub & 5 Abas)
```mermaid
flowchart LR
  Splash["SplashScreen<br/><b>Inicialização & Sessão</b>"] --> Main["MainScreen<br/><b>Navegação Principal (Rodapé)</b>"]
  Main --> Tab0["1. Início<br/><b>DashboardScreen</b>"]
  Main --> Tab1["2. Carrinhos<br/><b>MonthSelectionScreen</b>"]
  Main --> Tab2["3. Análises<br/><b>StatisticsScreen</b>"]
  Main --> Tab3["4. Comunidade<br/><b>CommunityRadarScreen</b>"]
  Main --> Tab4["5. Ajustes<br/><b>SettingsScreen</b>"]
```

#### 2.1.2 Fluxo da Home & Meus Carrinhos (Abas 1 e 2)
```mermaid
flowchart TD
  subgraph Home["Aba 1: Início (Dashboard)"]
    Dash["DashboardScreen<br/>(Saldo, Orçamento & Atalhos)"]
    Accounts["AccountsScreen<br/>(Perfis Locais & Google OAuth)"]
    Dash --> Accounts
  end

  subgraph Carts["Aba 2: Carrinhos & Compras"]
    Months["MonthSelectionScreen<br/>(Mais Recentes no Topo • Toggle Ordem)"]
    Shop["ShoppingListScreen<br/>(Lista Ativa de Compras)"]
    AddItem["Modal Adicionar/Editar Item<br/>(Nome, Preço, Qtd, Categoria, Barcode)"]
    BarScan["BarcodeScannerScreen<br/>(Scanner EAN-13 / EAN-8)"]
    RecScan["ReceiptScannerScreen<br/>(NFC-e / SEFAZ QR Code)"]
    Calculators["Calculadoras Assistivas<br/>(Preço/Kg & Flutuante)"]
    Share["Exportação<br/>(PDF & WhatsApp)"]
    Rateio["RateioDialog<br/>(Divisão de Conta)"]

    Months --> Shop
    Shop --> AddItem
    Shop --> BarScan
    Shop --> RecScan
    Shop --> Calculators
    Shop --> Share
    Shop --> Rateio
    BarScan -->|"Lookup Rápido"| AddItem
  end

  Dash -->|"Abre Carrinho Ativo"| Shop
```

#### 2.1.3 Fluxo de Análises, Radar Comunitário & Mapa (Abas 3 e 4)
```mermaid
flowchart TD
  subgraph TabAnalytics["Aba 3: Análises"]
    Stats["StatisticsScreen<br/>(Gráficos FL Chart & Gastos)"]
    Profile["BuyerProfileScreen<br/>(Perfil de Comprador)"]
    Stats --> Profile
  end

  subgraph TabCommunity["Aba 4: Comunidade & Mapa Geográfico"]
    Radar["CommunityRadarScreen<br/>(2 Abas Consolidadas)"]
    SubOffers["1. Ofertas<br/>(Feed Dinâmico + Busca de Comparação Integrada)"]
    SubMarkets["2. Mercados<br/>(Ranking Regional por GPS)"]
    Collab["Colaborar Preço<br/>(FAB na Cor do Tema)"]
    
    Radar --> SubOffers
    Radar --> SubMarkets
    Radar --> Collab
    
    Map["MarketMapScreen<br/>(GPS em Tempo Real • Pulso & Bússola • Modo Seguir • 3.484 Lojas)"]
    Radar -->|"Atalho Mapa"| Map
    
    Map --> PulseGPS["Rastreamento GPS em Tempo Real<br/>(Pulso Radar Animado • Feixe de Bússola • Modo Seguir)"]
    Map --> DynamicDist["Recálculo Dinâmico<br/>(Distâncias Atualizadas em Tempo Real nos Pins e Cards)"]
    Map --> Layers["6 Estilos de Camadas<br/>(Google, Satélite, OSM, Dark)"]
    Map --> PointPick["Seleção de Ponto<br/>(Toque no Mapa • Ir até Aqui)"]
    Map --> SearchMap["Busca Rápida & Redes<br/>(Filtro de Lojas com Sugestões)"]
    Map --> ExternalNav["Rotas Externas<br/>(Google Maps & Waze)"]
  end
```

#### 2.1.4 Fluxo de Ajustes, Personalização & Sistema (Aba 5)
```mermaid
flowchart TD
  subgraph TabSettings["Aba 5: Ajustes & Sistema"]
    Settings["SettingsScreen<br/>(Painel Central de Ajustes)"]
    Themes["ThemeColorPickerSheet<br/>(Cores do Ícone & Coleções)"]
    Access["Acessibilidade<br/>(Modos Daltônicos & Escala)"]
    Backup["Backup & Restauração<br/>(SQLite JSON Local)"]
    Tutorials["Tutorial Interativo<br/>(Acesso na Home & Configurações)"]
    Terms["TermsScreen<br/>(Termos de Uso & LGPD)"]

    Settings --> Themes
    Settings --> Access
    Settings --> Backup
    Settings --> Tutorials
    Settings --> Terms
  end
```

### 2.2 Estrutura Detalhada de Rotas e Telas

| Tela / Rota / Serviço | Arquivo Fonte | Responsabilidade Principal |
| :--- | :--- | :--- |
| **SplashScreen** | [`lib/screens/splash_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/splash_screen.dart) | Animação cinematográfica de entrada com motion design vetorial, física de partículas, inicialização assíncrona do SQLite, preferências e GPS. |
| **MainScreen** | [`lib/screens/main_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/main_screen.dart) | Host principal com `PageView` e `BottomNavigationBar` de 5 posições com navegação resiliente (`PopScope`) e transições horizontais livres. |
| **DashboardScreen** | [`lib/screens/dashboard_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/dashboard_screen.dart) | Visão geral do mês ativo, medidor circular (gauge), grid reordenável de métricas, atalhos rápidos e botões de workspace fiéis ao tema sem poluição de interrogação. |
| **MonthSelectionScreen** | [`lib/screens/month_selection_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/month_selection_screen.dart) | Lista de carrinhos com ordenação inteligente (mais recentes no topo por padrão), botão alternador de ordem (`Icons.arrow_downward_rounded` / `Icons.arrow_upward_rounded`) com persistência, progresso de itens e status trancado. |
| **ShoppingListScreen** | [`lib/screens/shopping_list_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/shopping_list_screen.dart) | Lista de compras com slivers responsivos, seleção em lote, cálculo de peso, scanner, rateio, máscara monetária em tempo real e exportação PDF. |
| **StatisticsScreen** | [`lib/screens/statistics_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/statistics_screen.dart) | Relatórios visuais com `fl_chart`, evolução mensal, divisão por categorias e atalho para o perfil de hábitos. |
| **BuyerProfileScreen** | [`lib/screens/buyer_profile_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/buyer_profile_screen.dart) | Diagnóstico inteligente do perfil de consumo (Econômico, Gourmet, Planejador, etc.) e métricas de hábito. |
| **CommunityRadarScreen** | [`lib/screens/community_radar_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/community_radar_screen.dart) | Radar comunitário consolidado em 2 abas (Ofertas com feed e busca inteligente integrada, e Mercados com ranking regional de economia por GPS), botão Colaborar Preço na cor do tema e atalho para o Mapa em tempo real. |
| **MarketMapScreen** | [`lib/screens/market_map_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/market_map_screen.dart) | Mapa geográfico interativo estilo Google Maps com rastreamento GPS ao vivo em tempo real, marcador pulsante (radar), orientação de direção (feixe de bússola), modo seguir câmera, recálculo dinâmico de distâncias aos estabelecimentos, 6 estilos visuais de camadas (Google Padrão, Satélite, Relevo, Limpo, OSM e CartoDB Dark), catálogo de 3.484 supermercados (RJ, ES e SP), badge dourado `👑` para o mais barato, seleção de ponto tocando no mapa, filtro de redes, carrossel inferior sincronizado, busca rápida com sugestões e rotas externas (Google Maps/Waze). |
| **PulsingUserLocationMarker** | [`lib/widgets/pulsing_user_location_marker.dart`](file:///C:/Dev/CARRIN/lib/widgets/pulsing_user_location_marker.dart) | Marcador animado com `AnimationController` estilo radar/pulso contínuo para renderizar a localização do usuário com anéis de precisão e feixe direcional de bússola. |
| **SettingsScreen** | [`lib/screens/settings_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/settings_screen.dart) | Customização de 36 temas e cores do ícone, seletor de ícone do app, acessibilidade/modos daltônicos, backup/restore, reset de tutoriais e sobre. |
| **AccountsScreen** | [`lib/screens/accounts_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/accounts_screen.dart) | Gestão de login Google OAuth 2.0 e perfis locais offline isolados. |
| **ReceiptScannerScreen** | [`lib/screens/receipt_scanner_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/receipt_scanner_screen.dart) | Scanner de NFC-e (SEFAZ QR Code) com parser de cupons de 1 e 2 linhas. |
| **BarcodeScannerScreen** | [`lib/screens/barcode_scanner_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/barcode_scanner_screen.dart) | Scanner de códigos de barras EAN-13/EAN-8 para inserção e busca instantânea. |
| **BarcodeLookupService** | [`lib/services/barcode_lookup_service.dart`](file:///C:/Dev/CARRIN/lib/services/barcode_lookup_service.dart) | Motor de resolução em camadas (SQLite local + Open Food Facts Brasil REST + IA de categorias) com fluxo zero-fricção direto para edição. |
| **DefaultSupermarketsData** | [`lib/services/default_supermarkets.dart`](file:///C:/Dev/CARRIN/lib/services/default_supermarkets.dart) | Catálogo oficial de 3.484 supermercados geolocalizados com endereço físico completo em Niterói, São Gonçalo, Maricá, Itaboraí, Rio de Janeiro e estados vizinhos (extraído e calibrado via Maps.me `.mwm`, OpenStreetMap e Photon). |
| **CommunityPriceService** | [`lib/services/community_price_service.dart`](file:///C:/Dev/CARRIN/lib/services/community_price_service.dart) | Conexão com Supabase REST, sincronização em background, purga de dados legados e cálculo de proximidade Haversine. |
| **AppUpdateService** | [`lib/services/app_update_service.dart`](file:///C:/Dev/CARRIN/lib/services/app_update_service.dart) | Sistema OTA de checagem automática de versão, download com barra de progresso, disparo nativo do instalador do Android via `FileProvider` e painel de publicação para o desenvolvedor. |
| **SyncIndicator** | [`lib/widgets/sync_indicator.dart`](file:///C:/Dev/CARRIN/lib/widgets/sync_indicator.dart) | Indicador visual de sincronização em tempo real (verde sincronizado, laranja pendente) com modal explicativo limpo e sem parênteses. |
| **TermsScreen** | [`lib/screens/terms_screen.dart`](file:///C:/Dev/CARRIN/lib/screens/terms_screen.dart) | Termos de serviço, garantias de privacidade e política de transparência de dados. |

---

## 3. Tecnologias e Dependências Principais

- **Linguagem & Framework:** Dart `3.x` / Flutter SDK `>=3.0.0 <4.0.0`
- **Gerenciamento de Estado:** `provider: ^6.1.1` (arquitetura centralizada com `ItemProvider` e `ThemeProvider`)
- **Banco de Dados Local (Offline-First):** `sqflite: ^2.3.0` + `path: ^1.9.0`
- **Armazenamento de Preferências:** `shared_preferences: ^2.2.2`
- **Nuvem Pessoal:** `googleapis: ^11.4.0` + `google_sign_in: ^6.2.1` (Google Drive & Sheets API v4)
- **Nuvem Comunitária (Preços):** REST API Supabase (Tabela pública `community_prices` com RLS)
- **Rede & APIs Externas:** `http: ^1.6.0` (Consulta à base aberta Open Food Facts Brasil e Supabase REST)
- **Geolocalização & Proximidade:** `geolocator: ^13.0.2` + OpenStreetMap (Nominatim Reverse Geocoding)
- **Mapa Geográfico Interativo:** `flutter_map: ^8.3.2` + `latlong2: ^0.10.1` (OpenStreetMap / CartoDB Dark Matter tiles)
- **Navegação & Rotas Externas:** `url_launcher: ^6.3.3` (Esquemas nativos `geo:` para Google Maps e Waze com fallback web)
- **Gráficos Financeiros:** `fl_chart: ^1.2.0`
- **Animações Fluidas:** `flutter_staggered_animations: ^1.1.1`
- **Relatórios & PDF:** `pdf: ^3.12.0` + `printing: ^5.14.3` + `share_plus: ^10.1.4`
- **Câmera & Scanners:** `mobile_scanner: ^5.1.1` (Leitura de códigos de barras EAN-13, EAN-8 e QR Code NFC-e)
- **Notificações em Tempo Real:** `flutter_local_notifications: ^17.2.2`
- **Internacionalização:** `intl: ^0.20.2` (padrão monetário `R$ 0,00` e datas `pt_BR`)

---

## 4. Arquitetura de Dados e Persistência

### 4.1 Banco de Dados Local SQLite (`DatabaseHelper`)

O banco local `shopping_list.db` conta com 5 tabelas integradas:

```sql
-- 1. Itens de Compra
CREATE TABLE items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit_price REAL NOT NULL,
  is_bought INTEGER NOT NULL,
  category TEXT,
  barcode TEXT,
  month_title TEXT NOT NULL,
  supermarket TEXT,
  is_kg INTEGER DEFAULT 0
);

-- 2. Carrinhos / Meses
CREATE TABLE months (
  title TEXT PRIMARY KEY,
  budget REAL DEFAULT 0,
  is_finalized INTEGER DEFAULT 0,
  supermarket TEXT,
  purpose TEXT,
  created_at TEXT
);

-- 3. Fila de Sincronização Resiliente (Sheets)
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- 4. Supermercados Cadastrados & Geofencing
CREATE TABLE supermarkets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  latitude REAL,
  longitude REAL,
  radius_meters REAL DEFAULT 150.0,
  icon TEXT DEFAULT 'store',
  color_hex TEXT DEFAULT '#1E88E5'
);

-- 5. Cache Local do Radar Comunitário de Preços
CREATE TABLE community_prices_cache (
  id TEXT PRIMARY KEY,
  product_name TEXT NOT NULL,
  category TEXT,
  unit TEXT DEFAULT 'un',
  price REAL NOT NULL,
  supermarket_name TEXT NOT NULL,
  latitude REAL,
  longitude REAL,
  submitted_by TEXT,
  verified_receipt INTEGER DEFAULT 0,
  created_at TEXT NOT NULL
);
```

### 4.2 Catálogo Consolidado de 3.484 Supermercados e Geofencing (`DefaultSupermarketsData`)

O CARRIN conta com um catálogo nativo rigorosamente calibrado de **3.484 supermercados geolocalizados** com endereços físicos completos e coordenadas obtidas via extração direta de alta precisão das bases de dados `.mwm` do Maps.me (Rio de Janeiro, Espírito Santo e São Paulo) e cruzamento cartográfico (OpenStreetMap e Photon):

* **Distribuição Geográfica Regional:**
  - **Niterói & São Gonçalo (120+ lojas):** Supermercados Guanabara (Centro/Fonseca), Mundial (Jardim Icaraí), Pão de Açúcar (Icaraí e Ingá), Prezunic (Fonseca), Supermarket, Grand Marché (Itaipu, Piratininga, Fonseca, Barreto), Real Supermercados (Icaraí, Santa Rosa, São Francisco, Pendotiba, Piratininga, Maravista, Itaipu), Princesa (Icaraí, Fonseca), Super Prix (Icaraí Praia e Otávio Carneiro), Pomar (Icaraí e Santa Rosa), Multi Market (Santa Rosa), Mercado Extra (Centro), Mercado Fruto da Terra, Rede Economia (Ingá, Centro, Tribobó, Rio do Ouro, Trindade, Rocha, Zé Garoto, Porto Novo, Mutondo, Jardim Catarina), Assaí Atacadista (Tribobó - Rodovia RJ-104/RJ-106, Alcântara e Porto Velho), Atacadão (Alcântara), Carrefour, Mercado Varsilva e Super Rede.
  - **Maricá & Região dos Lagos (150+ lojas):** Cobertura total de todos os eixos comerciais de Maricá: Centro (*Supermarket, Princesa, Rede Economia, Super Rede*), Inoã (*Dom Atacadista, Supermarket, Super Lagos, Litoral, Costazul*), Itaipuaçu / Barroco (*Grand Marché Barroco, Grand Marché Recanto, Rio Sul, Rede Economia*), São José do Imbassaí (*Supermarket, Mercado Joana*), Itapeba (*Atacadão Maricá, Assaí Atacadista Maricá*), além de ampla cobertura em Saquarema, Araruama, Cabo Frio, São Pedro da Aldeia e Búzios.
  - **Rio de Janeiro Capital & Baixada Fluminense (1.500+ lojas):** Polos atacadistas e redes de varejo de todas as zonas (Centro, Zona Sul, Zona Norte, Zona Oeste e Baixada: Duque de Caxias, Nova Iguaçu, São João de Meriti, Nilópolis, Belford Roxo).
  - **Espírito Santo & São Paulo (1.600+ lojas):** Cobertura das regiões metropolitanas de Vitória (Vila Velha, Serra, Cariacica) e Grande São Paulo, litoral e interior paulista.

* **Unificação Canônica do Supermercado de Referência:**
  - **Estabelecimento:** `Supermercados Guanabara`
  - **Endereço:** *R. Marechal Deodoro, 360 - Centro, Niterói - RJ, 24030-060*
  - **Coordenadas Oficiais:** Latitude `-22.88975`, Longitude `-43.11515`
  - **Raio de Geofencing:** 250 metros
  - **Desduplicação e Limpeza:** As variantes `'Supermercados Guanabara'` e `'Supermercados Guanabara - Niterói'` foram unificadas sob o mesmo registro canônico. Todas as compras do usuário e o pino estático do catálogo convergem para um único marcador oficial no mapa e no radar.

* **Motor Inteligente de Busca e Resolução (`DefaultSupermarketsData.findMatch`):**
  - Normalização sem diacríticos (remove acentos, cedilhas e pontuações).
  - Correspondência exata de nome ou decomposição em tokens (ex: *"Assaí Tribobó"* coincide com *"Assaí Atacadista - Tribobó"*).
  - Desempate espacial por proximidade euclidiana quando as coordenadas do usuário estão disponíveis.
  - Auto-sincronização no SQLite: `DatabaseHelper.ensureDefaultSupermarkets()` atualiza em tempo de execução as coordenadas de lojas legadas e de itens em cache sem deletar históricos locais.

---

### 4.3 Rede de Preços Comunitária (`CommunityPriceService`)

* **Auto-Sincronização Invisível em Background:** Quando o usuário preenche suas listas ou tranca um carrinho, o app publica em lote os produtos com preço (`publishPricesBatch`) no Supabase, garantindo que a base comunitária esteja sempre atualizada.
* **Purga de Mocks e Resíduos de Teste:** O serviço descarta incondicionalmente registros residuais de testes iniciais, preservando apenas supermercados reais cadastrados no catálogo ou validados via GPS.
* **Comparador de Economia e Filtros da UI:**
  - **Filtro Horizontal por Estabelecimentos:** Chips dinâmicos no topo da aba (`Todos os Mercados`, `Supermercados Guanabara`, etc.).
  - **Agrupamento Único por Supermercado (`_buildGroupedMarketCards`):** Cada estabelecimento aparece exatamente uma vez por produto pesquisado. O card consolidado exibe o menor preço apurado, a data da cotação mais recente, o volume total de compras registradas e a faixa de variação de preço, eliminando duplicidade visual e repetição de datas idênticas.
  - **Seleção sob Demanda (Zero Poluição):** A tela não auto-seleciona arbitrariamente nenhum produto ao ser aberta. Os detalhes comparativos abrem apenas quando o usuário toca ativamente em um item, com opção de fechar a visualização a qualquer momento.
  - **Cálculo de Economia Relativa:** Aponta a porcentagem de economia (`economize até X%`) comparando o menor preço daquele item com o maior preço registrado na comunidade.
  - **Fórmula Haversine:** Filtro dinâmico por raio de alcance geográfico a partir da posição GPS do usuário.

---

### 4.4 Mapa Geográfico dos Mercados & Rotas GPS (`MarketMapScreen`)

* **Seletor de 6 Camadas de Mapa Estilo Google Maps (`MapTileStyle`):**
  Renderização vetorial e rasterizada fluida com `flutter_map: ^8.3.2` e `latlong2: ^0.10.1`, com seletor interativo de estilos e persistência em `SharedPreferences` (`market_map_tile_style`):
  1. **Google Padrão Desenhado (`googleStandard`):** Estilo clássico Google Maps com malha viária, nomes de vias, pontos de interesse e contraste ideal para navegação diurna.
  2. **Google Limpo (`googleClean`):** Visual minimalista e desobstruído com paleta suave, destacando os pinos dos supermercados.
  3. **Google Satélite + Ruas (`googleHybrid`):** Ortofotos de satélite de alta resolução combinadas com sobreposição vetorial de ruas, avenidas e contornos urbanos.
  4. **Google Relevo (`googleTerrain`):** Mapa físico com sombreamento de relevo, topografia e curvas de nível geográficas.
  5. **OpenStreetMap (`osmStandard`):** Cartografia colaborativa mundial livre e ilimitada baseada no OSM Standard.
  6. **Modo Noturno / Dark Matter (`darkNight`):** Cartografia escura de alto contraste da CartoDB, perfeita para uso noturno e economia de bateria em telas OLED.
* **Localização GPS do Usuário & Raio Dinâmico:** Marcador com anel pulsante azul e círculo semitransparente com seletor de raio (5 km, 10 km, 15 km, 25 km, 30 km e 50 km) com botão flutuante de recentralização rápida e alternador para ligar/desligar o círculo visual.
* **Modo Selecionar Ponto no Mapa (`_pickOnMapMode` & Toque / Long-Press):**
  - Permite ao usuário tocar ou manter pressionado qualquer local no mapa para definir um ponto arbitrário sem interferir nos pinos dos mercados.
  - Exibe marcador dinâmico animado e painel inferior (`BottomSheet`) com coordenadas exatas, endereço aproximado e botão *"Ir até aqui"* para iniciar navegação de rota imediata.
* **Barra de Busca com Sugestões Inteligentes em Tempo Real:**
  - Campo de pesquisa superior com overlay de sugestões dinâmicas que filtra estabelecimentos por nome da loja, nome da rede, endereço ou município (com busca insensível a acentos, ex: *"Tribobó"*, *"Inoã"*, *"Guanabara"*).
  - Fechamento automático do teclado virtual ao submeter a busca ou rolar os resultados, com deslocamento suave da câmera do mapa para o local selecionado.
* **Filtro Rápido de Redes Principais (`mainChains`):**
  - Carrossel horizontal de chips com as maiores redes de varejo e atacado (*Guanabara, Supermarket, Rede Economia, Assaí, Mundial, Real, Atacadão, Grand Marché, Prezunic, Princesa, Super Rede, Dom Atacadista, Pão de Açúcar, Zona Sul, etc.*) para filtragem instantânea dos marcadores visíveis.
* **Pinos Inteligentes com Destaque de Economia:**
  - O supermercado com o menor preço médio da região recebe destaque supremo com uma **Coroa de Ouro** (`👑`) e gradiente âmbar (`#FFA000` a `#FF6F00`).
  - Os demais supermercados exibem pinos estilizados com ícone da loja e indicador de preço médio apurado.
  - Alternador rápido para ocultar/exibir todos os pinos de mercados na tela.
* **Carrossel Inferior Sincronizado (`PageView`):** Cards deslizantes translúcidos que exibem o nome do mercado, distância calculada, badge de menor preço e botão para focalizar o pino no mapa com transição suave.
* **Modal Completo de Detalhes do Mercado (`_showMarketBottomSheet`):** Exibe endereço físico completo, preço médio da cesta, contagem de produtos com menor preço, lista das melhores ofertas do mercado, atalho direto para o Comparador de Preços e botão *"Como Chegar"*.
* **Traçado de Rotas Externas (`_openNavigation`):** Acionamento nativo de aplicativos de navegação GPS (Google Maps e Waze) através de esquemas `geo:latitude,longitude?q=...` com fallback automático para rotas web HTTPS via `url_launcher`.

---

### 4.5 Reconhecimento Inteligente de Código de Barras (`BarcodeLookupService`)

O [`BarcodeLookupService`](file:///C:/Dev/CARRIN/lib/services/barcode_lookup_service.dart) implementa uma arquitetura de identificação em camadas para códigos de barras EAN-13 e EAN-8 lidos pela câmera:

1. **Camada 1 — Histórico Local SQLite (Offline-First):**
   - Ao ler o código de barras, o app pesquisa primeiramente no banco local do usuário (`findProductByBarcode`).
   - Se o usuário já comprou o item anteriormente, os dados reais da sua rotina (nome customizado, último preço pago e categoria) são retornados imediatamente em menos de 10ms, sem depender de internet.
2. **Camada 2 — API Open Food Facts Brasil (Base Aberta):**
   - Caso o item seja novo para o usuário, o serviço dispara uma requisição HTTP para a API nacional/global do Open Food Facts (`world.openfoodfacts.org/api/v2/product/{barcode}.json`).
   - Extrai nome oficial em português (`product_name_pt` / `product_name`), marca do fabricante (`brands`), gramatura/volume (`quantity`) e foto do produto (`image_url`).
   - Formatação automática em Title Case e sanitização do nome do produto.
3. **Camada 3 — IA de Categorização Automática:**
   - O método heurístico [`ItemProvider.suggestCategoryForName`](file:///C:/Dev/CARRIN/lib/providers/item_provider.dart) analisa o nome e marca retornados e classifica automaticamente o item na categoria correta da lista (*Mercearia, Bebidas, Limpeza, Higiene, Frios & Laticínios, Hortifruti, etc.*).
4. **Cache em Memória & Timeout Resiliente:**
   - Resultados cacheados em memória para respostas instantâneas caso o código seja lido novamente.
   - Timeout rígido de 4 segundos que evita travamentos em áreas de subsolo sem sinal celular.
5. **Experiência Zero-Fricção (Adição Direta):**
   - Eliminação de caixas de diálogo confirmatórias invasivas (*"Deseja adicionar agora?"*).
   - O escaneamento abre imediatamente o diálogo de item ([`AddItemDialog`](file:///C:/Dev/CARRIN/lib/screens/shopping_list_screen.dart)) com nome, código de barras, categoria sugerida e badge sutil de procedência (`🌐 Base Aberta` ou `🛒 Seu Histórico`).

---

### 4.6 Sincronização Google Sheets Pessoal (`UserSheetsService`)

* **Autenticação Pessoal via OAuth 2.0:** O usuário conecta diretamente sua conta Google via [`GoogleSignIn`](file:///C:/Dev/CARRIN/lib/services/user_sheets_service.dart).
* **Armazenamento Privado no Drive Pessoal:** O aplicativo cria e atualiza a planilha `CARRIN_LISTAS` no Google Drive exclusivo do usuário, garantindo privacidade absoluta sem servidores proprietários.
* **Fila Resiliente de Sincronização (`sync_queue`):** Alterações realizadas sem internet são enfileiradas na tabela local SQLite `sync_queue` e despachadas sequencialmente em background assim que a conectividade for restabelecida.

* **Sincronização Não-Destrutiva e Auto-Recuperação (`recoverAndConsolidateUserData`):** O motor de sincronização mescla listas locais e da nuvem sem jamais apagar listas locais que ainda não subiram para o Google Sheets, filtra abas padrão vazias (`Página1` / `Sheet1`), seleciona automaticamente a planilha mais completa no Google Drive e reconstrói listas/itens a partir de múltiplos bancos locais (`.db`), snapshots (`local_backup_carts_v1`) e histórico de preços (`cache_price_history_v2*`).

---

### 4.7 Leitor e Parser de Cupons Fiscais SEFAZ (`ReceiptScannerScreen`)

* **Leitura de NFC-e via QR Code:** Captura a URL pública emitida pelas Secretarias de Fazenda estaduais (SEFAZ) nos cupons fiscais eletrônicos.
* **Parser Inteligente de Cupons (1 e 2 Linhas):** Algoritmo de extração textual com suporte a cupons fiscais onde a descrição, código e valores estão dispostos em uma única linha ou divididos em duas linhas sucessivas.
* **Importação em Lote:** Itens do cupom fiscal são convertidos automaticamente em instâncias do modelo `Item` e adicionados diretamente ao carrinho ativo com quantidades fracionárias, preços unitários e categorias pré-sugeridas.

---

## 5. Histórico Cronológico de Atualizações e Versões

### v1.3.583 (21 de Outubro de 2026)
- **Localização e Mapa em Tempo Real (`MarketMapScreen` & `PulsingUserLocationMarker`):**
  - **Marcador de GPS Estilo Radar:** Implementação do widget animado `PulsingUserLocationMarker` com onda de expansão azul contínua, anel de precisão e cone direcional de bússola alinhado com o `heading` do GPS em tempo real.
  - **Modo Seguir Usuário (Live Tracking):** Botão flutuante de GPS com alternância dinâmica para modo navegação; a câmera acompanha suavemente a posição do usuário conforme ele se desloca. Ao arrastar o mapa manualmente, o modo seguir pausa automaticamente; tocando no FAB, o mapa re-centraliza e retoma o rastreamento ao vivo.
  - **Recálculo Dinâmico de Distâncias:** Conforme o usuário caminha ou dirige, as distâncias em todos os estabelecimentos carregados, pinos do mapa e cards do carrossel inferior são recalculadas instantaneamente via `LocationService.instance.calculateDistance`.
  - **Círculo de Precisão do GPS:** Exibição sutil do raio de acurácia métrica do sensor do dispositivo (`_userAccuracy`).
- **Instalador Resiliente & Blindagem contra Arquivos Corrompidos (`AppUpdateService`):**
  - **Validação de Integridade ZIP/EOCD (`isApkFileValid`):** O aplicativo inspeciona os bytes finais do arquivo procurando a assinatura End of Central Directory (`0x50, 0x4B, 0x05, 0x06`) e o tamanho real esperado antes de validar o APK baixado, impedindo que downloads parciais sejam renomeados para `.apk`.
  - **Auto-limpeza de Cache em Falhas:** Se qualquer instalação falhar ou um APK inválido for detectado no cache temporário, o arquivo é imediatamente expurgado, eliminando loops de instalação travada e dispensando a limpeza manual de cache no Android.
  - **Permissões Explícitas de URI (`MainActivity.kt`):** Concessão explícita de `FLAG_GRANT_READ_URI_PERMISSION` para todos os pacotes do instalador do sistema e flag `EXTRA_NOT_UNKNOWN_SOURCE`.
- **Validação Automatizada:** 74/74 testes unitários e de integração aprovados (100%), 0 advertências no `dart analyze`.

### v1.3.582 (21 de Outubro de 2026)
- **Consolidação e Simplificação da Aba Comunidade (`CommunityRadarScreen`):**
  - Unificação das abas redundantes de Feed e Comparador em 2 abas limpas e intuitivas: **Ofertas** e **Mercados**.
  - **Busca Inteligente Integrada:** Barra de pesquisa diretamente no topo da aba Ofertas com expansão imediata de cards de comparação de preços do produto buscado, combinada com chips de filtro horizontal por redes de supermercados.
- **Automação do Pipeline de Releases (`scripts/publish_release.ps1`):**
  - Script PowerShell que extrai credenciais de forma segura do Gerenciador de Credenciais do Windows, interage com a API REST do GitHub, cria releases, faz upload binário de APKs e valida o link público final HTTP 200.
- **Validação Automatizada:** 73/73 testes aprovados, 0 avisos no `dart analyze`.

### v1.3.581 (21 de Outubro de 2026)
- **Otimização do Monitor de Atualizações em Segundo Plano (`BackgroundUpdateChecker`):**
  - Ajuste na rotina periódica e anti-spam de notificações automáticas para o canal `app_updates_v1`.
- **Validação Automatizada:** 73/73 testes aprovados, 0 avisos no `dart analyze`.

### v1.3.580 (21 de Outubro de 2026)
- **Notificações Automáticas de Atualização em Segundo Plano (`BackgroundUpdateChecker` & `WorkManager`):**
  - Implementação de verificação periódica nativa em segundo plano utilizando o WorkManager do Android, eliminando a necessidade de abrir o aplicativo para ser notificado sobre novas versões.
  - Intervalo de checagem a cada 6 horas com restrição de rede ativa (`NetworkType.connected`) e preservação de agendamento após reinicialização do dispositivo (`RECEIVE_BOOT_COMPLETED`).
  - Proteção anti-spam via `SharedPreferences`: o usuário só é notificado uma única vez por versão lançada.
- **Notificação de APK Baixado e Pronto para Instalação (`NotificationService.showUpdateReady`):**
  - Ao concluir o download silencioso em segundo plano, o app emite uma notificação de alta prioridade na barra de status do Android informando que o instalador está pronto.
  - Toque interativo na notificação: aciona imediatamente o instalador nativo do Android (`AppUpdateService.instance.installApk`) mesmo que o app esteja minimizado ou fechado.
- **Canal de Notificações Dedicado (`app_updates_v1`):**
  - Criação de canal nativo específico para atualizações com prioridade alta, som e vibração habilitados, separado do monitor de compras e de alertas de orçamento.
- **Preservação de Avisos de Atualização ao Fechar o App (`NotificationDismissService`):**
  - Ajuste no serviço nativo para limpar exclusivamente a barra de progresso de compras (`cancel(0)`) e alertas de orçamento (`cancel(1)`), mantendo os avisos de atualização intactos na gaveta de notificações do Android.
- **Validação Automatizada:** 100% de aprovação nos testes unitários e de integração, 0 advertências no `dart analyze`.

### v1.3.579 (21 de Outubro de 2026)
- **Preservação de Recursos Nativos Android contra Shrinking/R8 (`android/app/src/main/res/raw/keep.xml`):**
  - Criação do arquivo de regras de retenção de recursos nativos (`tools:keep="@drawable/*,@mipmap/*"`). Previne que o otimizador R8 / Android Gradle Plugin descarte os drawables nativos das notificações (`ic_notification_cart`, `ic_carrin_logo`) durante o build de release com `isShrinkResources = true` e `isMinifyEnabled = true`.
  - Resolução definitiva de exceções silenciosas de ícone ausente (`invalid_icon` / `invalid_large_icon`), restaurando 100% da visibilidade e estabilidade do monitor de compras na barra de status e tela de bloqueio.
- **Fallback Seguro e Persistência do Monitor de Compras (`NotificationService` & `main.dart`):**
  - Adição de fallback defensivo para `@mipmap/launcher_icon` caso os recursos específicos sofram qualquer problema no dispositivo.
  - Ajuste de `autoCancel: false` no monitor contínuo: o toque na notificação para retornar ao aplicativo não encerra mais prematuramente o monitoramento, mantendo `ongoing: false` para que o usuário ainda possa dispensar com swipe se desejar.
  - Reativação imediata do monitoramento em `didChangeAppLifecycleState(AppLifecycleState.resumed)` e após concessão explícita de permissões.
- **Correção Abrangente do Modo Daltônico com Paleta Semântica Acessível:**
  - Vinculação de todas as cores de status (itens riscados, alertas de orçamento, balanço financeiro, medidores de saúde financeira e chips de preço) ao `Theme.of(context).colorScheme.primary` e `Theme.of(context).colorScheme.error` em vez de constantes fixas (`Colors.green`, `Colors.redAccent`).
  - Paletas científicas calibradas para legibilidade absoluta:
    - **Deuteranopia & Protanopia:** Azul Royal (`#0072B2`) e Vermillion/Laranja Queimado (`#D55E00`).
    - **Tritanopia:** Verde Azulado (`#009E73`) e Rosa Avermelhado (`#CC79A7`).
    - **Alto Contraste:** Verde Neon (`#00E676`) e Vermelho Intenso (`#FF1744`).
- **Reatividade Instantânea no Root (`main.dart`):**
  - Adição de `key: ValueKey(themeProvider.colorBlindMode)` no `ColorFiltered` global, forçando reconstrução limpa e imediata de toda a árvore de widgets ao alternar o modo nas configurações.
- **Validação Automatizada:** 70/70 testes aprovados (100% de sucesso), 0 advertências no `dart analyze`.

### v1.3.578 (21 de Outubro de 2026)
- **Idempotência a Nível de Evento no Radar de Preços Comunitário (`CommunityPriceService`):**
  - Envio de identificador estável `event_id` estruturado (`<deviceId>_<itemId>`) em conjunto com as diretivas HTTP `on_conflict=event_id` e `resolution=ignore-duplicates` no Supabase REST API (individual e batch).
  - Previne duplicações de compras na nuvem em casos de retentativas automáticas causadas por oscilações ou timeouts de conexão.
- **Identificador de Dispositivo Anônimo e Persistente:**
  - Geração de UUID v4 anônimo local salvo em `SharedPreferences` para garantir unicidade global sem coletar dados pessoais do usuário.
- **Exposição da Chave Primária SQLite (`DatabaseHelper.getAllUserPurchasedProducts`):**
  - Inclusão da coluna `id` na consulta de produtos comprados para suportar o rastreamento preciso de eventos e confirmações de sincronização.
- **Preservação Integral de Egress e Políticas de Segurança:**
  - Manutenção de seleção explícita de colunas na API do Supabase, índices GIN de busca por trigramas (`pg_trgm`) e restrições `CHECK (price > 0)`.
- **Validação Automatizada:** 68/68 testes aprovados, 0 advertências no `dart analyze`.

### v1.3.568 (18 de Outubro de 2026)
- **Bloqueio de Orientação em Modo Retrato Vertical (`AndroidManifest.xml` & `main.dart`):**
  - **Prevenção de Quebra de Telas em Modo Paisagem:** Configurado `android:screenOrientation="portrait"` na atividade principal do Android (`MainActivity`) e `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])` no `main()`.
  - Impede que o aplicativo gire horizontalmente ao inclinar o celular no supermercado, mantendo a ergonomia de uso vertical de todas as janelas, calculadoras, rodapés curvos, scanners e modais sem cortes ou quebras de layout.
- **Sanitização de Segurança para Repositório Público (`android_release_info.md`):**
  - Remoção de anotações de senhas em texto puro do guia interno de publicação. As credenciais privadas locais da keystore permanecem 100% protegidas no arquivo `key.properties` e no arquivo binário `.jks`, ambos blindados no `.gitignore`.
- **Validação Automatizada:** 61/61 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.567 (18 de Outubro de 2026)
- **Persistência Garantida da Escala de Fontes (`ThemeProvider` & `SettingsScreen`):**
  - **Identificação da Causa Raiz:** O ajuste de tamanho de texto (85% e outros) voltava para 100% ao fechar o app porque a inicialização no `main.dart` agrupava múltiplos serviços em um único bloco `try/catch`. Caso a inicialização de notificações encontrasse qualquer advertência ou se o SharedPreferences deserializasse o número como tipo `int`, o carregamento do `_fontScale` era abortado e o valor padrão de 1.0 era assumido.
  - **Leitura Resiliente Numérica:** O `ThemeProvider.init()` agora realiza leitura polimórfica (`prefs.get('fontScale') as num?`) convertendo com segurança tanto inteiros quanto decimais sem gerar `TypeError`.
  - **Gravação Segura e Arredondamento:** O método `setFontScale` arredonda o valor para 2 casas decimais (`(scale * 100).round() / 100.0`) e executa `prefs.remove('fontScale')` antes de `setDouble` para evitar conflito de tipagem nativa no XML de preferências do Android.
  - **Isolamento de Serviços no Boot (`main.dart`):** Cada subsistema (`initializeDateFormatting`, `NotificationService().init()`, `themeProvider.init()`, `AuthService().init()`) agora possui seu próprio bloco de proteção isolado, garantindo que o tema e escala de fonte sempre carreguem mesmo se outros serviços falharem.
  - **Correção da Prévia em Tempo Real:** Ajustada a caixa de visualização do diálogo para utilizar `TextScaler.linear(scale)` direto via `MediaQuery`, eliminando multiplicação duplicada de escala.
- **Correção do Identificador do Ícone de Notificações (`NotificationService`):**
  - O `AndroidInitializationSettings` foi corrigido para utilizar o nome de recurso nativo `'ic_notification_cart'` (sem o prefixo de caminho `'@drawable/'`), assegurando resolução imediata pelo Android OS sem exceções de inicialização.
- **Diagnóstico Inteligente para Atualizações OTA (`AppUpdateService` & `SettingsScreen`):**
  - Adicionado rastreamento de falhas na checagem de atualizações (`lastFetchError`). Quando a URL do `version.json` retorna erro 404 (típico de repositórios mantidos como **Privados** no GitHub), o app agora informa explicitamente ao usuário através de um aviso explicativo na tela em vez de indicar falsamente que ele já está na versão mais recente.
- **Validação Automatizada:** 61/61 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.566 (18 de Outubro de 2026)
- **Correção da Sobreposição da Barra de Navegação do Android (Botões Voltar, Home e Janelas):**
  - **Margem Segura Dinâmica (`SafeArea` & `padding.bottom`):** Solucionado o problema em celulares com a barra de navegação de 3 botões físicos/virtuais no rodapé (Back, Home, Recents/Janelas). O app anteriormente transpassava e desenhava elementos por baixo dos botões do sistema.
  - **Menu Inferior Principal (`MainScreen`):** O `BottomNavigationBar` agora é encapsulado em `SafeArea(top: false, bottom: true)` e `AnnotatedRegion<SystemUiOverlayStyle>`, garantindo que as 5 abas (*Início*, *Carrinhos*, *Análises*, *Comunidade*, *Ajustes*) fiquem elevadas com conforto acima da barra do sistema, enquanto a cor de fundo (`cardColor`) preenche o rodapé do Android de forma limpa e nativa.
  - **Rodapé Curvo e Botão de Escanear (`ShoppingListScreen`):** Altura do footer recalculada dinamicamente (`100.0 + bottomPadding`). A onda personalizada (`_WavyFooterPainter`) estende sua pintura até a base da tela, os botões *"Novo Item"* e *"Filtros"* apoiam-se acima da barra, e o botão flutuante de escaneamento de código de barras (`FloatingActionButton`) repousa em `bottom: 12 + bottomPadding`, exatamente encaixado na cavidade da onda e livre de qualquer sobreposição com o botão Home do Android.
  - **Barra de Ações em Lote (`_isSelectionMode`):** A barra de seleção múltipla de itens agora conta com `SafeArea(top: false)` para não colidir com os botões de navegação.
  - **Carrossel e Botões Flutuantes do Mapa (`MarketMapScreen`):** Os botões de camadas/GPS e o carrossel de supermercados foram elevados por `bottomPadding`, impedindo toques acidentais nos botões do sistema operacional.
  - **Modais e Telas Auxiliares (`ReceiptScannerScreen` & `ShoppingFilterBottomSheet`):** Ajustados para respeitar `MediaQuery.of(context).padding.bottom`.
- **Validação Automatizada:** 60/60 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.565 (18 de Outubro de 2026)
- **Ícone Nativo de Carrinho para Notificações Android (`ic_notification_cart`):**
  - Implementação de ícone de carrinho no padrão oficial do Android (silhueta branca com canal alfa/fundo transparente), disponível em vetor XML (`ic_notification_cart.xml` e `ic_stat_cart.xml`) e em todas as densidades de tela (`drawable-mdpi`, `drawable-hdpi`, `drawable-xhdpi`, `drawable-xxhdpi`, `drawable-xxxhdpi`).
  - Destaque em tom esmeralda oficial (`#10B981`) no cabeçalho e inclusão de `largeIcon` com o emblema colorido do aplicativo na área expandida.
- **Eliminação da Persistência Travada e Notificações Deslizáveis (`NotificationService`):**
  - Ajustado `ongoing: false` e `autoCancel: true`: a notificação de progresso das compras não fica mais travada na barra de status; o usuário pode agora deslizá-la lateralmente para dispensá-la quando desejar, e ao tocar nela o app se abre e a notificação é limpa.
- **Cancelamento Automático Confiável ao Fechar o App:**
  - **Serviço Nativo `NotificationDismissService`:** Escuta o ciclo `onTaskRemoved` do Android (quando o app é deslizado/encerrado da tela de multitarefas/Recent Apps), cancelando imediatamente todas as notificações do sistema operacional.
  - **Hook Nativo `MainActivity.onDestroy()`:** Garante o expurgo síncrono das notificações quando a atividade principal for destruída.
  - **Ciclo Flutter (`MyApp.dispose` & `detached`):** Cancelamento de segurança adicional via Dart.
  - **Finalização de Carrinho (`finalizeMonth`):** O fechamento do carrinho ativo remove automaticamente a barra de progresso do painel de notificações.
- **Sistema de Atualizações Sem Play Store (OTA / In-App Updater):**
  - **Identificação Automática e Instalação em 1 Toque:** Ao abrir o app, uma checagem assíncrona identifica se há novas versões lançadas. Se houver, um modal amigável com a lista de novidades é exibido; ao tocar em *"Instalar Atualização"*, o APK é baixado com barra de progresso em tempo real e o instalador nativo do Android é acionado via `FileProvider` mantendo todos os dados, listas e configurações intactos.
  - **Botão do Usuário em Configurações (`_handleCheckUpdate`):** Opção *"Verificar Atualizações"* com status da versão instalada e feedback visual em tempo real.
  - **Painel de Lançamento do Desenvolvedor (`AppUpdatePublisherDialog`):** Opção *"Lançar Atualização"* no painel de Ajustes que permite ao criador definir nova versão, número de build, URL do APK, notas de lançamento (changelog), gerar o `version.json` e testar a instalação no próprio dispositivo.
  - **Integração Nativa Android:** Permissão `REQUEST_INSTALL_PACKAGES`, `FileProvider` seguro (`file_paths.xml`) e `MethodChannel` (`com.wmartins.carrin/installer`) para checagem e disparo do instalador sem dependências pesadas externas.
- **Validação Automatizada:** 60/60 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.564 (18 de Outubro de 2026)
- **Remoção de Parênteses no Diálogo de Sincronização (`SyncIndicator`):**
  - O texto de sucesso no popup de sincronização foi simplificado de *"Todos os dados estão devidamente sincronizados e salvos na nuvem (Google Sheets)."* para *"Todos os dados estão devidamente sincronizados e salvos na nuvem."*, removendo os parênteses e mantendo a mensagem mais limpa e direta.
- **Validação Automatizada:** 60/60 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.563 (18 de Outubro de 2026)
- **Inversão e Ordenação Inteligente de Carrinhos / Listas de Compras (`MonthSelectionScreen` & `ItemProvider`):**
  - **Mais Recentes no Topo por Padrão:** As listas de carrinhos agora são exibidas com os meses/carrinhos mais recentes no topo e os mais antigos embaixo ("colocar as mais antigas para baixo"), garantindo acesso imediato ao carrinho ativo sem necessidade de rolar até o final da tela.
  - **Botão de Inversão de Ordem no Topo:** Adicionado botão alternador no `AppBar` de *Meus Carrinhos* (`Icons.arrow_downward_rounded` / `Icons.arrow_upward_rounded`) permitindo ao usuário inverter a visualização entre mais recentes no topo ou mais antigas no topo a qualquer momento com tooltip informativo e persistência automática em `SharedPreferences` (`month_sort_descending`).
  - **Ordenação Cronológica e por Criação:** O algoritmo de ordenação analisa meses e anos (`year * 100 + month`) para ordenar cronologicamente listas com nomes de meses e infere o ano corrente quando omitido, e utiliza a ordem de criação invertida para listas personalizadas ("Rancho", "Churrasco", etc.).
  - **Histórico no Dashboard e Estatísticas Atualizados:** Os diálogos de *Economia Mensal* e *Histórico de Orçamentos* na Home e o diálogo de *Resumo Geral* na aba de Estatísticas agora também exibem os carrinhos mais recentes no topo.
- **Validação Automatizada:** 60/60 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.562 (18 de Outubro de 2026)
- **Remoção da Interrogação da Tela Inicial (`DashboardScreen`):**
  - O botão de interrogação `?` foi totalmente retirado da AppBar da Home, mantendo a tela inicial limpa e focada exclusivamente no status de sincronização, alternador de tema e perfil. O suporte e reset de tutoriais permanecem organizados na aba de *Ajustes*.
- **Correção da Cor do Botão "Colaborar Preço" e FABs (`AppThemes` & `CommunityRadarScreen`):**
  - Ajustado o `floatingActionButtonTheme` no `_buildLightTheme` e `_buildDarkTheme` para utilizar a cor primária ativa (`seedColor` / `primaryColor`) com contraste dinâmico de texto/ícone, em vez de forçar a cor secundária azul quando o usuário seleciona temas verdes (`iconGreen` / `emerald`).
  - O botão *"Colaborar Preço"* em `CommunityRadarScreen` agora herda e exibe com fidelidade a cor verde do tema.
- **Fidelidade de Tema nos Botões da Home no Modo Escuro (`DashboardScreen`):**
  - Os botões seletores de workspace (*"Meu Carrinho"* e *"Família"*) foram refatorados para utilizar a cor primária (`primaryColor`) e cor de contraste (`onPrimary`) do tema ativo tanto no modo claro quanto no modo noturno, eliminando as cores fixas legadas (roxo pastel `#AEB2FF` e `Colors.deepOrange`).
- **Validação Automatizada:** 58/58 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.561 (18 de Outubro de 2026)
- **Consolidação e Limpeza de Tutoriais (Exclusivos para Início e Configurações):**
  - **Eliminação de Poluição Visual nas Telas Internas:** Removidos todos os botões de interrogação `?` e cards de demonstração interativa de todas as telas secundárias do aplicativo (*Meus Carrinhos*, *Lista de Compras*, *Estatísticas*, *Perfil de Comprador*, *Radar da Comunidade* e *Mapa de Mercados*).
  - **Limpeza do Card de Demo na Tela Inicial:** Remoção do card azul de demo interativa que continuava sendo exibido na Home após o usuário passar pelo tutorial caso a lista de carrinhos estivesse vazia.
  - **Centralização dos Tutoriais:** O tutorial foi preservado exclusivamente onde realmente agrega valor:
    - **Início (`DashboardScreen`):** Acessível de forma limpa pelo botão de ajuda no topo e na primeira abertura do app.
    - **Configurações (`SettingsScreen`):** Acessível sob demanda no topo e pela opção *"Resetar Tutoriais das Abas"*.
  - **Otimização do Agendador no `MainScreen`:** O `_scheduleTabTutorial` agora atua estritamente nas abas 0 (Início) e 4 (Configurações), eliminando qualquer pop-up indesejado nas abas intermediárias.
- **Validação Automatizada:** 58/58 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.560 (18 de Outubro de 2026)
- **Navegação Horizontal Livre e Suave Para Fora da Aba Comunidade (`CommunityRadarScreen` & `MainScreen`):**
  - **Desbloqueio de Gestos e Remoção de Captura Conflitante:** O `TabBarView` interno das 3 sub-abas da Comunidade (*Lista*, *Comparador*, *Mercados*) foi configurado com `physics: const NeverScrollableScrollPhysics()`, impedindo que os gestos horizontais fiquem aprisionados no carrossel de abas filhas e liberando o arraste horizontal 100% direto e contínuo para o `PageView` do `MainScreen`.
  - **Transição Fluida a 120 FPS Entre Telas:** O usuário pode agora deslizar para a esquerda ou direita em qualquer área da aba Comunidade para navegar diretamente entre *Início*, *Carrinhos*, *Análises*, *Comunidade* e *Ajustes*, com animação de página nativa, sem atritos, travamentos ou necessidade de puxar a borda com força excessiva.
  - **Preservação Total da Navegação Interna por Toques:** As sub-abas internas da Comunidade (*Lista*, *Comparador*, *Mercados*) continuam disponíveis e alternam instantaneamente através de toques na barra superior `TabBar`.
  - **Resiliência e Proteção Assíncrona no Cache Local:** Tratamento de exceção em `_loadLocationAndData` e `_fetchDataFromCache` garantindo que o ciclo de vida dos indicadores de carregamento seja liberado com segurança sem travar o loop de renderização do Flutter em ambientes de teste ou sem banco inicializado.
- **Validação Automatizada:** 58/58 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.559 (18 de Outubro de 2026)
- **Fechamento Automático do Teclado Após Pesquisa (`ItemSearchDelegate`, `CommunityRadarScreen`, `MarketMapScreen`):**
  - **Ação Concluída no Teclado (`textInputAction: TextInputAction.search` & `onSubmitted`):** Pressionar o botão de pesquisa/Enter no teclado virtual agora remove o foco (`FocusScope.of(context).unfocus()`) e fecha o teclado instantaneamente em todas as telas de busca.
  - **Ocultação ao Rolar (`keyboardDismissBehavior: onDrag`):** Ao arrastar ou rolar a lista de resultados em `ItemSearchDelegate`, na aba Comunidade/Radar (Tabs 0, 1 e 2) e no modal de mercados do mapa, o teclado se recolhe suavemente.
  - **Toque Fora e Interação:** Tocar em qualquer área vazia, card de produto, supermercado, checkbox ou botão limpar agora retira o foco do teclado de forma imediata.
- **Redesign Compacto e Agrupamento Ergonômico de Temas (`ThemeColorPickerSheet`):**
  - **Redução de Mais de 50% de Espaço Vertical:** Eliminação do card de prévia redundante de 180px e do banner duplicado de 110px, substituídos por uma faixa ultra-compacta de 48px com indicador da cor ativa, nome, código HEX e atalho para edição.
  - **Alternador Claro/Escuro Integrado:** O controle de Modo Claro / Modo Escuro foi incorporado diretamente ao cabeçalho em formato de pílula compacta ao lado do botão de restauração das cores do ícone.
  - **Agrupamento Inteligente por Coleções:** As 36 opções de temas agora são organizadas por abas de categorias com ícones visuais (`🌟 Ícone`, `🌿 Natureza`, `💼 Clássicas`, `☀️ Quentes`, `💎 Elegantes`, `🔮 Criativas`, `🌈 Livre` e `🎨 Todas`):
    - *Ícone CARRIN:* Exibe os cartões destacados de **Verde do Ícone** e **Azul do Ícone** com selo oficial de fábrica.
    - *Coleções Específicas:* Paletas exibidas em grades compactas de amostras circulares com checkmark, cabendo inteiramente em 1 a 2 linhas sem rolagem desnecessária.
    - *Espectro Livre:* Slider arco-íris contínuo HSL e modal para digitação de HEX personalizados.
- **Validação Automatizada:** 57/57 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.558 (18 de Outubro de 2026)
- **Animação da Logo 100% Autônoma e Abertura Rápida na Splash Screen (`InteractiveAnimatedLogo` & `SplashScreen`):**
  - **Execução Autônoma Sem Toques:** O gatilho de animação cinematográfica agora dispara automaticamente (`autoPlayIntro: true`) aos 280ms após a montagem do widget com vibração háptica suave, compressão elástica com salto (*squash & stretch*) e explosão radial de 18 partículas físicas e moedas douradas (`🪙`, `✨`, `⚡`), dispensando a necessidade de qualquer toque do usuário.
  - **Sincronia e Abertura Acelerada:** Duração total da Splash Screen reduzida de 2.600ms para 1.600ms, controlador de escala ajustado para 700ms com curva `easeOutBack`, e ciclo do feixe de brilho (*glossy light sweep*) reduzido para 2.200ms para passar com destaque durante a inicialização rápida do aplicativo.
  - **Transição Rápida e Suave:** Transição de tela `PageRouteBuilder` ajustada para 400ms via `FadeTransition`, garantindo abertura fluida e imediata para a tela principal ou login.
- **Validação Automatizada:** 56/56 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.557 (18 de Outubro de 2026)
- **Logo Animada, Cinematográfica e Interativa na Abertura (`InteractiveAnimatedLogo`):**
  - Substituição da imagem estática da splash screen por um componente de animação vetorial com física de fluidos e motion design profissional:
    - **Aura de Neon e Anéis de Energia:** Gradiente radial pulsante nas cores oficiais (`#10B981` Verde Esmeralda e `#0179F3` Azul Royal) com anéis concêntricos que expandem como ondas de radar no fundo.
    - **Flutuação Contínua (Levitação Senoidal):** Movimento suave de elevação vertical tipo onda senoidal e pulso de respiração contínuo.
    - **Varredura Especular de Alto Brilho (Shimmer / Glossy Sweep):** Feixe diagonal de luz que varre a logo ciclicamente via `ShaderMask` e `LinearGradient`, transmitindo sensação de vinheta de estúdio cinematográfico em 60/120 FPS sem peso extra de vídeo.
    - **Interatividade por Toque (Física de Impacto):** Reação instantânea a toques com efeito elástico de compressão e extensão (*squash & stretch*), salto para o alto e explosão de partículas físicas (moedas douradas `🪙`, estrelas esmeralda `✨`, raios `⚡` e orbes de luz).
    - **Inclinação 3D Parallax ao Arrastar:** Ao deslizar o dedo sobre a logo, ela se inclina tridimensionalmente no espaço via `Matrix4` em perspectiva e retorna com amortecimento elástico ao soltar.
    - **Modo Turbo (Toque Duplo ou Múltiplos Toques Rápidos):** Dispara um giro 360° com feedback tátil pesado (`HapticFeedback.heavyImpact()`) e tempestade de confetes e moedas.
- **Validação Automatizada:** 55/55 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.556 (18 de Outubro de 2026)
- **Correção Geral dos Resumos e Valores das Planilhas ("Meus Carrinhos" & Google Sheets):**
  - **Identificação da Causa Raiz:** Carrinhos anteriores exibiam R$ 0,00 ou erros de cálculo porque o template gravava fórmulas em inglês com ponto e vírgula `;` (que gerava `#ERROR!` na API do Google Sheets), comparava strings com booleano (`"true"` vs `TRUE`) e a sincronização de itens (`overwriteAllItems`) não atualizava o cabeçalho de resumo na linha 2.
  - **Fórmulas Resilientes e Padronizadas no Google Sheets:** Fórmulas corrigidas para sintaxe padrão da API com vírgula e tratamento de erro:
    - *Total Gasto (C2):* `=IFERROR(SUMIF(G7:G, TRUE, E7:E), 0)`
    - *Qtd Itens (E2):* `=IFERROR(COUNTA(C7:C), 0)`
    - *Comprados (F2):* `=IFERROR(COUNTIF(G7:G, TRUE), 0)`
    - *Saldo (G2):* `=IFERROR(H2-C2, 0)`
    - Cabeçalho da coluna G atualizado para `'Saldo'`.
  - **Cálculo Dinâmico a partir dos Itens em Lote (`UserSheetsService.getBatchSummaries`):** O `getBatchSummaries` agora consulta simultaneamente o resumo (`A2:I2`) e todos os itens (`B7:I`) de cada mês em uma única requisição HTTP. Caso a linha 2 contenha erros de fórmula ou valores zerados, o serviço calcula automaticamente os valores reais com base nos itens cadastrados (somando apenas os itens marcados como comprados, `isBought == true`) e regenera em background as fórmulas corretas na planilha do usuário (`_healSummaryRow`).
  - **Auto-Recuperação no SQLite Local (`DatabaseHelper.recalculateAllMonthSummaries`):** Na inicialização e no carregamento dos meses, o SQLite recalcula o resumo de todos os carrinhos locais diretamente a partir dos itens salvos, garantindo exibição instantânea dos valores corretos em *"Meus Carrinhos"*.
  - **Suporte Robusto a Pontos de Milhar em Valores Numéricos (`Utils.parseCurrency` & `Item._parseNum`):** Tratamento universal de números brasileiros com separador de milhar (ex: `1.250,50` $\rightarrow$ `1250.50`), decimais com vírgula ou ponto, valores entre parênteses para negativos e símbolos monetários.
  - **Preservação Integral da Coluna de Supermercado (Coluna I):** Intervalos do Google Sheets expandidos de `B:H` para `B:I` em `getItems`, `updateItem`, `overwriteAllItems` e `getFullPriceHistory`, impedindo a perda do estabelecimento associado a cada produto.
- **Validação Automatizada:** 54/54 testes unitários e de widgets aprovados (100% de sucesso), 0 erros no `flutter analyze`.

### v1.3.555 (17 de Outubro de 2026)
- **Vírgula Automática em Tempo Real nos Diálogos e Caixas de Entrada (`CurrencyInputFormatter`):**
  - Implementação do formatador monetário nativo em tempo real (`CurrencyInputFormatter`) em `lib/services/utils.dart`, permitindo que os centavos e a vírgula "andem sozinhos" da direita para a esquerda conforme o usuário digita no teclado numérico:
    - Digita `1` $\rightarrow$ `0,01`
    - Digita `2` $\rightarrow$ `0,12`
    - Digita `9` $\rightarrow$ `1,29`
    - Digita `9` $\rightarrow$ `12,99`
    - Digita `5` $\rightarrow$ `129,95`
    - Digita `0` $\rightarrow$ `1.299,50` (com ponto de milhar automático)
    - Backspace $\rightarrow$ retrocede os dígitos de forma limpa até limpar a caixa (`""`), exibindo o placeholder `0,00` sem travar o cursor.
  - O usuário não precisa mais alternar teclado para achar a tecla de vírgula ou ponto: o teclado abre em modo exclusivamente numérico (`TextInputType.number`).
- **Padronização Universal de Entradas Monetárias em Todas as Telas e Modais:**
  - **Preço Unitário na Adição e Edição de Item (`ShoppingListScreen._showItemDialog`):** Campo com `CurrencyInputFormatter`, chips de histórico de preços, sugestão de código de barras e retorno da calculadora flutuante formatados via `Utils.formatCurrencyInput`.
  - **Edição Rápida de Preço Direto na Lista (`ShoppingListScreen._inlinePriceController`):** Edição rápida inline com máscara automática em tempo real e leitura segura com `Utils.parseCurrency`.
  - **Orçamento Disponível do Mês (`ShoppingListScreen._showEditBudgetDialog`):** Diálogo de meta mensal com máscara de vírgula automática.
  - **Orçamento Inicial ao Criar Carrinho (`MonthSelectionScreen._showCreateMonthDialog`):** Máscara automática no modal de novo mês/carrinho.
  - **Calculadora de Peso por Preço Total (`WeightCalculatorDialog`):** Ambos os campos (*Preço por Kg* e *Total Pago*) equipados com `CurrencyInputFormatter`.
  - **Travas e Metas por Categoria (`PurposeAndCapsDialog`):** Definição de teto máximo em R$ por categoria com máscara dinâmica.
  - **Preço Comunitário do Radar (`CommunityRadarScreen._showPublishDialog`):** Diálogo de contribuição de preço para a comunidade com máscara monetária.
  - **Edição de Preço no Scanner de Cupom Fiscal (`ReceiptScannerScreen._editItemDialog`):** Ajuste de itens extraídos de NFC-e com máscara automática.
  - **Orçamento Padrão das Configurações (`SettingsScreen._showDefaultBudgetDialog`):** Configuração do orçamento padrão com vírgula dinâmica.
- **Validação Automatizada:** 50/50 testes aprovados, incluindo bateria dedicada para deslocamento de centavos, backspace e parsing de valores.

### v1.3.554 (17 de Outubro de 2026)
- **Correção da Contagem de Itens Não Checados no Preço Final / Total:**
  - Identificada e eliminada a causa raiz pela qual itens não checados (`isBought == false`), como "jogo de taças", tinham seu valor somado indevidamente no total do mês e nos cards financeiros.
  - No `DatabaseHelper` (`saveItems` e `recoverAndConsolidateUserData`), remoção da condição espúria `else if (it.unitPrice > 0 && it.quantity > 0) calcTotal += it.totalPrice;`, garantindo que apenas itens marcados no carrinho (`it.isBought == true`) componham o `total` e abatam o `balance`.
  - Reconstrução e consolidação automática na inicialização: o app recalcula imediatamente o resumo de todos os meses locais, expurgando valores indevidos de itens não checados e corrigindo a lista de Outubro.
  - Cabeçalho dinâmico (`_StickyHealthHeaderDelegate`): o valor principal exibe estritamente `provider.totalCost` sempre que a lista contiver itens, mantendo itens não checados apenas no campo de estimativa *"Previsão"*.
  - Diálogo de *Finalizar Compra* e calculadora de *Rateio* padronizados para utilizar `provider.totalCost`.
  - Exportação em PDF (`PdfExportService`): cálculo de *Gasto Atual* restrito a itens comprados (`it.isBought`).
  - Sincronização de compras finalizadas (`syncMonthPurchases`): proteção contra publicação de itens pendentes no feed comunitário.
  - Testes unitários dedicados adicionados validando a exclusão de itens não checados do total.

### v1.3.553 (17 de Outubro de 2026)
- **Tema Padrão Oficial & Restauração com Cores do Ícone:**
  - Correção da ação "Restaurar" (`_restoreDefault`) no seletor de temas: retorna fielmente às cores oficiais do ícone principal do CARRIN (`#10B981` Verde Esmeralda e `#0179F3` Azul Royal) em vez do tom navy/preto escuro legado (`#1A1C2C`).
  - O tema padrão inicial (`ThemeProvider._seedColor`) agora é oficialmente `AppColors.iconGreen` (`#10B981`) com `colorScheme.secondary` configurado automaticamente para `AppColors.iconBlue` (`#0179F3`).
- **Migração Automática do Legado (`ThemeProvider.init`):**
  - Checagem automática no carregamento das preferências: se o usuário possuir o valor legado `#1A1C2C` gravado em `SharedPreferences`, o app migra automaticamente para `AppColors.iconGreen`, garantindo que os usuários não permaneçam na cor escura por herança de dados antigos.
- **Seletor de Cores com Banner das Cores Oficiais do Ícone (`ThemeColorPickerSheet`):**
  - Adicionado banner interativo no seletor de temas com atalho em 1 toque para alternar entre as cores oficiais do ícone: *Verde Ícone* (`#10B981`) e *Azul Ícone* (`#0179F3`).
  - Nova categoria "Ícone" nas cores com curadoria rápida.
- **Harmonização do Tutorial Interativo (`InteractiveTabTutorial`):**
  - O distintivo "TUTORIAL INTERATIVO" agora utiliza um gradiente vivo combinando o verde esmeralda e o azul royal do ícone principal (`colors: [accent, secondary]`).
  - `accentColor` atualizado para `AppColors.iconGreen`.
- **Eliminação Sistemática de Cores Navy Fixas em Telas e Modais:**
  - Substituição de referências fixas a `AppThemes.primaryNavy` por `Theme.of(context).colorScheme.primary` em todas as telas: `BuyerProfileScreen`, `MonthSelectionScreen`, `SettingsScreen`, `ShoppingListScreen`, `FloatingCalculatorPopup` e `ShoppingFilterBottomSheet`.
- **Auditoria de Qualidade:** 0 erros no `flutter analyze`, 44/44 testes aprovados.

### v1.3.552 (17 de Outubro de 2026)
- **Ancoragem Geométrica Estável dos Pinos no Mapa (`MarketMapScreen`):**
  - Correção definitiva do salto de coordenadas XY que ocorria ao tocar em qualquer marcador de supermercado: tanto o estado não-selecionado quanto o estado selecionado agora compartilham rigorosamente as dimensões `width: 38, height: 38` e o ponto âncora `Alignment.center`.
  - O balão informativo do mercado selecionado foi reposicionado verticalmente via `Stack(clipBehavior: Clip.none)` flutuando sobre o pino sem deslocar o centro geográfico do pino em nem sequer 0.1 pixel.
- **GPS de Alta Precisão & Monitoramento Contínuo em Tempo Real (`LocationService` & `MarketMapScreen`):**
  - Fim da reutilização de posições antigas de até 10 minutos: `getCurrentPosition` agora invalida posições com mais de 15 segundos de idade e exige `LocationAccuracy.high` direto via satélite/hardware.
  - Implementação de `getPositionStream(distanceFilter: 2)` e conexão direta com o `MarketMapScreen`, atualizando a posição do usuário em tempo real à medida que ele se move pelo mapa.
- **Desobstrução e Limpeza da Interface na Comunidade e Radar (`CommunityRadarScreen`):**
  - Remoção do banner redundante de abertura do mapa na aba *Mercados* (o mapa já possui acesso direto e permanente no ícone da AppBar).
  - Remoção do card estático de loja ("Supermercados Guanabara Niterói • Ao Vivo") que ocupava o topo da aba *Lista*.
  - Remoção dos cards instrutivos com explicações óbvias ("Compare os Preços dos Mercados • Toque em qualquer produto...") na aba *Comparador*.
- **Navegação Fluida por Deslize Lateral (Resolução do Swipe Trapping):**
  - `TabBarView` da tela de comunidade atualizado para `BouncingScrollPhysics()` e integrado com `NotificationListener<ScrollNotification>`. Ao atingir as bordas externas (deslizar para a direita na primeira aba ou para a esquerda na última aba), o gesto transita suavemente para as telas adjacentes do `MainScreen` (`Estatísticas` e `Ajustes`), sem travar o usuário.
- **Eliminação do Tutorial Geral Redundante & Padronização Visual com o Ícone do App:**
  - Remoção completa da tela obsoleta `TutorialScreen` e centralização exclusiva nos tutoriais interativos contextuais (`InteractiveTabTutorial`).
  - Padronização das cores dos tutoriais interativos para refletirem fielmente o tema ativo do aplicativo e as tonalidades oficiais do ícone principal (`#1A1C2C` Marinho, `#0077B6` / `#0179F3` Azul Oceânico e `#10B981` Esmeralda), eliminando discrepâncias cromáticas.
- **Auditoria de Qualidade:** 0 erros no `flutter analyze`, 44/44 testes aprovados.

### v1.3.551 (17 de Outubro de 2026)
- **Blindagem Anti-Perda de Listas & Motor de Auto-Recuperação (`DatabaseHelper.recoverAndConsolidateUserData`):**
  - **Fim da Exclusão Destrutiva no `_loadMonths()` (`ItemProvider`):** Removido o loop que deletava em cascata (`ON DELETE CASCADE`) os meses do SQLite local quando uma planilha recém-criada ou temporariamente dessincronizada no Google Drive retornava vazia ou apenas com a aba `Página1`. Agora a sincronização é 100% aditiva e envia automaticamente qualquer lista local ausente para o Google Sheets em segundo plano (`_pushMissingLocalMonthToCloud`).
  - **Filtro Estrito de Abas Padrão & Seleção Inteligente de Planilha (`UserSheetsService`):** `getAvailableMonths()` nunca mais retorna `Página1` / `Sheet1` como nome de lista, e `_ensureSpreadsheetExists()` filtra `trashed = false` e prioriza a planilha `CARRIN_Lista_Compras*` que contém abas reais caso existam duplicatas no Google Drive.
  - **Auto-Recuperação Multi-Fonte (`recoverAndConsolidateUserData`):** Na abertura do app e na troca de perfil, o `DatabaseHelper` varre automaticamente outros arquivos `.db` locais (`guest`, `offline`, contas), snapshots JSON (`local_backup_carts_v1`), caches de histórico de preços (`cache_price_history_v2*`) e cache local da comunidade (`community_prices_cache`) para restaurar imediatamente qualquer lista ou item que tenha sumido.
  - **Carregamento Instantâneo das Listas no Boot (`_initProvider`):** As listas e itens locais do SQLite são carregados e exibidos na tela antes da inicialização do catálogo de 3.484 supermercados.

### v1.3.550 (17 de Outubro de 2026)
- **Mapa Limpo & Modo Noturno 100% Sem API Key (Servidores Google Maps):**
  - Substituição definitiva dos tiles da CartoDB (`basemaps.cartocdn.com`, que passaram a exigir API Key) por tiles nativos do próprio Google Maps (`mt{s}.google.com/vt/lyrs=m&hl=pt-BR&apistyle=s.t:2|p.v:off,s.t:4|p.v:off`) para o **Mapa Limpo** (ocultando POIs comerciais de terceiros sem chave de API) e com filtro matricial acelerado por GPU (`_darkMapColorFilter`) para o **Modo Noturno** (preservando azul oceânico e verde de parques).
- **Fluidez Total (60/120 FPS) nos Tutoriais Interativos (`InteractiveTabTutorial` & `TutorialScreen`):**
  - Eliminação de disparos prematuros/duplicados durante o arraste do `PageView` entre abas (`MainScreen` agora aguarda a estabilização completa da aba antes de exibir o tutorial da primeira visita, sem interromper o gesto de swipe ou abas intermediárias).
  - Transições aceleradas por GPU com `FadeTransition` + `ScaleTransition` + `RepaintBoundary` (removendo o `Opacity` que forçava `saveLayer` a cada frame).
  - Adicionadas pílulas rápidas clicáveis de passos no topo de cada card, `AnimatedSize` suave entre passos e suporte a gesto de arrasto horizontal.
  - Substituição de chamadas assíncronas de canal nativo (`Vibration.hasVibrator()`) por `HapticFeedback.selectionClick()` instantâneo (`<1ms`).

### v1.3.549 (17 de Outubro de 2026)
- **Seletor Visual de Camadas Estilo Google Maps & Escolha de Ponto no Mapa (`MarketMapScreen`):**
  - Adicionado menu visual de camadas (`_showMapStyleAndLayersSheet`) com miniaturas desenhadas para **Padrão Google**, **Satélite**, **Relevo**, **Mapa Limpo**, **OpenStreetMap** e **Noturno**, além de controles sem conflito para exibir/ocultar pinos e escolher qualquer mercado ou ponto tocando direto no mapa.

### v1.3.548 (17 de Outubro de 2026)
- **Decodificação Nativa dos Mapas `.mwm` (Maps.me) — 3.484 Supermercados Geolocalizados:**
  - Extração direta dos 4 arquivos binários `.mwm` na raiz do projeto cobrindo Rio de Janeiro (`Meus Locais.kmb`), Espírito Santo (`bm.order`), São Paulo Campinas (`2026-10-16`) e São Paulo Capital (`2026-10-17`), totalizando **3.484 supermercados e atacadistas** em `DefaultSupermarketsData.all`.

### v1.3.547 (17 de Outubro de 2026)
- **Cards de Demonstração & Tutoriais Interativos por Aba (`InteractiveTabTutorial` & `InteractiveSectionTutorialCard`):**
  - Criação do serviço e componente [`lib/widgets/interactive_tab_tutorial.dart`](file:///C:/Dev/CARRIN/lib/widgets/interactive_tab_tutorial.dart) cobrindo todas as 8 seções do aplicativo (`dashboard`, `carts`, `shoppingList`, `statistics`, `buyerProfile`, `community`, `marketMap`, `settings`).
  - **Exibição Automática na Primeira Visita:** Ao entrar pela primeira vez em cada uma das 5 abas principais (`MainScreen`) ou nas telas `ShoppingListScreen`, `BuyerProfileScreen` e `MarketMapScreen`, o app exibe automaticamente o tutorial interativo passo a passo daquela seção.
  - **Cards de Demonstração Interativos nos Estados Vazios:** Substituição dos avisos estáticos de tela vazia em `MonthSelectionScreen` e `StatisticsScreen` (e na calibração inicial do `BuyerProfileScreen`) por cards interativos funcionais onde o usuário pode testar recursos na hora.
  - **Botão de Ajuda (`?`) Global & Reset de Tutoriais:** Adicionado botão `Icons.help_outline_rounded` na `AppBar` de todas as abas e telas para reabrir o card interativo sob demanda, além da opção *"Resetar Tutoriais das Abas"* em `SettingsScreen` e `TutorialScreen`.
  - **Reformulação Completa do `TutorialScreen` (`lib/screens/tutorial_screen.dart`):** Atualizado para refletir as 5 abas atuais do rodapé, Radar de Preços Comunitário, Mapa com pinos leves sob demanda e filtro de redes, Scanner Direto para Edição via API sem popups intermediários, NFC-e SEFAZ, Perfil de Comprador, Rateio e Calculadoras, com 100% dos slides interativos.
- **Validação Automatizada:** 0 advertências no `flutter analyze`, 43/43 testes aprovados.

### v1.3.546 (17 de Outubro de 2026)
- **Mapa Ultrarrápido (60 FPS) & Pinos Limpos Sob Demanda (`MarketMapScreen`):**
  - Remoção dos rótulos permanentes de texto em todos os 154 marcadores do mapa, substituindo-os por pinos leves encapsulados em `RepaintBoundary`.
  - O nome do supermercado e sua média de preço aparecem apenas ao clicar no pino (em um callout flutuante sobre o pino selecionado e no card inferior sincronizado).
  - Carregamento instantâneo via cache local SQLite sem bloquear no GPS ou rede.
- **Pesquisa por Nome e Filtro por Redes de Supermercados:**
  - Adicionada barra de pesquisa integrada no topo do `MarketMapScreen` (com autocompletar flutuante) e na aba *Mercados* do `CommunityRadarScreen`.
  - Adicionados chips horizontais de filtro por redes (`Todas`, `Guanabara`, `Supermarket`, `Rede Economia`, `Assaí`, `Mundial`, `Real`, `Atacadão`, `Grand Marché`, `Prezunic`, `Princesa`, `Super Rede`, `Dom Atacadista`, `Pão de Açúcar`, `Zona Sul`, `Multi Market`, `Carrefour`, `Outras`) via `DefaultSupermarketsData.mainChains`.
- **Carregamento Instantâneo da Aba Comunidade (`CommunityRadarScreen`):**
  - Eliminação de 3 chamadas HTTP redundantes seguidas ao Supabase e bloqueio de até 4s do GPS na abertura da aba. A tela agora renderiza em `<50ms` a partir do cache SQLite (`preloadedPrices`) e sincroniza GPS + nuvem em segundo plano.
  - Substituição de listas `.map()` ansiosas por `CustomScrollView` + `SliverList.builder` preguiçosos nas 3 abas (*Lista*, *Comparador* e *Mercados*).
  - Otimização de `DatabaseHelper.ensureDefaultSupermarkets()` com `txn.batch()` em transação única e cache $O(1)$ em `DefaultSupermarketsData.findMatch()`.
- **Scanner de Produtos Direto para Edição (0ms & Sem Popups):**
  - Ao escanear qualquer código de barras, o app abre instantaneamente o menu de edição de produto (`_showEditDialog`) sem nenhum popup de confirmação intermediário e sem espera em tela preta, preenchendo automaticamente nome, marca, categoria e preço assim que resolvidos no cache local ou nas APIs Open Food Facts / Open Beauty Facts / Open Products Facts.

### v1.3.545 (16 de Outubro de 2026)
- **Eliminação de Marcador Duplicado do Guanabara Niterói:** Unificação dos nomes `'Supermercados Guanabara'` e `'Supermercados Guanabara - Niterói'` sob o mesmo registro canônico. Anteriormente, as compras do usuário cadastradas sob o nome genérico geravam um marcador de cotações, enquanto o catálogo estático gerava um segundo marcador no mesmo local. A agregação do `CommunityPriceService` e a limpeza do SQLite agora consolidam todos os dados sob um único pino oficial.
- **Inclusão de 15 Supermercados Extraídos do Maps.me:** Incorporação de 15 estabelecimentos comerciais pesquisados na região de Niterói com coordenadas de alta precisão ao catálogo oficial (`DefaultSupermarketsData.all`), elevando o total para 154 lojas mapeadas:
  - *Multi Market (Santa Rosa)*
  - *Pomar Supermercados (Santa Rosa e Icaraí)*
  - *Super Prix (Icaraí - Otávio Carneiro e Praia)*
  - *Mercado Extra (Centro)*
  - *Princesa Supermercados (Icaraí e Fonseca)*
  - *Mercado Municipal de Niterói (Feliciano Sodré)*
  - *Mercado Fruto da Terra (Icaraí)*
  - *Rede Economia (Ingá e Centro de Niterói)*
  - *Supermercado Garritano (Centro)*
  - *Hortifruti (Icaraí)*
  - *Mercado Orgânico Korin (Icaraí)*
- **Validação Automatizada:** 0 advertências no `flutter analyze`, 39/39 testes aprovados.

### v1.3.544 (16 de Outubro de 2026)
- **Fluxo Direto de Escaneamento de Código de Barras (Zero Fricção):** Ao escanear o código de barras de um produto inexistente na lista, o app elimina completamente o popup intermediário de confirmação (*"Deseja adicioná-lo agora?"*) e abre diretamente a aba/diálogo de edição com todos os dados preenchidos (*nome oficial, categoria sugerida, último preço e código de barras*).
- **Badge de Origem no Formulário de Edição:** Inclusão de indicador sutil no formulário informando que as informações foram importadas via leitura de código de barras.
- **Validação Automatizada:** 0 advertências no `flutter analyze`, 37/37 testes aprovados.

### v1.3.543 (16 de Outubro de 2026)
- **Identificação Inteligente de Produtos via Código de Barras (Online + Offline):** Criação do serviço `BarcodeLookupService` que identifica produtos instantaneamente ao escanear códigos de barras EAN-13/EAN-8 pela câmera do celular.
- **Integração com Open Food Facts Brasil:** Ao escanear um produto que ainda não existe no histórico do usuário, o CARRIN consulta em tempo real a base aberta do Open Food Facts (`world.openfoodfacts.org/api/v2/`), obtendo nome oficial do produto, marca, gramatura e foto de alta resolução.
- **Sugestão Automática de Categoria:** O algoritmo inteligente de categorização (`ItemProvider.suggestCategoryForName`) analisa o nome e marca retornados pela API e sugere automaticamente a seção correta da lista (ex: Bebidas, Mercearia, Limpeza, Higiene, Hortifruti).
- **Diálogo Interativo de Confirmação:** Modal elegante com thumbnail do produto, selo visual de origem (`🌐 Base Aberta (Online)` ou `🛒 Seu Histórico`), badge da categoria com emoji correspondente e botão direto *"Adicionar à Lista"*.
- **Preenchimento Automático na Edição Manual:** O leitor de código de barras embutido no formulário de adição/edição de item também pesquisa online e autocompleta nome e categoria caso o campo esteja vazio.
- **Cache Local & Timeout Resiliente:** Respostas salvas em memória para consulta ultrarrápida repetida e timeout de 4 segundos que garante fluidez sem travamentos caso o usuário esteja em subsolos com conexão instável.
- **Validação Automatizada:** 0 advertências no `flutter analyze`, 37/37 testes aprovados.

### v1.3.542 (16 de Outubro de 2026)
- **Correção Estrutural de Prioridade no Motor de Coordenadas:** O `CommunityPriceService.getCheapestMarketsNearby()` e `resolveMarketCoordinates()` agora priorizam incondicionalmente o catálogo calibrado (`DefaultSupermarketsData`), impedindo que coordenadas antigas cacheadas em registros legados do SQLite ou Supabase prendam as lojas em locais incorretos no mapa.
- **Sincronização Ativa do SQLite:** O `DatabaseHelper.ensureDefaultSupermarkets()` agora atualiza em massa as coordenadas da tabela `community_prices_cache`, realinhando todos os pinos de compras antigas aos supermercados reais.
- **Auditoria Geográfica Automatizada (OpenStreetMap / Nominatim):** Varredura dos 139 supermercados cadastrados contra a base cartográfica oficial, identificando e corrigindo 54 desvios causados por aproximações de IA (com discrepâncias corrigidas de até 2,9 km em Niterói, São Gonçalo, Maricá, Itaboraí e Rio de Janeiro).
- **Validação:** 0 advertências no `flutter analyze`, 34/34 testes automatizados aprovados.

### v1.3.541 (16 de Outubro de 2026)
- **Correção Fina de Localização - Rede Economia (Rio do Ouro):** Ajuste das coordenadas para `-22.88727, -42.98817` na Av. Doutor Eugênio Borges, 7500 (Rodovia RJ-106 / Amaral Peixoto), corrigindo desvio de cadastro anterior que apontava para rua residencial interna.
- **Inclusão do Mercado Varsilva (Rio do Ouro / Engenho do Roçado):** Cadastro oficial do tradicional supermercado local `Mercado Varsilva - Rio do Ouro` nas coordenadas exatas `-22.88476, -42.98544` (Estrada do Engenho do Roçado, 15 / Rua Vereador Luiz Paulo Guimarães).
- **Total de Supermercados Geolocalizados Atualizado:** 139 lojas catalogadas com endereço físico completo em Niterói, São Gonçalo, Maricá, Itaboraí e Rio de Janeiro.
- **Validação Automatizada:** 0 advertências no `flutter analyze`, 34/34 testes de unidade e widgets aprovados.

### v1.3.540 (16 de Outubro de 2026)
- **Integração Total da Revisão de 138 Supermercados:** Incorporação da auditoria completa com 100% de conferência dos 138 supermercados de Niterói, São Gonçalo, Maricá, Itaboraí e Rio de Janeiro.
- **Ajustes de Precisão Cirúrgica nas 12 Unidades com Desvio:** Grand Marché (Itaipu, Fonseca, Barreto), Mercado Diamante (Engenhoca), Mercado Flor da Jurujuba, Mercado Itaipu (Engenho do Mato), Mercado Rio do Ouro, Prezunic (Alcântara), Super Rede (Trindade), Rede Economia (Venda das Pedras) e Super Rede (Venda das Pedras e Centro de Itaboraí).
- **Endereço Físico Completo Registrado em Cada Loja:** Adicionado o campo `address` em `PreloadedSupermarket` para todos os 138 estabelecimentos cadastrados.
- **Exibição do Endereço no Mapa:** O endereço físico real agora é exibido tanto no painel inferior de detalhes (`_showMarketBottomSheet`) quanto na lista de resultados da busca rápida (`_openSearchDialog`).
- **Validação:** 0 advertências no `flutter analyze`, 33/33 testes aprovados.

### v1.3.571 (19 de Outubro de 2026)
- **Correção Crítica no Carregamento de Recursos das Notificações:**
  - Resolução do erro `invalid_large_icon` no Android (`FlutterLocalNotificationsPlugin`): o `largeIcon` referenciando recurso inexistente na pasta drawable foi corrigido, mapeando o bitmap nativo para `ic_carrin_logo` em todas as densidades de tela (`drawable-mdpi`, `drawable-hdpi`, `drawable-xhdpi`, `drawable-xxhdpi`, `drawable-xxxhdpi`).
  - Adição de blocos de proteção `try/catch` com log detalhado em todos os métodos de disparo e cancelamento do `NotificationService`.
- **Canal de Notificações com Prioridade Padrão (`shopping_list_progress_v5`):**
  - Migração para `Importance.defaultImportance` (com som e vibração desativados), garantindo exibição confiável na barra de status e tela de bloqueio em interfaces customizadas (Samsung One UI, Xiaomi HyperOS/MIUI e Motorola) sem incomodar com toques a cada item comprado.
- **Persistência da Notificação em Segundo Plano:**
  - Correção no ciclo de vida em `lib/main.dart` e `PopScope` de `lib/screens/main_screen.dart`: a notificação de compras agora permanece ativa quando o usuário bloqueia a tela, abre a calculadora ou alterna entre apps no supermercado, sendo encerrada apenas ao fechar o app da multitarefa (`onTaskRemoved`) ou ao finalizar a lista.
- **Disparo e Atualização Automática Imediata:**
  - O monitor de compras agora é atualizado automaticamente ao iniciar o app com lista salva, ao alternar entre listas no seletor de meses e ao ativar o switch nas configurações.
- **Validação:** 0 advertências no `flutter analyze`, 61/61 testes unitários aprovados.

### v1.3.570 (19 de Outubro de 2026)
- **Ativação Real do Modo Daltônico com Matrizes de Daltonização:** Implementação de pipeline de filtragem cromática global no root da aplicação (`MaterialApp.builder` com `ColorFiltered` e `ColorFilter.matrix`), garantindo transformação óptica em tempo real de 100% dos elementos da interface (telas, ícones, botões, gráficos, cards, badges e alertas).
- **Calibração Científica para Tipos de Daltonismo:**
  - **Deuteranopia (Dificuldade com verde):** Matriz de transposição espectral que desloca os canais para azul/laranja/amarelo de alta legibilidade.
  - **Protanopia (Dificuldade com vermelho):** Matriz que reforça a luminosidade dos tons vermelhos (evitando aspecto escuro/apagado) e preserva distinção de alertas.
  - **Tritanopia (Dificuldade com azul/amarelo):** Realce do contraste azul-verde com proteção de tons quentes.
  - **Alto Contraste:** Matriz de amplificação de contraste dinâmico (+35%) combinada com sementes de tema preto/esmeralda para legibilidade absoluta sob luz solar.
- **Prévia Visual em Tempo Real nas Configurações:** Cada modalidade na caixa de diálogo de seleção exibe 3 círculos com a paleta de cores correspondente (Sucesso, Alerta, Destaque), facilitando a escolha imediata do usuário.
- **Validação:** 0 advertências no `flutter analyze`, 61/61 testes unitários aprovados.

### v1.3.569 (18 de Outubro de 2026)
- **Download Silencioso de Atualizações em Segundo Plano:** O aplicativo não exibe mais popups interruptivos solicitando permissão para baixar atualizações. Ao detectar uma nova versão no GitHub/OTA, o download do APK é iniciado silenciosamente em segundo plano enquanto o usuário navega normalmente pelo app.
- **Aviso Compacto de Instalação com Notas Expansíveis:** Ao término do download, o usuário é notificado com um card compacto ("Atualização Pronta!") contendo um link sutil expansível *"Notas da versão ▼"* (recolhido por padrão para não poluir a tela) e botão direto *"Instalar Agora"*.
- **Download Atômico e Limpeza de Cache:** Implementação de escrita atômica com arquivo temporário `.apk.part` renomeado somente após a conclusão do streaming, prevenindo corrupção de arquivos em conexões instáveis, além de purga automática de instaladores antigos.
- **Conformidade Integral com a LGPD (Lei nº 13.709/18):** Atualização completa da tela de Termos e Privacidade (`TermsScreen`) com 9 tópicos jurídicos claros (Minimização, SQLite local, OAuth pessoal do Google Sheets, Anonimização total do Radar Supabase, descarte de CPF de cupons NFC-e da SEFAZ, localização não-comercializada e canal DPO).
- **Validação:** 0 advertências no `flutter analyze`, 61/61 testes unitários aprovados.

### v1.3.568 (18 de Outubro de 2026)
- **Bloqueio de Orientação em Modo Retrato:** Fixação do app exclusivamente em modo vertical (`portraitUp`), prevenindo giros acidentais para paisagem em celulares e tablets.
- **Persistência Garantida da Escala de Fontes:** Correção e persistência do ajuste de fonte (85%, 100%, 115%) via `SharedPreferences`.
- **Ícone Nativo em Notificações:** Correção do ícone de carrinho (`ic_notification_cart`) nas notificações do Android.
- **Adaptação para Barra de Navegação Inferior:** Margens seguras com `SafeArea` e compatibilidade total com a barra de botões nativos do rodapé (voltar, home e janelas).
- **Validação:** 0 advertências no `flutter analyze`, 61/61 testes unitários aprovados.

### v1.3.539 (16 de Outubro de 2026)
- **Calibração Exata de Geolocalização (GPS & Rooftop OSM):** Auditoria e correção de precisão métrica de todas as coordenadas de supermercados na API/catálogo (`DefaultSupermarketsData`), cruzando dados com o banco do OpenStreetMap/Photon.
- **Localização Exata do Assaí Atacadista Tribobó:** Posicionamento corrigido para a Av. Fued Moisés, 114 – Tribobó, São Gonçalo (`-22.85444, -43.02005`), no entroncamento das rodovias RJ-104 e RJ-106 (terreno da antiga Carta Fabril).
- **Correção Geral de Mercados Fora de Posição:** Calibração física dos mercados de Tribobó, Rio do Ouro, Arsenal, Maria Paula, Maricá (Inoã, Itaipuaçu, São José do Imbassaí, Centro) e Itaboraí.
- **Atualização Automática no SQLite Existente:** Aprimoramento de `ensureDefaultSupermarkets()` no `DatabaseHelper` para atualizar incondicionalmente as coordenadas de lojas pré-existentes, garantindo que usuários recebam as localizações corrigidas imediatamente ao abrir o app.
- **Resolução Inteligente de Coordenadas na API:** O serviço `CommunityPriceService` agora resolve as coordenadas reais da loja (`resolveMarketCoordinates`) ao sincronizar compras do usuário para a nuvem Supabase, eliminando o envio de coordenadas nulas.
- **Busca Rápida de Mercados no Mapa:** Novo botão de pesquisa (`Icons.search_rounded`) no `MarketMapScreen` permitindo digitar termos (ex: *"Tribobó"*, *"Assaí"*, *"Rio do Ouro"*, *"Inoã"*) com busca insensível a acentos/diacríticos e vôo direto do mapa para a loja.
- **Ampliação dos Chips de Raio:** Adicionados chips de 25 km e 50 km para visualização regional expandida.
- **Validação:** 0 advertências no `flutter analyze`, 33/33 testes aprovados.

### v1.3.538 (16 de Outubro de 2026)
- **Expansão Massiva de Supermercados (120+ Lojas Geolocalizadas):** Mapeamento exato de todos os supermercados de médio e pequeno porte das regiões de **Niterói, São Gonçalo, Maricá, Itaboraí e Rio de Janeiro** (`DefaultSupermarketsData.all`).
- **Cobertura Específica de Tribobó e Rio do Ouro:** Adição de `Supermarket - Rio do Ouro`, `Rede Economia - Rio do Ouro`, `Mercado Rio do Ouro`, `Assaí Atacadista - Tribobó`, `Rede Economia - Tribobó`, `Supermarket - Arsenal / Tribobó`, `Real Supermercados - Maria Paula` e `Rede Economia - Várzea das Moças`.
- **Inclusão Completa do Município de Maricá:** Mapeamento integral de todos os eixos comerciais: Centro (`Supermarket`, `Princesa`, `Rede Economia`, `Super Rede`), Inoã (`Dom Atacadista`, `Supermarket`, `Super Lagos`, `Supermercado Litoral`, `Costazul Multimercado`), Itaipuaçu / Barroco (`Grand Marché Barroco`, `Grand Marché Recanto`, `Supermercado Rio Sul`, `Rede Economia`), São José do Imbassaí (`Supermarket`, `Mercado Joana`) e Itapeba (`Atacadão Maricá`, `Assaí Atacadista Maricá`).
- **Redes Locais e de Bairro de Niterói e São Gonçalo:** Inclusão de todas as unidades da rede Real Supermercados (Icaraí, Santa Rosa, São Francisco, Pendotiba, Piratininga, Maravista, Itaipu), Grand Marché, unidades de bairro da Rede Economia e Supermarket.
- **Validação:** 0 advertências no `flutter analyze`, 32/32 testes aprovados.

### v1.3.537 (16 de Outubro de 2026)
- **Supermercados Pré-Cadastrados no Mapa & Geofencing:** Inclusão de mais de 60 unidades reais das principais redes de **Niterói, São Gonçalo, Itaboraí e Rio de Janeiro** com coordenadas geográficas exatas e raio de alcance calibrado (`DefaultSupermarketsData.all`).
- **Localização Instantânea para Novos Usuários:** Ao abrir o app ou chegar a qualquer supermercado dessas cidades, o `LocationService` reconhece a loja automaticamente em segundo plano (mesmo sem internet no subsolo).
- **Mapa dos Mercados Totalmente Povoado:** O mapa interativo (`MarketMapScreen`) já exibe todos os supermercados da região ao redor do usuário, permitindo traçar rotas imediatas com o botão *"Como Chegar"*.
- **Preservação de Estabelecimentos Reais:** Fim de filtros restritivos legados; compras realizadas em qualquer rede são registradas com a marca correta, mantendo apenas a purga de dados mock/teste.
- **Validação:** 0 advertências no `flutter analyze`, 32/32 testes automatizados aprovados.

### v1.3.536 (16 de Outubro de 2026)
- **Mapa Geográfico Interativo de Mercados:** Nova tela `MarketMapScreen` utilizando `flutter_map: ^8.3.2` e `latlong2: ^0.10.1`, integrada ao Radar de Preços e acessível via botão na AppBar e banner na aba Mercados.
- **Pinos com Destaque e Badges de Menor Preço:** Identificação visual imediata do mercado líder em economia (`👑 Mais Barato`), preço médio e distância.
- **Traçado de Rotas GPS Externas:** Botão *"Como Chegar"* com abertura nativa no Google Maps e Waze via protocolo `geo:` e fallback web através de `url_launcher: ^6.3.3`.
- **Carrossel Inferior Sincronizado:** Navegação por cards deslizantes que movem o mapa para cada supermercado em tempo real.
- **Consultas Declaradas no AndroidManifest:** Inclusão de `<queries>` para esquemas `geo` e `https` no Android 11+ (API 30+).
- **Validação Completa:** 0 advertências no `flutter analyze`, 31/31 testes aprovados.

### v1.3.535 (16 de Outubro de 2026)
- **Filtro de Supermercados no Comparador:** Substituição de atalhos de alimentos por chips de estabelecimentos reais (`Todos os Mercados`, `Supermercados Guanabara`).
- **Remoção de Pré-seleção Forçada:** Fim da auto-seleção arbitrária do primeiro produto alfabético ("Abobrinha"); a tela abre limpa com aviso instrutivo e botão de fechar detalhes.
- **Agrupamento e Desduplicação de Cotações:** Eliminação de cartões repetidos e datas idênticas (`16/10/2026`) para o mesmo mercado. Cada supermercado agora é exibido exatamente uma vez, destacando o menor preço, quantidade de compras registradas e faixa de variação.
- **Limpeza no Git:** Adição de máscaras de captura de screenshots de teste (`WhatsApp*.jpeg`) ao `.gitignore`.

### v1.3.534 (16 de Outubro de 2026)
- **Varredura e Higienização de Código:** Remoção de scripts scratch rastreados (`test_gsheets.dart`), limpeza de arquivos temporários e atualização de referências legadas de supermercados de teste para `Supermercados Guanabara`.
- **Ajuste Fino de Detecção OSM:** Inclusão de `guanabara` com prioridade na expressão regular do `LocationService`.
- **Validação:** 0 erros no `flutter analyze`, 29/29 testes automatizados aprovados.

### v1.3.533 (16 de Outubro de 2026)
- **Eliminação Definitiva de Mercados de Teste:** Purga completa no SQLite e filtro rigoroso no feed Supabase descartando registros de teste iniciais.
- **Associação Unificada Guanabara Niterói:** Garantia de que todos os produtos comprados pelo usuário pertençam exclusivamente ao Guanabara de Niterói.

### v1.3.530 a v1.3.532 (15 e 16 de Outubro de 2026)
- **Comunidade na Navegação do Rodapé:** Inclusão do Radar de Preços como a 4ª aba nativa do `MainScreen`.
- **Remoção de Credenciais Expostas:** Supabase URL e Anon Key embutidos de forma segura no serviço sem exibição em tela de ajustes.
- **Comparador Pré-Preenchido:** A aba de comparação carrega automaticamente com os produtos reais das compras do usuário ao ser aberta.

### v1.3.515 a v1.3.525 (15 de Outubro de 2026)
- **Integração Supabase REST:** Criação do serviço `CommunityPriceService`, arquitetura RLS pública e auto-sync de compras em background.
- **Cálculo de Distância Haversine:** Filtro dinâmico por raio GPS e cálculo de proximidade de cada supermercado.
- **Diagnóstico de Perfil de Comprador (`BuyerProfileScreen`):** Algoritmo de análise comportamental e categorização de hábitos de compra.

### v1.3.500 a v1.3.514 (13 a 15 de Outubro de 2026)
- **Leitor de Cupom Fiscal SEFAZ (`ReceiptScannerScreen`):** Parsing inteligente de QR Code de NFC-e e notas de 1 e 2 linhas.
- **Acessibilidade Completa:** Inclusão de filtros para daltônicos (Protanopia, Deuteranopia, Tritanopia) e ajuste dinâmico da escala de fontes no `ThemeProvider`.
- **Calculadora Flutuante Assistiva:** Widget flutuante arrastável na tela de compras para auxílio em contas rápidas durante a feira.

### v1.3.5 e anteriores (Maio de 2026)
- **OAuth 2.0 User Sheets:** Migração definitiva de Service Account para conta Google do próprio usuário (`UserSheetsService`).
- **Navegação Orgânica Timeline Lock:** Respeito absoluto à ordem de criação de planilhas e carrinhos.
- **Exportação PDF com Emojis:** Geração de relatórios elegantes com fontes leves e emojis visuais.