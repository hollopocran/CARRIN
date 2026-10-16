# CARRIN — Sua lista, sem complicação. 🛒

O **CARRIN** é um ecossistema mobile inteligente em Flutter para gestão financeira doméstica, compras de supermercado e economia colaborativa comunitária.

---

## ✨ Principais Funcionalidades

* 📱 **Privacidade Total com Google Sheets:** Sincronização direta com a planilha pessoal do seu Google Drive via OAuth 2.0. Seus dados nunca passam por servidores de terceiros.
* ⚡ **Arquitetura Offline-First (SQLite):** Todas as operações funcionam instantaneamente mesmo sem sinal no supermercado, com fila resiliente de sincronização.
* 📡 **Radar de Preços Comunitário (Supabase):** Feed em tempo real de preços colaborativos, com comparador de economia (%) e ranking de mercados mais baratos por proximidade GPS.
* 🗺️ **Mapa Geográfico Interativo (OpenStreetMap):** Visualização de supermercados no mapa em tempo real com GPS do usuário, destaque visual do mercado mais barato (`👑`), carrossel sincronizado e rotas externas para Google Maps e Waze.
* 📍 **Geofencing e Reconhecimento de Supermercado:** Identificação automática de quando você chega ao supermercado (calibrado para *Supermercados Guanabara Niterói*).
* 🧾 **Scanner Duplo Inteligente:**
  * **Código de Barras (EAN-13):** Preenchimento automático de nome, preço e categoria a partir do seu histórico de compras.
  * **Cupom Fiscal / NFC-e (SEFAZ QR Code):** Leitura de notas fiscais com extração de itens, quantidades e valores.
* ⚖️ **Calculadora de Peso (Kg):** Calcula a quantidade comprada automaticamente ao digitar o preço por quilo e o valor total na balança.
* 🧮 **Calculadora Flutuante & Rateio:** Assistente de cálculo rápido em cima da lista e divisão de conta por pessoa com 1 toque.
* 📊 **Análises & Perfil de Comprador:** Gráficos interativos (`fl_chart`) e algoritmo que traça seu perfil de consumo (Econômico, Gourmet, Planejador, etc.).
* 🎨 **Personalização & Acessibilidade:** Temas Claro, Escuro e Pastel, seletor de ícone do app, modos para daltônicos (Protanopia, Deuteranopia, Tritanopia) e controle de tamanho de fonte.
* 📄 **Exportação em PDF:** Gere relatórios profissionais das compras para impressão ou compartilhamento direto no WhatsApp.

---

## 🗺️ Mapa do Aplicativo (5 Abas no Rodapé)

1. **Início (`DashboardScreen`):** Medidor circular de orçamento, grid reordenável de métricas e atalhos rápidos.
2. **Carrinhos (`MonthSelectionScreen`):** Histórico completo de listas por ordem cronológica orgânica.
3. **Análises (`StatisticsScreen`):** Gráficos de evolução temporal, gastos por categoria e perfil de comprador.
4. **Comunidade (`CommunityRadarScreen`):** Feed de preços, comparador de produtos e ranking de mercados mais baratos no raio GPS.
5. **Ajustes (`SettingsScreen`):** Cores de tema, ícone, acessibilidade, backup/restauração e termos.

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

Para detalhes aprofundados sobre a arquitetura de dados (SQLite, Supabase, Google Sheets API), diagrama Mermaid do mapa do app e histórico de versões, consulte o arquivo [DOCUMENTATION.md](file:///C:/Dev/CARRIN/DOCUMENTATION.md).
