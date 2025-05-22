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
  // REUSABLE BANNER
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
        middle: Text('Products in Queue',
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
                  // Use the snapshot and count only queued/failed
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
                              'You are connected. Sync $pending pending product${pending == 1 ? '' : 's'}?',
                          button: 'Sync',
                          onTap: _product.processQueue,
                        );
                }

                if (!online) {
                  return _banner(
                    icon: CupertinoIcons.wifi_slash,
                    color: CupertinoColors.systemYellow,
                    text:
                        'You are offline. Products will upload when connection returns.',
                    button: 'Check',
                    onTap: _net.checkConnectivity,
                  );
                }

                // checking connection
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  color: CupertinoColors.systemGrey.withOpacity(.1),
                  child: Row(children: [
                    const CupertinoActivityIndicator(radius: 8),
                    const SizedBox(width: 8),
                    Text('Checking connection…',
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
                final rawList = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (rawList.isEmpty) return const _EmptyState();

                // Sort products by priority: uploading -> queued -> failed -> completed
                final list = [...rawList];
                list.sort((a, b) {
                  final statusPriority = {
                    'uploading': 0,
                    'queued': 1, 
                    'failed': 2,
                    'completed': 3,
                  };
                  final priorityA = statusPriority[a.status] ?? 4;
                  final priorityB = statusPriority[b.status] ?? 4;
                  
                  if (priorityA != priorityB) {
                    return priorityA.compareTo(priorityB);
                  }
                  // Same status, sort by time (newest first)
                  return b.queuedTime.compareTo(a.queuedTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Dismissible(
                    key: Key(list[i].queueId),
                    direction: list[i].status == 'completed' 
                        ? DismissDirection.endToStart 
                        : DismissDirection.endToStart,
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
                          title: Text(list[i].status == 'completed' ? 'Remove from history?' : 'Delete product?'),
                          content: Text(list[i].status == 'completed' 
                              ? 'Remove "${list[i].product.title}" from upload history?'
                              : 'Are you sure you want to delete "${list[i].product.title}" from the queue?'),
                          actions: [
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(list[i].status == 'completed' ? 'Remove' : 'Delete'),
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
    Color? backgroundColor;

    switch (qp.status) {
      case 'queued':
        color = CupertinoColors.systemOrange;
        icon = CupertinoIcons.clock;
        label = 'Queued';
        break;
      case 'uploading':
        color = AppColors.primaryBlue;
        icon = CupertinoIcons.arrow_up_circle_fill;
        label = 'Uploading';
        backgroundColor = AppColors.primaryBlue.withOpacity(0.05);
        trailingWidget = const CupertinoActivityIndicator(radius: 8);
        break;
      case 'failed':
        color = CupertinoColors.systemRed;
        icon = CupertinoIcons.exclamationmark_circle_fill;
        label = 'Failed';
        backgroundColor = CupertinoColors.systemRed.withOpacity(0.05);
        break;
      case 'completed':
        color = CupertinoColors.systemGreen;
        icon = CupertinoIcons.checkmark_circle_fill;
        label = 'Uploaded';
        backgroundColor = CupertinoColors.systemGreen.withOpacity(0.05);
        break;
      default:
        color = CupertinoColors.systemGrey;
        icon = CupertinoIcons.question_circle;
        label = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: qp.status == 'uploading' 
            ? Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey4.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2)
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with better spacing
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color.withOpacity(.2), width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (qp.statusMessage != null && qp.statusMessage!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            qp.statusMessage!,
                            style: GoogleFonts.inter(
                              color: color.withOpacity(0.8),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailingWidget != null)
                  trailingWidget
                else
                  Text(
                    _ago(qp.queuedTime),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Body with better layout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(qp),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qp.product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\${qp.product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        qp.product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message with better styling
          if (qp.status == 'failed' && qp.errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemRed.withOpacity(.2), width: 0.5),
              ),
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
                      qp.errorMessage!,
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

          // Action buttons
          if (qp.status == 'failed' || qp.status == 'queued')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        color: CupertinoColors.systemRed,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (qp.status == 'failed')
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      minSize: 0,
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () async {
                        if (await _checkInternetAccess()) {
                          await _product.retryQueuedUpload(qp.queueId);
                        } else {
                          _showNoInternetDialog();
                        }
                      },
                      child: Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
    // For completed products, prioritize uploaded URLs
    if (qp.status == 'completed' && qp.product.imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          qp.product.imageUrls.first,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _tryLocalImage(qp);
          },
        ),
      );
    }
    
    // For pending/uploading products, try local images first
    if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(qp.product.pendingImagePaths!.first),
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _tryNetworkImage(qp);
          },
        ),
      );
    }
    
    // Fallback to network images
    return _tryNetworkImage(qp);
  }

  Widget _tryLocalImage(QueuedProductModel qp) {
    if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(qp.product.pendingImagePaths!.first),
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _placeholder();
          },
        ),
      );
    }
    return _placeholder();
  }

  Widget _tryNetworkImage(QueuedProductModel qp) {
    if (qp.product.imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          qp.product.imageUrls.first,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _placeholder();
          },
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(10),
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
    if (d.inDays > 0) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    if (d.inHours > 0)
      return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    if (d.inMinutes > 0)
      return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
    return 'just now';
  }

  // confirmation
  void _confirmRemove(QueuedProductModel qp) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete product?'),
        content: Text('Delete "${qp.product.title}" from queue?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _product.removeFromQueue(qp.queueId);
            },
            child: const Text('Delete'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInternetAccess() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void _showNoInternetDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('No Internet Connection'),
        content: const Text('Please check your internet connection and try again.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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