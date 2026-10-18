# Guia de Publicação e Assinatura do Android - CARRIN

Este arquivo contém todas as informações de release, credenciais de assinatura, impressões digitais (fingerprints) e configurações das APIs do Google para o aplicativo.

---

## 1. Identificação do Aplicativo
* **Nome do App**: CARRIN
* **ID do Aplicativo (Package Name)**: `com.wmartins.carrin`

---

## 2. Dados da Keystore (Chave de Assinatura)
O arquivo da keystore está localizado em: `android/app/upload-keystore.jks`

* **Alias**: `upload`
* **Senhas**: Configuradas no arquivo local privado `android/key.properties` (ignorado no git)

> [!IMPORTANT]
> O arquivo binário `upload-keystore.jks` e o arquivo `key.properties` contêm as credenciais privadas locais e estão protegidos pelo `.gitignore`.

---

## 3. Impressões Digitais do Certificado (Fingerprints)
Você precisará destas chaves para configurar a integração do Login do Google e do Google Sheets no console de APIs:

### A. Chave de Release (Para publicar ou testar o APK de Produção)
* **SHA-1 (Chave de Upload)**:
  `2E:D9:D4:36:8F:CA:8B:59:E0:FB:AA:53:0C:0A:9F:C4:6D:61:E3:CA`
* **SHA-256 (Chave de Upload)**:
  `A9:AD:54:E2:14:00:84:81:EC:FE:97:E8:70:E0:22:A4:59:FD:15:51:24:65:E1:F0:86:18:5A:6C:F6:80:86:F4`

### B. Chave de Debug (Para desenvolvimento local via VS Code / Android Studio)
* **SHA-1 (Chave de Debug)**:
  `E3:FD:25:59:19:F0:F2:52:D7:69:E6:23:EE:47:90:D6:39:69:C3:B2`
* **SHA-256 (Chave de Debug)**:
  `45:BB:0E:87:4B:6A:7E:FD:D0:43:F5:66:17:53:DD:D3:ED:C5:D7:04:A8:9A:EF:1D:A5:E4:83:1D:E7:9F:13:28`

---

## 4. Configuração das APIs (Google Cloud Console)
Para manter o Login do Google e o Google Sheets funcionando, certifique-se de ter os seguintes cadastros no [Google Cloud Console](https://console.cloud.google.com/) em **APIs e Serviços** > **Credenciais**:

### ID do Cliente Web (serverClientId usado no código)
* **ID atual em uso no app**: `114329991086-807sk2l4i4u52t4cqsbdg0njniegnef4.apps.googleusercontent.com`
* Este ID é referenciado em `lib/services/auth_service.dart`.

### IDs do Cliente Android (OAuth 2.0)
Você precisa ter **3 cadastros** do tipo Android com o Package Name `com.wmartins.carrin`:

| Finalidade | SHA-1 |
|---|---|
| APK de Release (arquivo compilado) | `2E:D9:D4:36:8F:CA:8B:59:E0:FB:AA:53:0C:0A:9F:C4:6D:61:E3:CA` |
| Debug local (VS Code / Android Studio) | `E3:FD:25:59:19:F0:F2:52:D7:69:E6:23:EE:47:90:D6:39:69:C3:B2` |
| Play Store (Google App Signing) | Copiar do Play Console > Configurações > Assinatura do app |

---

## 5. Passos para Publicar no Google Play Console
1. **Criar o App**: No painel inicial do Play Console, clique em **Criar app**, dê o nome de `CARRIN`, configure como `App` e `Gratuito`.
2. **Fazer o primeiro Upload**: No menu esquerdo, acesse **Testar e lançar** > **Teste interno**, crie uma versão e envie o arquivo `.aab`. Isso registrará o pacote `com.wmartins.carrin` na loja.
3. **Liberar Compartilhamento Interno**: Vá em **Compartilhamento interno de apps** e certifique-se de que seu e-mail de desenvolvedor está adicionado na aba **Uploaders e testadores**.

---

## 6. Comandos de Compilação no Terminal
Sempre que precisar atualizar o aplicativo, execute estes comandos na pasta raiz do projeto:

* **Limpar cache de builds anteriores**:
  ```bash
  flutter clean
  ```
* **Gerar o pacote para a Play Store (AAB)**:
  ```bash
  flutter build appbundle --release
  ```
  *O arquivo gerado fica em:* `build/app/outputs/bundle/release/carrin-release.aab`
* **Gerar o arquivo de instalação direta para testes no celular (APK)**:
  ```bash
  flutter build apk --release
  ```
  *O arquivo gerado fica em:* `build/app/outputs/flutter-apk/app-release.apk`
