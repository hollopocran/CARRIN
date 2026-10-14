import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/item_provider.dart';
import '../services/auth_service.dart';
import '../widgets/supermarket_avatar.dart';
import 'splash_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<List<Map<String, String>>> _getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accountsJson = prefs.getString('saved_google_accounts');
    if (accountsJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      return decoded.map((e) {
        final map = Map<String, dynamic>.from(e);
        return {
          'email': map['email']?.toString() ?? '',
          'displayName': map['displayName']?.toString() ?? '',
          'photoUrl': map['photoUrl']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Erro ao decodificar contas salvas: $e');
      return [];
    }
  }

  Future<void> _connectAccount(BuildContext context, ItemProvider itemProvider, String email) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await AuthService().signIn();
      
      if (context.mounted) {
        Navigator.pop(context); // Remove CircularProgressIndicator
        
        if (success) {
          final newEmail = AuthService().currentUser?.email;
          if (newEmail != null) {
            await itemProvider.switchActiveUserEmail(newEmail);
            
            if (!context.mounted) return;
            if (newEmail.toLowerCase() != email.toLowerCase()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Conectado como $newEmail (diferente da conta anterior).'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conta sincronizada com a nuvem com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login cancelado ou não concluído.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove CircularProgressIndicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar conta: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _addNewAccount(BuildContext context, ItemProvider itemProvider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await AuthService().signIn();
      
      if (context.mounted) {
        Navigator.pop(context); // Remove CircularProgressIndicator
        
        if (success) {
          final newEmail = AuthService().currentUser?.email;
          if (newEmail != null) {
            await itemProvider.switchActiveUserEmail(newEmail);
          }
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta adicionada e sincronizada com sucesso!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove CircularProgressIndicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar conta: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showAddAccountOptions(BuildContext context, ItemProvider itemProvider) {
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Adicionar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.cloud_upload_outlined, color: Theme.of(context).primaryColor),
              title: const Text('Conectar Conta Google', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Sincroniza suas listas na nuvem automaticamente'),
              onTap: () {
                Navigator.pop(context);
                _addNewAccount(context, itemProvider);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_off, color: Colors.grey),
              title: const Text('Criar Perfil Offline', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Dados salvos apenas no seu celular'),
              onTap: () {
                Navigator.pop(context);
                _showCreateOfflineProfileDialog(context, itemProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOfflineProfileDialog(BuildContext context, ItemProvider itemProvider) {
    final TextEditingController nameController = TextEditingController();
    String selectedAvatarId = 'supermarket_cart_ocean';
    
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Novo Perfil Offline', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Perfil',
                  hintText: 'Perfil Offline',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              SupermarketAvatarSelector(
                selectedId: selectedAvatarId,
                onSelected: (avatarId) {
                  selectedAvatarId = avatarId;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim().isEmpty 
                  ? 'Perfil Offline' 
                  : nameController.text.trim();
              
              Navigator.pop(context);
              
              final safeId = DateTime.now().millisecondsSinceEpoch.toString();
              final email = 'offline_$safeId@offline';
              
              await itemProvider.createOfflineProfile(email, name, selectedAvatarId);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Perfil "$name" criado com sucesso!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  void _showEditOfflineProfileDialog(BuildContext context, ItemProvider itemProvider, String email, String currentName, String currentAvatarId) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    String selectedAvatarId = currentAvatarId;
    
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Editar Perfil Offline', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Perfil',
                  hintText: 'Perfil Offline',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              SupermarketAvatarSelector(
                selectedId: selectedAvatarId,
                onSelected: (avatarId) {
                  selectedAvatarId = avatarId;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim().isEmpty 
                  ? 'Perfil Offline' 
                  : nameController.text.trim();
              
              Navigator.pop(context);
              
              await itemProvider.updateOfflineProfile(email, name, selectedAvatarId);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Perfil "$name" atualizado com sucesso!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmDialog(BuildContext context, ItemProvider itemProvider, String email, String name) {
    final displayName = name.isNotEmpty ? name : email;
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Excluir Conta Local?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Isso apagará permanentemente o banco de dados local e todos os dados salvos para $displayName no seu dispositivo. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close confirm dialog
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              
              // Garante que o diálogo de carregamento terminou de ser empilhado no Navigator
              await Future.delayed(const Duration(milliseconds: 150));
              
              try {
                final bool isActive = email.trim().toLowerCase() == itemProvider.activeUserEmail?.trim().toLowerCase();
                await itemProvider.removeSavedAccount(email);
                
                // Remove o loading usando o navigator previamente obtido
                navigator.pop(); 
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dados locais de $displayName excluídos.'), backgroundColor: Colors.green),
                  );
                  
                  if (isActive) {
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const SplashScreen()),
                      (route) => false,
                    );
                  }
                }
              } catch (e) {
                // Tenta fechar o loading em caso de erro
                try {
                  navigator.pop();
                } catch (_) {}
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    _showAnimatedDialog(
      context,
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Sair de Todas as Contas?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Isso removerá todas as contas salvas localmente (perfis offline e contas do Google) e limpará seus respectivos bancos de dados locais. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close dialog
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              // Garante que o diálogo de carregamento terminou de ser empilhado no Navigator
              await Future.delayed(const Duration(milliseconds: 150));

              try {
                final itemProvider = context.read<ItemProvider>();
                await itemProvider.removeAllSavedAccounts();
                
                // Remove o loading
                navigator.pop();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Todas as contas foram removidas com sucesso.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SplashScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                // Tenta fechar o loading em caso de erro
                try {
                  navigator.pop();
                } catch (_) {}
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao sair das contas: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sair de Todas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAnimatedDialog(BuildContext context, Widget dialog) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => dialog,
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemProvider = Provider.of<ItemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Contas', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _getSavedAccounts(),
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? [];
          final activeEmail = itemProvider.activeUserEmail ?? '';
          final googleUser = AuthService().currentUser;
          final googleEmail = googleUser?.email ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONTAS SALVAS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                if (accounts.isEmpty)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma conta cadastrada. Conecte uma conta Google ou crie um perfil offline.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ),
                if (accounts.isNotEmpty)
                  Expanded(
                    child: ListView.separated(
                      itemCount: accounts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final acc = accounts[index];
                        final email = acc['email'] ?? '';
                        final name = acc['displayName'] ?? '';
                        final photoUrl = acc['photoUrl'] ?? '';
                        
                        final isActive = email.toLowerCase() == activeEmail.toLowerCase();
                        
                        // Se for a conta ativa localmente e o usuário estiver autenticado no Google
                        final bool isSynced = isActive && googleEmail.isNotEmpty && !email.endsWith('@offline');

                        Color syncColor = isDark ? Colors.orangeAccent : Colors.orange[800]!;
                        String syncText = 'Offline local';
                        IconData syncIcon = Icons.cloud_off;

                        if (email.endsWith('@offline')) {
                          syncColor = Colors.grey;
                          syncText = 'Modo Offline';
                          syncIcon = Icons.cloud_off_outlined;
                        } else if (isSynced) {
                          if (itemProvider.isProcessingQueue) {
                            syncColor = Colors.blue;
                            syncText = 'Sincronizando...';
                            syncIcon = Icons.sync;
                          } else if (itemProvider.lastSyncError != null) {
                            syncColor = Colors.redAccent;
                            syncText = 'Erro de Sync';
                            syncIcon = Icons.error_outline;
                          } else if (itemProvider.pendingSyncCount > 0) {
                            syncColor = isDark ? Colors.orangeAccent : Colors.orange[800]!;
                            syncText = 'Pendente (${itemProvider.pendingSyncCount})';
                            syncIcon = Icons.cloud_queue;
                          } else {
                            syncColor = Colors.green;
                            syncText = 'Sincronizado';
                            syncIcon = Icons.cloud_done;
                          }
                        }

                        return Card(
                          elevation: isActive ? 4 : 0,
                          margin: EdgeInsets.zero,
                          color: isActive 
                              ? Color.alphaBlend(
                                  Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.18 : 0.10),
                                  Theme.of(context).cardColor,
                                )
                              : Theme.of(context).cardColor.withValues(alpha: isDark ? 0.5 : 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isActive 
                                  ? Theme.of(context).primaryColor
                                  : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                              width: isActive ? 2.0 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final isEmailOffline = email.endsWith('@offline');
                              if (!isActive) {
                                await itemProvider.switchActiveUserEmail(email);
                                
                                if (!context.mounted) return;
                                
                                if (!isEmailOffline && !itemProvider.isSyncEnabled) {
                                  await _connectAccount(context, itemProvider, email);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEmailOffline 
                                          ? 'Alternado para o perfil offline: $name'
                                          : 'Alternado para a conta: $email (Sincronizada)'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                if (!isEmailOffline) {
                                  if (!isSynced) {
                                    await _connectAccount(context, itemProvider, email);
                                  } else if (itemProvider.lastSyncError != null || itemProvider.hasPendingSync) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(child: CircularProgressIndicator()),
                                    );
                                    try {
                                      await itemProvider.processSyncQueue();
                                    } finally {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  }
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isActive 
                                            ? Theme.of(context).primaryColor 
                                            : Colors.transparent,
                                        width: 2.0,
                                      ),
                                    ),
                                    padding: EdgeInsets.all(isActive ? 2.0 : 0.0),
                                    child: SupermarketAvatarWidget(
                                      photoUrl: photoUrl,
                                      displayName: name,
                                      radius: 20,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name.isNotEmpty ? name : email.split('@').first,
                                                style: TextStyle(
                                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isActive 
                                                      ? (isDark ? Colors.white : Theme.of(context).primaryColor)
                                                      : (isDark ? Colors.white70 : Colors.black87),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (!email.endsWith('@offline')) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark 
                                                  ? (isActive ? Colors.white60 : Colors.white38) 
                                                  : (isActive ? Colors.black54 : Colors.black38),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (email.endsWith('@offline')) ...[
                                    if (isActive) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: isDark ? 0.15 : 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.cloud_off_outlined,
                                              size: 11,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Modo Offline',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    IconButton(
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        size: 22,
                                      ),
                                      tooltip: 'Editar nome e avatar',
                                      onPressed: () => _showEditOfflineProfileDialog(context, itemProvider, email, name, photoUrl),
                                    ),
                                  ],
                                  if (!email.endsWith('@offline') && isActive) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: syncColor.withValues(alpha: isDark ? 0.15 : 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: syncColor.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            syncIcon,
                                            size: 11,
                                            color: syncColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            syncText,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: syncColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  IconButton(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                    tooltip: 'Remover conta e apagar dados locais',
                                    onPressed: () => _showDeleteAccountConfirmDialog(context, itemProvider, email, name),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (accounts.isNotEmpty) const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddAccountOptions(context, itemProvider),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Alternar / Adicionar Contas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                        label: const Text('Sair de todas', style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
