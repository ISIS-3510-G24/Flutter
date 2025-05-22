import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/theme/app_colors.dart';

// Import the upload progress overlay functions
void showUploadProgress(BuildContext context, {required String message}) {
  showCupertinoDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Container(
      color: CupertinoColors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  CupertinoIcons.cloud_upload_fill,
                  color: AppColors.primaryBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Uploading',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const CupertinoActivityIndicator(
                color: AppColors.primaryBlue,
                radius: 12,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void hideUploadProgress(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

class QueuedProductsScreen extends StatefulWidget {
  const QueuedProductsScreen({Key? key}) : super(key: key);

  @override
  State<QueuedProductsScreen> createState() => _QueuedProductsScreenState();
}

class _QueuedProductsScreenState extends State<QueuedProductsScreen> {
  final ProductService      _product = ProductService();
  final ConnectivityService _net     = ConnectivityService();

  //───────────────────────────────────────────────────────────────────────────
  // CLEAN BANNER
  //───────────────────────────────────────────────────────────────────────────
  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
    required String button,
    required VoidCallback onTap,
  }) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.3), width: 1),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minSize: 0,
            color: color,
            borderRadius: BorderRadius.circular(8),
            onPressed: onTap,
            child: Text(button,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
          )
        ]),
      );

  //───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Upload Queue',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        trailing: StreamBuilder<bool>(
          stream: _net.connectivityStream,
          initialData: _net.hasInternetAccess,
          builder: (_, snap) {
            final ok = snap.data ?? false;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ok ? CupertinoColors.systemGreen.withOpacity(.1) : CupertinoColors.systemRed.withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(ok ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
                    size: 14,
                    color: ok ? CupertinoColors.systemGreen : CupertinoColors.systemRed),
                const SizedBox(width: 4),
                Text(ok ? 'Online' : 'Offline',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ok ? CupertinoColors.systemGreen : CupertinoColors.systemRed)),
              ]),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
          
