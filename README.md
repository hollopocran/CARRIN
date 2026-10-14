# Aplicativo de Lista de compras

Este é um aplicativo Flutter para gerenciar sua lista de compras sincronizada com o Google Sheets.

## Configuração Necessária

1.  **Compartilhe sua Planilha:**
    Abra sua planilha no Google Sheets e compartilhe-a com o seguinte e-mail (com permissão de Editor):
    `lista-de-compras@listasheetapi.iam.gserviceaccount.com`

2.  **Instale o Flutter:**
    Certifique-se de ter o Flutter instalado em sua máquina. Se não tiver, baixe em [flutter.dev](https://flutter.dev).

3.  **Prepare o projeto:**
    Navegue até a pasta `lista_compras` e execute:
    ```bash
    flutter pub get
    ```

4.  **Execute o Aplicativo:**
    Conecte seu celular ou use um emulador e execute:
    ```bash
    flutter run
    ```

5.  **Gerar o APK:**
    Para gerar o arquivo instalável (APK), execute:
    ```bash
    flutter build apk --release
    ```
    O arquivo será gerado em `build/app/outputs/flutter-apk/app-release.apk`.

## Funcionalidades
- **Scanner Inteligente:** Adicione itens escaneando o código de barras. O app busca automaticamente nome e preço no histórico.
- **Busca via Scanner:** Escaneie um produto para encontrá-lo instantaneamente na sua lista atual.
- **Alertas de Orçamento:** Notificações automáticas quando você atinge 90% do seu orçamento planejado.
- **Edição em Lote:** Segure um item para selecionar vários e marcá-los como comprados ou excluí-los de uma vez.
- **Sincronização Nuvem:** Integração total e bidirecional com Google Sheets.
- **Calculadora de Peso:** Define a quantidade automaticamente baseada no preço por kg e valor pago.
- **Temas:** Suporte a temas Claro, Escuro e Pastel com persistência.
- **Exportação PDF:** Gere relatórios profissionais das suas compras diretamente para o WhatsApp ou e-mail.
