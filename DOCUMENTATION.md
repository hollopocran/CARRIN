# Documentação do Projeto: CARRIN (Gestor de Compras)

Esta documentação detalha a arquitetura, as tecnologias utilizadas, as funcionalidades implementadas e o histórico de manutenções e refatorações realizadas no aplicativo "CARRIN" (anteriormente conhecido como Gestor de Compras).

## 1. Visão Geral do Projeto
O **CARRIN** é um aplicativo mobile desenvolvido em Flutter focado na gestão financeira e organização de compras de supermercado. Seu grande diferencial é a sincronização bidirecional (via API) com o **Google Sheets**. Cada mês ou lista de compras é mapeada como uma aba (worksheet) dentro de uma planilha do Google Sheets, permitindo que o usuário gerencie seus gastos tanto pelo celular quanto pelo computador.

### 1.1 Tecnologias Principais
- **Framework:** Flutter / Dart
- **Gerenciamento de Estado:** `provider` (Provider Pattern)
- **Banco de Dados / Nuvem:** Google Sheets via package `gsheets`
- **Armazenamento Local (Cache):** `shared_preferences`
- **Formatação de Dados:** `intl` (Moeda e datas no padrão pt_BR)
- **Exportação e Compartilhamento:** `pdf` e `printing` (para geração de listas estilizadas)
- **Notificações:** `flutter_local_notifications`

---

## 2. Arquitetura e Integração com Google Sheets

A persistência de dados é baseada na nuvem, sendo armazenada **diretamente no Google Drive pessoal de cada usuário**. O aplicativo possui mecanismos robustos de banco de dados local (SQLite) e cache em memória para permitir o carregamento imediato das telas enquanto a sincronização bidirecional ocorre em segundo plano.

### 2.1 Autenticação e Segurança (Google Sign-In)
A partir de Maio de 2026, a arquitetura de Conta de Serviço (Service Account genérica com `credentials.json` fixo) foi removida do aplicativo em favor da **Autenticação de Usuário**. 
- O aplicativo utiliza os pacotes `google_sign_in` e `googleapis`.
- Cada usuário faz login com sua própria conta Google (OAuth 2.0).
- O aplicativo solicita as permissões (escopos) `drive.file` e `spreadsheets`. 
- **Privacidade Total:** Os dados são salvos em uma planilha oculta chamada "CARRIN_Lista_Compras" criada automaticamente no Drive do usuário. O aplicativo só tem acesso à planilha que ele mesmo criou, e o desenvolvedor não tem acesso aos dados dos usuários.

### 2.2 Mapeamento Rígido de Células (UserSheetsService)
A comunicação agora utiliza a API REST v4 oficial do Google (substituindo o package `gsheets`). A leitura dos totais mensais foi fixada em coordenadas exatas para evitar erros de leitura:
- **Gasto Total:** Célula `C2`
- **Qtd Itens (Ativos):** Célula `E2`
- **Itens Comprados:** Célula `F2`
- **Saldo Restante:** Célula `G2`
- **Orçamento:** Célula `H2`

### 2.3 Estrutura da Planilha
A partir da linha 7 (`fromRow: 7`), o aplicativo lê e escreve os produtos na seguinte ordem de colunas (iniciando na coluna B):
1. Quantidade (Coluna B)
2. Produto (Nome) (Coluna C)
3. Preço Unitário (Coluna D)
4. Total (Calculado pela planilha ou pelo app) (Coluna E)
5. Categoria (Coluna F)
6. Status (Comprado: TRUE/FALSE) (Coluna G)
7. Código de Barras (Coluna H)

### 2.4 Sistema de Fila Offline e Banco Local (SQLite)
Para permitir que o app funcione offline ou sem conexão estável, o `ItemProvider` gerencia os dados através de um banco de dados **SQLite** e de uma **Fila de Sincronização**:
- Todas as operações (adicionar item, criar carrinho, renomear, excluir) são salvas imediatamente no SQLite e colocadas numa fila invisível (`_syncQueue`).
- Essa fila é disparada em segundo plano e repassa as alterações para o Google Sheets (se o usuário possuir conexão e o token OAuth estiver válido).
- **Hard Reset Automático de Privacidade:** Quando um novo usuário faz login, o aplicativo detecta a alteração de e-mail e executa um `clearAll()` no banco de dados SQLite local, impedindo que dados do usuário anterior vazem para a nuvem do novo usuário.

### 2.5 Fonte da Verdade: Ordem de Criação (Timeline)
O aplicativo foi estruturado para seguir rigorosamente a **Ordem de Criação** das planilhas. A aba mais antiga lida do Google Sheets é considerada o passado, e a aba mais recente criada é o presente. O `ItemProvider._months` reflete isso (Antigo -> Novo), e todas as telas de análise, históricos e listas de meses respeitam esta "linha do tempo" orgânica.

---

## 3. Telas e Funcionalidades

