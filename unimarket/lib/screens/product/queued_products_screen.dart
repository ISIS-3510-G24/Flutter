import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class QueuedProductsScreen extends StatefulWidget {
  const QueuedProductsScreen({super.key});

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
                  itemBuilder: (_, i) => _card(list[i]),
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
    late Color c;
    late IconData ic;
    late String lbl;
    switch (qp.status) {
      case 'queued':
        c = CupertinoColors.systemOrange;
        ic = CupertinoIcons.hourglass;
        lbl = 'En cola';
        break;
      case 'uploading':
        c = AppColors.primaryBlue;
        ic = CupertinoIcons.arrow_up_circle;
        lbl = 'Subiendo';
        break;
      case 'failed':
        c = CupertinoColors.systemRed;
        ic = CupertinoIcons.exclamationmark_circle;
        lbl = 'Error';
        break;
      case 'completed':
        c = CupertinoColors.systemGreen;
        ic = CupertinoIcons.checkmark_circle;
        lbl = 'Completado';
        break;
      default:
        c = CupertinoColors.systemGrey;
        ic = CupertinoIcons.question_circle;
        lbl = 'Desconocido';
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
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // encabezado
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.withOpacity(.1),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            border:
                Border(bottom: BorderSide(color: c.withOpacity(.3), width: 1)),
          ),
          child: Row(children: [
            Icon(ic, color: c, size: 18),
            const SizedBox(width: 8),
            Text(lbl,
                style:
                    GoogleFonts.inter(color: c, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_ago(qp.queuedTime),
                style: GoogleFonts.inter(
                    fontSize: 12, color: CupertinoColors.systemGrey)),
          ]),
        ),

        // cuerpo
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _thumb(qp),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(qp.product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('\$${qp.product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue)),
                    const SizedBox(height: 4),
                    Text(qp.product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey)),
                  ]),
            )
          ]),
        ),

        // error
        if (qp.status == 'failed' && qp.errorMessage != null)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: CupertinoColors.systemRed.withOpacity(.1),
            child: Row(children: [
              const Icon(CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemRed, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error: ${qp.errorMessage}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: CupertinoColors.systemRed)),
              )
            ]),
          ),

        // botones
        if (qp.status == 'failed' || qp.status == 'queued')
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minSize: 0,
                onPressed: () => _confirmRemove(qp),
                child: Text('Eliminar',
                    style:
                        GoogleFonts.inter(color: CupertinoColors.systemRed)),
              ),
              const SizedBox(width: 8),
              if (qp.status == 'failed')
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  minSize: 0,
                  color: AppColors.primaryBlue,
                  onPressed: () => _product.retryQueuedUpload(qp.queueId),
                  child: Text('Reintentar',
                      style:
                          GoogleFonts.inter(color: CupertinoColors.white)),
                ),
            ]),
          ),

        // subir ahora
        if (qp.status == 'queued' && _net.hasInternetAccess)
          Padding(
            padding:
                const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: AppColors.primaryBlue,
                onPressed: () {
                  _product.retryQueuedUpload(qp.queueId);
                  _product.processQueue();
                },
                child: Text('Subir ahora',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _thumb(QueuedProductModel qp) {
  // Intenta cargar desde URLs remotas primero
  if (qp.product.imageUrls.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        qp.product.imageUrls.first,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('Error cargando imagen remota: $error');
          // Si falla la carga remota, intenta con imágenes locales
          if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
            return _loadLocalImage(qp.product.pendingImagePaths!.first);
          }
          return _ph();
        },
      ),
    );
  }
  
  // Si no hay URLs remotas, intenta con imágenes locales
  if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
    return _loadLocalImage(qp.product.pendingImagePaths!.first);
  }
  
  // Si no hay imágenes, muestra un placeholder
  return _ph();
}

Widget _loadLocalImage(String path) {
  final file = File(path);
  return FutureBuilder<bool>(
    future: file.exists(),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data == true) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _ph(),
          ),
        );
      }
      return _ph();
    },
  );
}

  Widget _ph() => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(CupertinoIcons.photo,
            size: 30, color: CupertinoColors.systemGrey3),
      );

  // util
  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays > 0) return 'hace ${d.inDays} día${d.inDays == 1 ? '' : 's'}';
    if (d.inHours > 0) {
      return 'hace ${d.inHours} hora${d.inHours == 1 ? '' : 's'}';
    }
    if (d.inMinutes > 0) {
      return 'hace ${d.inMinutes} minuto${d.inMinutes == 1 ? '' : 's'}';
    }
    return 'justo ahora';
  }

  // confirmación
  void _confirmRemove(QueuedProductModel qp) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('¿Eliminar “${qp.product.title}” de la cola?'),
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
}

//────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
//────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(CupertinoIcons.checkmark_circle,
              size: 48, color: CupertinoColors.systemGrey),
          const SizedBox(height: 16),
          Text('No hay productos en cola',
              style: GoogleFonts.inter(
                  fontSize: 16, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 8),
          Text('Los productos guardados offline aparecerán aquí',
              style: GoogleFonts.inter(
                  fontSize: 14, color: CupertinoColors.systemGrey)),
        ]),
      );
}
