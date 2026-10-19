# Guia Definitivo e Checklist de Publicação — CARRIN na Google Play Store

Este documento foi preparado para você ter **tudo pronto** quando for realizar a inscrição e publicação do aplicativo no Google Play Console.

---

## 1. Documentos Necessários para Criar a Conta de Desenvolvedor

A taxa do Google Play Console é de **US$ 25** (pagamento único via cartão de crédito internacional). Para aprovar a conta de desenvolvedor (Pessoa Física), o Google exige a verificação de identidade:

### A. Documento de Identidade Oficial com Foto
* **O que é aceito:** CNH (Carteira Nacional de Habilitação) ou RG / Passaporte válidos.
* **Requisitos:**
  * Nome completo idêntico ao cadastrado no perfil de pagamentos do Google.
  * Todas as 4 bordas do documento visíveis (sem cortes, reflexos de flash ou dedos segurando).
  * Se for CNH Digital, exporte o PDF oficial direto do aplicativo da Carteira Digital de Trânsito.

### B. Comprovante de Residência (O que costuma gerar rejeição se incorreto)
* **O que é aceito:**
  * Conta de serviços públicos (energia, água, gás, internet ou telefone fixo/celular).
  * Extrato bancário de conta corrente ou fatura de cartão de crédito emitido por banco.
* **Critérios rigorosos do Google:**
  * **Em seu nome:** O comprovante **deve estar no mesmo nome** do titular da conta Google. Se a conta de luz estiver em nome de terceiros (pais, cônjuge), utilize uma fatura de banco ou telefone que esteja no seu CPF e nome.
  * **Recente:** Emitido há menos de **60 dias**.
  * **Endereço idêntico:** O endereço digitado no formulário do Google precisa ser idêntico ao do comprovante (incluindo número e complemento).
  * **Formato:** Se tiver o PDF original da fatura/concessionária, envie o próprio arquivo PDF baixado (evite tirar foto da tela do computador).

---

## 2. Textos Prontos para a Ficha da Loja (Copiar e Colar)

### Nome do Aplicativo (Máx 30 caracteres)
```
CARRIN: Lista de Compras
```

### Breve Descrição (Máx 80 caracteres)
```
Lista de compras inteligente com leitor de código de barras e Google Sheets.
```

### Descrição Completa (Formatada para a Play Store)
```text
CARRIN é a maneira mais simples, inteligente e transparente de gerenciar suas compras de supermercado e finanças domésticas.

Diferente de outros aplicativos, o CARRIN foi construído com foco em privacidade total: suas listas e orçamentos podem ser salvos e sincronizados diretamente na sua própria planilha do Google Sheets, sem intermediários.

Principais Recursos:

* SINCRONIZAÇÃO COM GOOGLE SHEETS
Conecte sua conta Google e mantenha suas listas salvas em planilhas do seu próprio Google Drive. Seus dados pertencem exclusivamente a você!

* LEITOR DE CÓDIGO DE BARRAS RÁPIDO
Adicione produtos ao carrinho instantaneamente apontando a câmera do celular para o código de barras (EAN-13 / EAN-8) com integração ao catálogo nacional.

* LEITOR DE CUPOM FISCAL (NFC-e / SEFAZ)
Escaneie o QR Code das suas notas fiscais de supermercado para registrar suas compras automaticamente em poucos segundos.

* RADAR DE PREÇOS E ECONOMIA COLABORATIVA
Consulte o histórico de valores e descubra onde os produtos estão mais baratos na sua região com a ajuda da comunidade.

* MAPA DE SUPERMERCADOS INTERATIVO
Encontre supermercados próximos a você, visualize distâncias e trace rotas com facilidade.

* CONTROLE DE ORÇAMENTO E ESTATÍSTICAS
Acompanhe o valor total em tempo real no carrinho, evite surpresas no caixa e visualize gráficos detalhados dos seus gastos por categoria.

* DIVISÃO DE CONTAS E CALCULADORA EMBUTIDA
Calcule o valor exato por quilo/grama de itens pesáveis e divida o valor total das compras entre amigos ou familiares sem complicação.

* FUNCIONA 100% OFFLINE
Ficou sem sinal dentro do supermercado? Não tem problema: o CARRIN funciona perfeitamente offline e sincroniza tudo assim que você se reconectar à internet.

Baixe agora o CARRIN e transforme sua experiência nas compras do mês!
```