### 3.1 DashboardScreen (Tela Inicial)
Atua como o resumo financeiro do mês corrente e menu de navegação principal.
- **Card de Resumo / Gauge Circular Animado:** Mostra o progresso do orçamento com cores dinâmicas (Azul, Laranja, Vermelho).
- **Grid Reordenável:** Atalhos rápidos para Saldo, Orçamento, Estatísticas e Carrinhos.
- **Sincronização:** Pull-to-refresh manual ou cache inteligente.

### 3.2 ShoppingListScreen (Lista de Compras)
A tela mais complexa do aplicativo, projetada para usabilidade com uma mão e otimização de espaço.
- **Layout Focado / Slivers:** Cabeçalho persistente com o "Gasto Atual", enquanto barras secundárias (Orçamento) podem ocultar no scroll.
- **Categorização Automática com Emojis:** Produtos novos recebem automaticamente emojis dependendo de palavras-chave.
- **Exportação Profissional em PDF:** Gera um relatório de compras no estilo premium do aplicativo, contendo o resumo financeiro, itens agrupados em "cards" com seus respectivos emojis usando a fonte leve `notoEmojiRegular`.

### 3.3 StatisticsScreen (Gráficos e Estatísticas)
Compara a evolução financeira ao longo da **Ordem de Criação**.
- **Filtros Temporais:** 3 meses, 6 meses, 1 ano, ou histórico total.
- **Detalhamento Híbrido:** Popups elegantes (estilo BottomSheet arredondados) exibem círculos de progresso (NEON) combinados com dados de saldo e métricas.
- **Temas Adaptáveis:** Todas as fontes e contrastes respeitam automaticamente as diretrizes do "Modo Escuro", garantindo legibilidade perfeita.

---

## 4. Histórico de Desafios e Refatorações Técnicas

Durante o desenvolvimento, vários ajustes precisos foram feitos para garantir a estabilidade e a estética do app:

1. **Bug da Barra de Progresso Sumindo:**
   - *Problema:* A animação foi quebrada por conta de um fechamento incorreto da árvore de widgets (`TweenAnimationBuilder`).
   - *Solução:* Correção estrutural na `DashboardScreen`. A barra agora cresce suavemente de 0 até `(total / budget)`.

2. **Simetria e Geometria de Slivers:**
   - *Problema:* O layout do cabeçalho da lista de compras apresentava o erro `RenderFlex overflow` e `SliverGeometry is not valid`.
   - *Solução:* Separação dos componentes entre `SliverToBoxAdapter` e `SliverPersistentHeader` com distâncias ajustadas manualmente.

3. **Sincronização de Valores (Discrepância):**
   - *Problema:* O Dashboard exibia o valor apenas dos itens "Comprados", não batendo com o Gasto Total real da planilha.
   - *Solução:* Leitura forçada das coordenadas rígidas `C2`, `G2` e `H2` no `SheetsService.getSummaryOnly` e unificação das chaves de cache.

---

## 5. Histórico de Atualizações Recentes (Maio 2026)

### 5.1 Redesign da Dashboard (Inspirado em Leaone)
- **Gauge Circular:** Substituição do card retangular por um medidor circular central de progresso, com cores dinâmicas e animação de carregamento.
- **Grid de Métricas:** Implementação de um layout em grade (2 colunas) e funcionalidade de "Drag & Drop" (Long Press para arrastar).

### 5.2 Melhorias de UX e Persistência
- **Persistência de Tema e Layout:** Salva escolha do usuário (Claro/Escuro) e ordem dos cards.
- **In-App Restart:** Opção de "Reiniciar Agora" após a limpeza de cache.

### 5.3 Grande Atualização de UX e Responsividade (12 de Maio de 2026)
- **Responsividade:** Navegação híbrida alternando entre `BottomNavigationBar` e `NavigationRail`. Limite de largura máxima (1000px) para ultra-wide.
- **Animações Premium:** Adição de efeitos staggered com curvas elásticas (`easeOutBack`).
- **Arquitetura Cache-First:** Dados locais renderizam instantaneamente enquanto a nuvem carrega em background.
- **Calculadora de Peso (Kg):** Calcula o peso (quantidade) automaticamente com base no preço por quilo e valor total pago.

### 5.4 Revisão de Estabilidade, Contagem e Animações (14 de Maio de 2026)
- **Contagem de Itens Corrigida:** Baseada na soma das quantidades (`quantity`) como double, tratando decimais de forma inteligente. Fórmulas `SUM` e `SUMIF` atualizadas no GSheets.
- **Central de Animações:** Menu dedicado em **Ajustes > Animações** para controle granular de efeitos visuais.
- **Estabilização de Keys:** Migração para `ValueKey` evitando corrupções de render tree no Hot Reload.

### 5.5 Notificações de Bloqueio, Splash Screen e Fluidez (15 de Maio de 2026)
- **Splash Screen Animada:** Tela de abertura customizada.
- **Notificações em Tempo Real:** Exibe progresso da compra (gasto e total) dinamicamente na tela de bloqueio com `flutter_local_notifications`.
- **Navegação por Swipe:** Implementação do `PageView` e `AutomaticKeepAliveClientMixin` para fluidez em telas 120Hz.

