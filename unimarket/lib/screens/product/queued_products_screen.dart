import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class QueuedProductsScreen extends StatefulWidget {
  const QueuedProductsScreen({Key? key}) : super(key: key);

  @override
  State<QueuedProductsScreen> createState() => _QueuedProductsScreenState();
}

class _QueuedProductsScreenState extends State<QueuedProductsScreen> {
  final ProductService      _product = ProductService();
  final ConnectivityService _net     = ConnectivityService();

  //───────────────────────────────────────────────────────────────────────────
  // BANNER REUTILIZABLE
  //───────────────────────────────────────────────────────────────────────────
  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
    required String button,
    required VoidCallback onTap,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: color.withOpacity(.1),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(fontSize: 14, color: color)),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onTap,
            child: Text(button,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, color: color)),
          )
        ]),
      );

  //───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Productos en Cola',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        trailing: StreamBuilder<bool>(
          stream: _net.connectivityStream,
          initialData: _net.hasInternetAccess,
          builder: (_, snap) {
            final ok = snap.data ?? false;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ok ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
                  size: 18,
                  color: ok
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed),
              const SizedBox(width: 6),
              Text(ok ? 'Online' : 'Offline',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: ok
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.systemRed)),
            ]);
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            //──────────────────  BANNER ONLINE/OFFLINE  ──────────────────
            StreamBuilder<bool>(
              stream: _net.connectivityStream,
              initialData: _net.hasInternetAccess,
              builder: (_, s) {
                final online = s.data ?? false;

                if (online && !_net.isChecking) {
                  final pending = _product.queuedProductsSnapshot
                      .where((p) =>
                          p.status == 'queued' || p.status == 'failed')
                      .length;
                  return pending == 0
                      ? const SizedBox.shrink()
                      : _banner(
                          icon: CupertinoIcons.arrow_up_circle,
                          color: AppColors.primaryBlue,
                          text:
                              'Estás conectado. ¿Sincronizar $pending producto${pending == 1 ? '' : 's'} pendientes?',
                          button: 'Sincronizar',
                          onTap: _product.processQueue,
                        );
                }

                if (!online) {
                  return _banner(
                    icon: CupertinoIcons.wifi_slash,
                    color: CupertinoColors.systemYellow,
                    text:
                        'Estás offline. Los productos se subirán cuando vuelva la conexión.',
                    button: 'Verificar',
                    onTap: _net.checkConnectivity,
                  );
                }

                // verificando conexión
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  color: CupertinoColors.systemGrey.withOpacity(.1),
                  child: Row(children: [
                    const CupertinoActivityIndicator(radius: 8),
                    const SizedBox(width: 8),
                    Text('Verificando conexión…',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: CupertinoColors.systemGrey))
                  ]),
                );
              },
            ),

            Expanded(
            child: StreamBuilder<List<QueuedProductModel>>(
              stream: _product.queuedProductsStream,
              initialData: _product.queuedProductsSnapshot,
              builder: (_, snap) {
                final list = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (list.isEmpty) return const _EmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Dismissible(
                    key: Key(list[i].queueId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.delete,
                        color: CupertinoColors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Delete product?'),
                          content: Text('Are you sure you want to delete "${list[i].product.title}" from the queue?'),
                          actions: [
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      _product.removeFromQueue(list[i].queueId);
                    },
                    child: _card(list[i]),
                  ),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  //───────────────────────────────────────────────────────────────────────────
  // CARD
  //───────────────────────────────────────────────────────────────────────────
  Widget _card(QueuedProductModel qp) {
    Color color;
    IconData icon;
    String label;
    Widget? trailingWidget;

    switch (qp.status) {
      case 'queued':
        color = CupertinoColors.systemOrange;
        icon = CupertinoIcons.hourglass;
        label = 'In queue';
        break;
      case 'uploading':
        color = AppColors.primaryBlue;
        icon = CupertinoIcons.arrow_up_circle;
        label = 'Uploading';
        trailingWidget = const CupertinoActivityIndicator(radius: 8);
        break;
      case 'failed':
        color = CupertinoColors.systemRed;
        icon = CupertinoIcons.exclamationmark_circle;
        label = 'Failed';
        break;
      case 'completed':
        color = CupertinoColors.systemGreen;
        icon = CupertinoIcons.checkmark_circle;
        label = 'Completed';
        break;
      default:
        color = CupertinoColors.systemGrey;
        icon = CupertinoIcons.question_circle;
        label = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: CupertinoColors.systemGrey4,
            blurRadius: 4,
            offset: Offset(0, 2)
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color.withOpacity(.3), width: 1)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: color,
                      fontWeight: FontWeight.w600
                    ),
                  ),
                ),
                if (trailingWidget != null)
                  trailingWidget
                else
                  Text(
                    _ago(qp.queuedTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(qp),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qp.product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${qp.product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        qp.product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (qp.status == 'failed' && qp.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: CupertinoColors.systemRed.withOpacity(.1),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: CupertinoColors.systemRed,
                    size: 16
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: ${qp.errorMessage}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CupertinoColors.systemRed
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Buttons
          if (qp.status == 'failed' || qp.status == 'queued')
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minSize: 0,
                    onPressed: () => _confirmRemove(qp),
                    child: Text(
                      'Remove',
                      style: GoogleFonts.inter(
                        color: CupertinoColors.systemRed
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (qp.status == 'failed')
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minSize: 0,
                      color: AppColors.primaryBlue,
                      onPressed: () async {
                        if (await _checkInternetAccess()) {
                          await _product.retryQueuedUpload(qp.queueId);
                        }
                      },
                      child: Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          color: CupertinoColors.white
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumb(QueuedProductModel qp) {
    // Primero intentamos con las imágenes locales pendientes
    if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(qp.product.pendingImagePaths!.first),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _placeholder();
          },
        ),
      );
    }
    
    // Si no hay imágenes locales, intentamos con las URLs
    if (qp.product.imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          qp.product.imageUrls.first,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _placeholder();
          },
        ),
      );
    }
    
    // Si no hay imágenes, mostramos un placeholder
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        CupertinoIcons.photo,
        color: CupertinoColors.systemGrey,
        size: 24,
      ),
    );
  }

  // util
  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays > 0) return 'hace ${d.inDays} día${d.inDays == 1 ? '' : 's'}';
    if (d.inHours > 0)
      return 'hace ${d.inHours} hora${d.inHours == 1 ? '' : 's'}';
    if (d.inMinutes > 0)
      return 'hace ${d.inMinutes} minuto${d.inMinutes == 1 ? '' : 's'}';
    return 'justo ahora';
  }

  // confirmación
  void _confirmRemove(QueuedProductModel qp) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('¿Eliminar "${qp.product.title}" de la cola?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _product.removeFromQueue(qp.queueId);
            },
            child: const Text('Eliminar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInternetAccess() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}

//────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
//────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(CupertinoIcons.clock,
              size: 48, color: CupertinoColors.systemGrey),
          const SizedBox(height: 16),
          Text('No products in queue',
              style: GoogleFonts.inter(
                  fontSize: 16, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 8),
          Text('Products saved offline will appear here',
              style: GoogleFonts.inter(
                  fontSize: 14, color: CupertinoColors.systemGrey)),
        ]),
      );
}
