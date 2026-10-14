import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos & Privacidade', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Icon(Icons.privacy_tip_rounded, size: 50, color: primaryColor),
                const SizedBox(height: 14),
                const Text(
                  'Compromisso com a LGPD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este documento detalha como o CARRIN protege e gerencia as suas informações, em total conformidade com a Lei Geral de Proteção de Dados (Lei nº 13.709/18).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Topic 1
          _buildTermCard(
            title: '1. Ausência de Servidores Externos',
            icon: Icons.dns_outlined,
            color: Colors.blueAccent,
            isDarkMode: isDarkMode,
            content: 'O CARRIN não possui servidores próprios de armazenamento. Isso significa que o desenvolvedor do aplicativo não tem acesso, não coleta, não armazena e não comercializa nenhum dos seus dados pessoais ou listas de compras. Suas informações pertencem exclusivamente a você.',
          ),
          const SizedBox(height: 16),

          // Topic 2
          _buildTermCard(
            title: '2. Armazenamento Local Seguro',
            icon: Icons.phone_android_rounded,
            color: Colors.teal,
            isDarkMode: isDarkMode,
            content: 'Todos os produtos, preços, quantidades e históricos de compras são salvos localmente em um banco de dados SQLite interno no seu dispositivo. Esses dados estão sujeitos às regras de segurança do sistema operacional do seu celular.',
          ),
          const SizedBox(height: 16),

          // Topic 3
          _buildTermCard(
            title: '3. Sincronização em Nuvem Privada',
            icon: Icons.cloud_done_outlined,
            color: Colors.green,
            isDarkMode: isDarkMode,
            content: 'No modo Online, a sincronização ocorre diretamente entre o seu celular e o seu Google Drive pessoal por meio de planilhas. O aplicativo utiliza o escopo de segurança "drive.file", limitando o acesso apenas aos arquivos criados pelo próprio aplicativo ("CARRIN_Lista_Compras"). Ninguém mais tem acesso aos seus dados de nuvem.',
          ),
          const SizedBox(height: 16),

          // Topic 4
          _buildTermCard(
            title: '4. Direitos do Titular (Seu Controle)',
            icon: Icons.settings_accessibility_rounded,
            color: Colors.orangeAccent,
            isDarkMode: isDarkMode,
            content: 'Em conformidade com a LGPD, você possui total autonomia sobre seus dados:\n'
                '• Para excluir dados locais: vá em Configurações > Limpar Cache, ou remova sua conta no menu Gerenciar Contas.\n'
                '• Para excluir dados da nuvem: você pode simplesmente apagar a planilha criada pelo aplicativo diretamente no seu Google Drive.',
          ),
          const SizedBox(height: 16),

          // Topic 5
          _buildTermCard(
            title: '5. Alterações nos Termos',
            icon: Icons.update_rounded,
            color: Colors.blueGrey,
            isDarkMode: isDarkMode,
            content: 'Como o aplicativo é projetado para operar com privacidade total ("privacy-first"), quaisquer futuras alterações nestes termos serão comunicadas de forma transparente dentro do aplicativo para renovação do seu consentimento.',
          ),
          const SizedBox(height: 32),

          // Footer info
          Center(
            child: Text(
              'CARRIN • Sua lista, sem complicação.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Última atualização: Maio de 2026',
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode ? Colors.white30 : Colors.black38,
              ),
            ),
          ),
          const SizedBox(height: 24),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
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
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
