import 'package:flutter/material.dart';

/// Tela completa e atualizada de Termos de Uso e Política de Privacidade
/// em estrita conformidade com a Lei Geral de Proteção de Dados (LGPD - Lei nº 13.709/2018).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos & Privacidade (LGPD)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.security_rounded, size: 40, color: primaryColor),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Compromisso com a sua Privacidade',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'O CARRIN adota o princípio de Privacidade por Padrão (Privacy by Design). Este documento detalha de forma transparente como seus dados são protegidos em estrita conformidade com a Lei Geral de Proteção de Dados Pessoais (LGPD - Lei Federal nº 13.709/2018).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Revisão Oficial: Outubro de 2026',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tópico 1: Minimização e Ausência de Servidores Centrais
          _buildTermCard(
            title: '1. Princípio da Minimização e Sem Servidores Centrais (Art. 6º, III)',
            icon: Icons.dns_outlined,
            color: Colors.blueAccent,
            isDarkMode: isDarkMode,
            content: 'O CARRIN não opera servidores centrais de armazenamento ou intermediação de listas pessoais. O desenvolvedor do aplicativo não coleta, não monitora, não analisa e não comercializa nenhum dos seus dados pessoais ou financeiros para anunciantes ou terceiros. Suas informações pertencem exclusivamente a você.',
          ),
          const SizedBox(height: 16),

          // Tópico 2: Armazenamento Local Seguro
          _buildTermCard(
            title: '2. Armazenamento Local Seguro (SQLite)',
            icon: Icons.phone_android_rounded,
            color: Colors.teal,
            isDarkMode: isDarkMode,
            content: 'Seus produtos cadastrados, listas de compras, histórico de preços, categorias e orçamentos são armazenados localmente em um banco de dados SQLite seguro no seu dispositivo. Esses dados são resguardados pelo sandbox de isolamento nativo do sistema operacional do seu celular.',
          ),
          const SizedBox(height: 16),

          // Tópico 3: Nuvem Pessoal Privada
          _buildTermCard(
            title: '3. Sincronização em Nuvem Pessoal Privada (Google Sheets)',
            icon: Icons.cloud_done_outlined,
            color: Colors.green,
            isDarkMode: isDarkMode,
            content: 'A sincronização em nuvem é opcional e ocorre diretamente entre o seu dispositivo e a sua própria conta do Google Drive via OAuth 2.0 oficial. O aplicativo solicita apenas o escopo de segurança estrito "drive.file", limitando o acesso única e exclusivamente à planilha criada pelo aplicativo ("CARRIN_Lista_Compras"). Nenhum servidor intermediário recebe suas credenciais.',
          ),
          const SizedBox(height: 16),

          // Tópico 4: Radar de Preços Comunitário e Anonimização
          _buildTermCard(
            title: '4. Radar Comunitário e Anonimização Absoluta (Art. 12)',
            icon: Icons.share_location_rounded,
            color: Colors.purpleAccent,
            isDarkMode: isDarkMode,
            content: 'Ao colaborar com o Radar de Preços Comunitário, apenas cotações puramente impessoais de mercado são transmitidas (nome do item, valor, supermercado e coordenadas públicas da loja). Nomes de usuário, e-mails, fotos ou qualquer identificador pessoal NUNCA são atrelados às cotações públicas da comunidade, garantindo anonimização total nos termos do Artigo 12 da LGPD.',
          ),
          const SizedBox(height: 16),

          // Tópico 5: Câmera, Códigos de Barras e Cupom Fiscal (NFC-e)
          _buildTermCard(
            title: '5. Uso de Câmera, Códigos de Barras e Cupons Fiscais (NFC-e)',
            icon: Icons.camera_alt_outlined,
            color: Colors.indigoAccent,
            isDarkMode: isDarkMode,
            content: 'A permissão de câmera é utilizada unicamente em tempo real no seu celular para leitura ótica de códigos de barras (EAN-13/8) e QR Codes de NFC-e (SEFAZ). Nenhuma fotografia é capturada, armazenada ou transmitida. O leitor de cupom fiscal extrai apenas os itens da compra e descarta sumariamente qualquer dado cadastral do consumidor (como CPF na nota).',
          ),
          const SizedBox(height: 16),

          // Tópico 6: Geolocalização e GPS
          _buildTermCard(
            title: '6. Tratamento de Localização e GPS (Art. 7º, I e IX)',
            icon: Icons.my_location_rounded,
            color: Colors.amber.shade800,
            isDarkMode: isDarkMode,
            content: 'A localização geográfica do seu aparelho é processada localmente para identificar supermercados no seu entorno, ordenar lojas mais próximas e calcular rotas. Seu histórico de deslocamento ou rotinas pessoais nunca são registrados, transmitidos ou vendidos para empresas de publicidade.',
          ),
          const SizedBox(height: 16),

          // Tópico 7: Atualizações Seguras de Software (OTA)
          _buildTermCard(
            title: '7. Atualizações Seguras e Autônomas de Software (OTA)',
            icon: Icons.system_update_rounded,
            color: Colors.cyan.shade700,
            isDarkMode: isDarkMode,
            content: 'O sistema de atualização autônoma realiza consultas criptografadas (HTTPS) aos repositórios oficiais públicos para checagem de versão e download do instalador APK. Não há envio de identificadores exclusivos de hardware (Device ID/IMEI) ou telemetria invasiva de uso.',
          ),
          const SizedBox(height: 16),

          // Tópico 8: Direitos do Titular de Dados
          _buildTermCard(
            title: '8. Direitos do Titular de Dados (Art. 18)',
            icon: Icons.settings_accessibility_rounded,
            color: Colors.orangeAccent,
            isDarkMode: isDarkMode,
            content: 'Em conformidade com a LGPD, você possui controle absoluto e contínuo sobre os seus dados:\n\n'
                '• Acesso e Portabilidade: Exporte relatórios completos em PDF ou compartilhe suas listas via WhatsApp a qualquer momento.\n'
                '• Eliminação Total de Dados Locais: Acesse Ajustes > Limpar Cache para apagar permanentemente todos os registros do seu dispositivo.\n'
                '• Eliminação dos Dados em Nuvem: Exclua a planilha diretamente do seu Google Drive ou encerre a sessão no menu Contas.\n'
                '• Revogação de Acesso: Você pode revogar as permissões do aplicativo a qualquer instante na página de segurança da sua Conta Google.',
          ),
          const SizedBox(height: 16),

          // Tópico 9: Canal de Contato do Encarregado (DPO)
          _buildTermCard(
            title: '9. Encarregado pelo Tratamento de Dados (Art. 41)',
            icon: Icons.support_agent_rounded,
            color: Colors.blueGrey,
            isDarkMode: isDarkMode,
            content: 'Para dirimir dúvidas, solicitar esclarecimentos técnicos ou exercer quaisquer direitos previstos pela LGPD, o canal de suporte com a equipe de desenvolvimento do CARRIN permanece disponível através do repositório oficial no GitHub.',
          ),
          const SizedBox(height: 32),

          // Footer info
          Center(
            child: Text(
              'CARRIN • Sua lista, sem complicação.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Conformidade Integral com a LGPD (Lei nº 13.709/18) • Outubro de 2026',
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildTermCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2030) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