### 5.6 Rebranding CARRIN e Design System (16 de Maio de 2026)
- **Identidade Visual:** O aplicativo passa a se chamar **CARRIN** ("Sua lista, sem complicação.").
- **Paleta de Cores:** O Azul Marinho (`#1A1C2C`) é adotado como cor primária (`AppThemes.primaryNavy`).
- **Exportação de Relatórios Premium:** Compartilhamento em PDF via `printing` remodelado em formato de "Cards" com Emoji-font (`notoEmojiRegular`) ao invés do check genérico.

### 5.7 Arquitetura de Ordenação Orgânica (16 de Maio de 2026)
- **Timeline Lock:** Remoção de parseamento temporal. O aplicativo assume a **Ordem de Criação** na planilha (array bruto `_months` antigo -> novo) como sua timeline principal. A aba "Meus Carrinhos", gráficos, histórico de itens e popups seguem rigidamente essa progressão natural, eliminando bugs de dessincronia.

### 5.8 Limpeza Estrutural e Otimização (16 de Maio de 2026)
- **Codebase Cleanup:** Arquivos mortos deletados (ex: versão residual do `main_screen.dart`), imagens não utilizadas removidas e importações enxutas (`share_plus` substituído). A navegação base (Rodapé) foi reconstruída adequadamente após a limpeza.
- **Tamanho Reduzido:** Build otimizada com `tree-shaking` e `--split-per-abi`, resultando em um APK final (`carrin.apk`) de aproximadamente **~20.8MB** (ARM64).

### 5.9 Scanner Inteligente, Alertas e Edição em Lote (v8 - 18 de Maio de 2026)
- **APK v8:** Versão final consolidada como `CARRIN_v8.apk`.
- **Leitor de Código de Barras Híbrido:** Integração de scanner na tela principal e em campos dedicados. O sistema agora realiza o preenchimento automático (nome, preço e categoria) baseado no histórico de compras do usuário. Se o produto for novo, o campo de nome permanece limpo para personalização.
- **Busca via Scanner:** Escanear um item que já existe na lista atual redireciona o usuário instantaneamente para a edição desse item.
- **Alertas Inteligentes de Orçamento:** Implementação da notificação proativa "Pé no freio!" ao atingir 90% do orçamento definido.
- **Edição em Lote (Batch Edit):** Modo de seleção múltipla (long press) permitindo marcar como comprado ou excluir vários itens simultaneamente.
- **Modo Escuro de Alto Contraste:** Revisão completa do tema escuro, utilizando tons vibrantes/neon para garantir visibilidade total de gráficos, menus de navegação e botões de ação em qualquer nível de brilho.
- **Cache de Histórico Instantâneo:** Otimização do `ItemProvider` para garantir que novos códigos de barras salvos sejam descobertos imediatamente em todas as listas.
- **Manutenção de Dependências:** Atualização do plugin de vibração para suporte ao Android v2 embedding e migração para a API v5 do `mobile_scanner`.

### 5.10 Gerenciamento de Contas, Avatar, Interceptação de Voltar e Ajustes de Layout (22 de Maio de 2026)
- **Menu Dedicado de Contas (`AccountsScreen`):** Criação de uma tela exclusiva (`accounts_screen.dart`) para isolar todas as opções de contas online e locais (perfis offline). Centralizou a criação, edição, remoção e alternância de perfis.
- **Botão "Sair de Todas":** Implementação de remoção em massa de contas logadas em lote, limpando completamente todos os dados do SharedPreferences de uma só vez.
- **Integração Premium de Avatar:** 
  - Exibição do avatar real do usuário ativo no AppBar do Dashboard (`DashboardScreen`) com atalho direto de toque para a tela de contas.
  - Exibição de avatar na linha de menu das Configurações (`settings_screen.dart`), mostrando a imagem de perfil ou iniciais juntamente com nome e e-mail ativos de forma dinâmica.
- **Interceptação do Gesto Voltar (`PopScope`):** Implementação de `PopScope` no Scaffold do `MainScreen`. Caso o usuário realize a ação de voltar fora da aba "Início", o aplicativo intercepta o pop e o redireciona para a aba inicial ("Início") em vez de encerrar o aplicativo. O encerramento do app pelo botão voltar só é acionado na aba inicial.
- **Centralização do Cabeçalho da Home:** O título "Monitor de Gastos" na página inicial foi centralizado usando um widget `Center`, garantindo simetria no design.
* **bug offline deslog:** Corrigido loop de carregamento infinito no `DashboardScreen` após a remoção de um perfil offline. O problema ocorria devido a uma condição de corrida onde o painel esperava por dados que não seriam carregados para uma conta sem meses.
* **Melhoria de Template e Ordenação:** Refatorada a lógica de `useTemplate` para buscar o mês mais recente com itens (em vez de apenas o atual) e adicionada ordenação cronológica via `rowid` no SQLite para garantir a integridade da linha do tempo.
* **Correção de Layout (Viewport):** Adicionado `shrinkWrap: true` ao histórico de preços no diálogo de edição de itens para evitar exceções de dimensões intrínsecas em viewports.