---

## 3. Arquivos Gráficos Prontos (Já Gerados no Projeto)

Os materiais de design estão gerados e prontos na pasta `play_store_assets/`:

1. **Ícone do App (512 x 512 px PNG 32-bit):**
   * Transparente: `play_store_assets/icon_512x512.png`
   * Fundo sólido escuro: `play_store_assets/icon_512x512_solid.png`
2. **Gráfico de Recursos / Banner (1024 x 500 px):**
   * Imagem pronta: `play_store_assets/feature_graphic_1024x500.png`
3. **Capturas de Tela (Screenshots para Celular):**
   * *O que fazer:* Tire de 4 a 6 prints da tela do app em uso no seu aparelho (Dashboard inicial, Lista com produtos e totais, Tela do Leitor de Código de Barras, Mapa de Mercados e Gráficos de Análise).

---

## 4. Política de Privacidade (Obrigatório pela Google Play)

O arquivo [PRIVACY_POLICY.md](file:///C:/Dev/CARRIN/PRIVACY_POLICY.md) já foi redigido com todas as cláusulas necessárias (LGPD, escopo do Google Drive/Sheets, uso local da câmera e localização).

* **Como hospedar o link gratuitamente:**
  * **Opção 1 (GitHub):** Suba o arquivo `PRIVACY_POLICY.md` no seu repositório do GitHub e copie a URL pública.
  * **Opção 2 (Notion / Google Docs):** Cole o texto em uma página pública do Notion ou Google Docs com link público de visualização.
  * Cole essa URL no campo **Política de Privacidade** dentro do Google Play Console.

---

## 5. Respostas para o Formulário de Segurança dos Dados (Data Safety)

Quando o Google Play Console solicitar as informações de segurança:

| Categoria | Dado | Coletado? | Compartilhado? | Finalidade |
|---|---|---|---|---|
| **Localização** | Aproximada e Precisa | Sim (opcional) | Não | Exibir supermercados próximos e rotas no mapa. |
| **Informações Pessoais** | Nome e E-mail | Sim (opcional) | Não | Autenticação via Google Sign-In para integração do Google Sheets. |
| **Fotos e Vídeos** | Câmera | Sim (temporário) | Não | Leitura em tempo real de código de barras e cupom fiscal. Nenhuma imagem é gravada ou enviada a servidores externos. |
| **Criptografia em trânsito** | — | **Sim** | — | Todos os dados trafegam via HTTPS seguro. |
| **Exclusão de conta/dados** | — | **Sim** | — | O usuário pode limpar os dados do app ou revogar o acesso via conta Google. |

---

## 6. Comandos para Gerar a Versão de Envio (AAB)

Quando for subir o aplicativo na loja, basta abrir o terminal do projeto e rodar:

```powershell
flutter clean
flutter build appbundle --release
```

O arquivo para upload estará localizado em:
`build/app/outputs/bundle/release/carrin-release.aab`

---

## 7. Passo Final Importante: Ativar o Google Sign-In na Loja

Após subir o `.aab` pela primeira vez:
1. No Play Console, vá em **Configurações** > **Assinatura do app**.
2. Copie o **SHA-1 do certificado da chave de assinatura do app** gerado pelo Google.
3. No [Google Cloud Console](https://console.cloud.google.com/), em **Credenciais**, crie ou edite o cliente OAuth Android e adicione esse SHA-1 para que o login do Google continue funcionando perfeitamente para os usuários que baixarem da loja.
