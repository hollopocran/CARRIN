import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/item_provider.dart';

class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator> with SingleTickerProviderStateMixin {
  AnimationController? _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _rotationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ItemProvider>(context);
    final count = provider.pendingSyncCount;
    final isProcessing = provider.isProcessingQueue;
    final isOfflineUser = provider.isActiveUserOffline;

    if (isProcessing && !isOfflineUser) {
      _rotationController?.repeat();
    } else {
      _rotationController?.stop();
    }

    Color iconColor;
    IconData iconData;
    String tooltip;

    if (isOfflineUser) {
      iconColor = Colors.grey;
      iconData = Icons.cloud_off_rounded;
      tooltip = 'Modo Offline (Sem sincronização na nuvem)';
    } else if (isProcessing) {
      iconColor = Colors.blueAccent;
      iconData = Icons.sync_rounded;
      tooltip = 'Sincronizando com a nuvem...';
    } else if (provider.lastSyncError != null) {
      iconColor = Colors.redAccent;
      iconData = Icons.sync_problem_rounded;
      tooltip = 'Erro de sincronização (Toque para ver)';
    } else if (count > 0) {
      iconColor = Colors.orangeAccent;
      iconData = Icons.cloud_queue_rounded;
      tooltip = '$count alterações pendentes offline';
    } else {
      iconColor = Colors.green;
      iconData = Icons.cloud_done_rounded;
      tooltip = 'Sincronizado com a nuvem';
    }

    return IconButton(
      icon: Stack(
        alignment: Alignment.center,
        children: [
          isProcessing && !isOfflineUser
              ? RotationTransition(
                  turns: _rotationController!,
                  child: Icon(iconData, color: iconColor),
                )
              : Icon(iconData, color: iconColor),
          if (!isOfflineUser && !isProcessing && count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      tooltip: tooltip,
      onPressed: () => _showSyncDetails(context, provider),
    );
  }

  void _showSyncDetails(BuildContext context, ItemProvider provider) {
    provider.purgeObsoleteSyncOperations();
    final count = provider.pendingSyncCount;
    final isProcessing = provider.isProcessingQueue;
    final isOfflineUser = provider.isActiveUserOffline;
    final syncError = provider.lastSyncError;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(
              isOfflineUser 
                  ? Icons.cloud_off_rounded 
                  : (syncError != null ? Icons.sync_problem_rounded : Icons.cloud_sync_outlined), 
              size: 28,
              color: isOfflineUser ? Colors.grey : (syncError != null ? Colors.redAccent : null),
            ),
            const SizedBox(width: 12),
            Text(syncError != null ? 'Erro de Sync' : 'Sincronização', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOfflineUser)
              const Text('Você está usando o aplicativo em Modo Offline. Suas listas e alterações são salvas exclusivamente no seu dispositivo, e não são sincronizadas com a nuvem.')
            else if (isProcessing)
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Expanded(child: Text('Enviando alterações pendentes para o Google Sheets...')),
                ],
              )
            else if (syncError != null) ...[
              Text(
                'Ocorreu uma falha ao comunicar com o Google Sheets:\n\n$syncError\n\nSuas alterações continuam salvas em segurança no dispositivo.',
                style: const TextStyle(fontSize: 13),
              ),
            ] else if (count > 0)
              Text('Você tem $count alterações salvas localmente e aguardando conexão para sincronizar com o Google Sheets.')
            else
              const Text('Todos os dados estão devidamente sincronizados e salvos na nuvem (Google Sheets).'),
          ],
        ),
        actions: [
          if (!isOfflineUser && !isProcessing && (count > 0 || syncError != null))
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.clearSyncQueue();
              },
              child: const Text('Limpar Fila', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.grey)),
          ),
          if (!isOfflineUser && !isProcessing && (count > 0 || syncError != null))
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.processSyncQueue();
              },
              child: const Text('Tentar Novamente', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