StreamBuilder<bool>(
  stream: _net.connectivityStream,
  initialData: _net.hasInternetAccess,
  builder: (_, s) {
    final online = s.data ?? false;

    return StreamBuilder<List<QueuedProductModel>>(
      stream: _product.queuedProductsStream,
      initialData: _product.queuedProductsSnapshot,
      builder: (context, queueSnapshot) {
        final queuedProducts = queueSnapshot.data ?? [];
        final pending = queuedProducts
            .where((p) => p.status == 'queued' || p.status == 'failed')
            .length;
        final uploading = queuedProducts
            .where((p) => p.status == 'uploading')
            .length;

        // Show auto-upload in progress
        if (uploading > 0) {
          return _banner(
            icon: CupertinoIcons.cloud_upload,
            color: AppColors.primaryBlue,
            text: 'Auto-uploading $uploading product${uploading == 1 ? '' : 's'}...',
            button: 'View',
            onTap: () {}, // Do nothing, just show status
          );
        }

        // Show manual upload option when online with pending items
        if (online && !_net.isChecking && pending > 0) {
          return _banner(
            icon: CupertinoIcons.cloud_upload,
            color: AppColors.primaryBlue,
            text: '$pending product${pending == 1 ? '' : 's'} ready to upload',
            button: 'Upload Now',
            onTap: () async {
              showUploadProgress(context, message: 'Starting upload...');
              try {
                await _product.processQueue();
                await Future.delayed(const Duration(milliseconds: 500));
              } finally {
                hideUploadProgress(context);
              }
            },
          );
        }

        // Show offline status when there are pending items
        if (!online && pending > 0) {
          return _banner(
            icon: CupertinoIcons.wifi_slash,
            color: CupertinoColors.systemOrange,
            text: '$pending product${pending == 1 ? '' : 's'} waiting for internet. Will upload automatically when connected.',
            button: 'Retry',
            onTap: () => _net.checkConnectivity(),
          );
        }

        // Show checking connection
        if (_net.isChecking) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const CupertinoActivityIndicator(radius: 10),
              const SizedBox(width: 12),
              Text('Checking connection...',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: CupertinoColors.systemGrey))
            ]),
          );
        }

        // No banner needed
        return const SizedBox.shrink();
      },
    );
  },
),

            const SizedBox(height: 8),

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

                  // Sort: uploading -> queued -> failed -> completed (newest first)
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
                    return b.queuedTime.compareTo(a.queuedTime);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildCard(list[i]),
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
  // SIMPLE CLEAN CARD
  //───────────────────────────────────────────────────────────────────────────
  Widget _buildCard(QueuedProductModel qp) {
    return Dismissible(
      key: Key(qp.queueId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.delete, color: CupertinoColors.white, size: 24),
            const SizedBox(height: 4),
            Text('Remove', 
              style: GoogleFonts.inter(color: CupertinoColors.white, fontSize: 12, fontWeight: FontWeight.w600)
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) => _confirmRemove(qp),
      onDismissed: (direction) => _product.removeFromQueue(qp.queueId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with status
            _buildHeader(qp),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildThumbnail(qp),
                  const SizedBox(width: 16),
                  Expanded(child: _buildProductInfo(qp)),
                ],
              ),
            ),
            
            // Actions
            if (qp.status == 'failed') _buildFailedActions(qp),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(QueuedProductModel qp) {
    Color color;
    IconData icon;
    String label;
    Widget? trailing;

    switch (qp.status) {
      case 'queued':
        color = CupertinoColors.systemOrange;
        icon = CupertinoIcons.clock;
        label = 'Queued';
        break;
      case 'uploading':
        color = AppColors.primaryBlue;
        icon = CupertinoIcons.cloud_upload;
        label = 'Uploading';
        trailing = const CupertinoActivityIndicator(radius: 8);
        break;
      case 'failed':
        color = CupertinoColors.systemRed;
        icon = CupertinoIcons.exclamationmark_circle;
        label = 'Failed';
        break;
      case 'completed':
        color = CupertinoColors.systemGreen;
        icon = CupertinoIcons.checkmark_circle;
        label = 'Uploaded';
        break;
      default:
        color = CupertinoColors.systemGrey;
        icon = CupertinoIcons.question_circle;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (qp.statusMessage != null && qp.statusMessage!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                qp.statusMessage!,
                style: GoogleFonts.inter(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          if (trailing != null)
            trailing
          else
            Text(
              _formatTime(qp.queuedTime),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: CupertinoColors.systemGrey2,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(QueuedProductModel qp) {
    Widget imageWidget;

    // Try local images first, then network
    if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
      imageWidget = Image.file(
        File(qp.product.pendingImagePaths!.first),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageFallback(qp),
      );
    } else if (qp.product.imageUrls.isNotEmpty) {
      imageWidget = Image.network(
        qp.product.imageUrls.first,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    } else {
      imageWidget = _buildImagePlaceholder();
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: CupertinoColors.systemGrey6,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildImageFallback(QueuedProductModel qp) {
    if (qp.product.imageUrls.isNotEmpty) {
      return Image.network(
        qp.product.imageUrls.first,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: CupertinoColors.systemGrey6,
      child: const Icon(
        CupertinoIcons.photo,
        color: CupertinoColors.systemGrey3,
        size: 24,
      ),
    );
  }

  Widget _buildProductInfo(QueuedProductModel qp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          qp.product.title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '\$${qp.product.price.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          qp.product.description,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFailedActions(QueuedProductModel qp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (qp.errorMessage != null) ...[
            Row(
              children: [
                const Icon(CupertinoIcons.exclamationmark_triangle, 
                  color: CupertinoColors.systemRed, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    qp.errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.systemRed,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minSize: 0,
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(8),
                onPressed: () async {
                  if (await _checkConnection()) {
                    showUploadProgress(context, message: 'Retrying upload...');
                    try {
                      await _product.retryQueuedUpload(qp.queueId);
                      // Small delay to show the retry started
                      await Future.delayed(const Duration(milliseconds: 800));
                    } catch (e) {
                      // Error will be shown in the queue card
                    } finally {
                      hideUploadProgress(context);
                    }
                  }
                },
                child: Text(
                  'Retry Upload',
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }

  Future<bool> _confirmRemove(QueuedProductModel qp) async {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(qp.status == 'completed' ? 'Remove from history?' : 'Delete from queue?'),
        content: Text(qp.status == 'completed' 
            ? 'Remove "${qp.product.title}" from upload history?'
            : 'Delete "${qp.product.title}" from upload queue?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(qp.status == 'completed' ? 'Remove' : 'Delete'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showNoInternetDialog();
      return false;
    }
    return true;
  }

  void _showNoInternetDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('No Internet'),
        content: const Text('Please check your connection and try again.'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                CupertinoIcons.cloud_upload,
                size: 40,
                color: CupertinoColors.systemGrey3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Upload queue is empty',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Products you save offline will appear here',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}