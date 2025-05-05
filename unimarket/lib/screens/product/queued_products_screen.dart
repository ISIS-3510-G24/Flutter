import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/offline_queue_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class QueuedProductsScreen extends StatefulWidget {
  const QueuedProductsScreen({Key? key}) : super(key: key);

  @override
  _QueuedProductsScreenState createState() => _QueuedProductsScreenState();
}

class _QueuedProductsScreenState extends State<QueuedProductsScreen> {
  final ProductService _productService = ProductService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Productos en Cola",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: StreamBuilder<bool>(
          stream: _connectivityService.connectivityStream,
          initialData: _connectivityService.hasInternetAccess,
          builder: (context, snapshot) {
            final bool hasInternet = snapshot.data ?? false;
            
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasInternet ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
                  color: hasInternet ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  hasInternet ? "Online" : "Offline",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: hasInternet ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Banner Online/Offline
            StreamBuilder<bool>(
              stream: _connectivityService.connectivityStream,
              initialData: _connectivityService.hasInternetAccess,
              builder: (context, snapshot) {
                final bool hasInternet = snapshot.data ?? false;
                
                return StreamBuilder<bool>(
                  stream: _connectivityService.checkingStream,
                  initialData: _connectivityService.isChecking,
                  builder: (context, checkingSnapshot) {
                    final bool isChecking = checkingSnapshot.data ?? false;
                    
                    if (hasInternet && !isChecking) {
                      // Online - mostrar botón de sincronización
                      return StreamBuilder<List<QueuedProductModel>>(
                        stream: _productService.queuedProductsStream,
                        builder: (context, queueSnapshot) {
                          final queuedProducts = queueSnapshot.data ?? [];
                          final pendingCount = queuedProducts.where((p) => 
                            p.status == 'queued' || p.status == 'failed').length;
                          
                          if (pendingCount == 0) return SizedBox.shrink();
                          
                          return Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_up_circle,
                                  color: AppColors.primaryBlue,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Estás conectado. ¿Sincronizar $pendingCount producto${pendingCount == 1 ? '' : 's'} pendientes?",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                Spacer(),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minSize: 0,
                                  child: Text(
                                    "Sincronizar",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  onPressed: () {
                                    _productService.processQueue();
                                  },
                                ),
                              ],
                            ),
                          );
                        }
                      );
                    } else if (!hasInternet) {
                      // Offline - mostrar advertencia
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        color: CupertinoColors.systemYellow.withOpacity(0.1),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.wifi_slash,
                              color: CupertinoColors.systemYellow,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Estás offline. Los productos se subirán cuando se restablezca la conexión.",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: CupertinoColors.systemYellow,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              child: Text(
                                "Verificar",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.systemYellow,
                                ),
                              ),
                              onPressed: () {
                                _connectivityService.checkConnectivity();
                              },
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Verificando conectividad
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        color: CupertinoColors.systemGrey.withOpacity(0.1),
                        child: Row(
                          children: [
                            CupertinoActivityIndicator(radius: 8),
                            SizedBox(width: 8),
                            Text(
                              "Verificando conexión a internet...",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              },
            ),
            
            // Lista de Productos en Cola
            Expanded(
              child: StreamBuilder<List<QueuedProductModel>>(
                stream: _productService.queuedProductsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CupertinoActivityIndicator());
                  }
                  
                  final queuedProducts = snapshot.data ?? [];
                  
                  if (queuedProducts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_circle,
                            size: 48,
                            color: CupertinoColors.systemGrey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No hay productos en cola",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Los productos guardados offline aparecerán aquí",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: queuedProducts.length,
                    itemBuilder: (context, index) {
                      final queuedProduct = queuedProducts[index];
                      return _buildQueuedProductCard(queuedProduct);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildQueuedProductCard(QueuedProductModel queuedProduct) {
    // Definir colores e iconos basados en el estado
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (queuedProduct.status) {
      case 'queued':
        statusColor = CupertinoColors.systemOrange;
        statusIcon = CupertinoIcons.hourglass;
        statusText = "En Cola";
        break;
      case 'uploading':
        statusColor = AppColors.primaryBlue;
        statusIcon = CupertinoIcons.arrow_up_circle;
        statusText = "Subiendo";
        break;
      case 'failed':
        statusColor = CupertinoColors.systemRed;
        statusIcon = CupertinoIcons.exclamationmark_circle;
        statusText = "Error";
        break;
      case 'completed':
        statusColor = CupertinoColors.systemGreen;
        statusIcon = CupertinoIcons.checkmark_circle;
        statusText = "Completado";
        break;
      default:
        statusColor = CupertinoColors.systemGrey;
        statusIcon = CupertinoIcons.question_circle;
        statusText = "Desconocido";
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey4,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Encabezado de estado
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                SizedBox(width: 8),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Text(
                  _formatTimeAgo(queuedProduct.queuedTime),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          
          // Detalles del producto
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen del producto
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildProductThumbnail(queuedProduct),
                ),
                SizedBox(width: 12),
                // Detalles del producto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        queuedProduct.product.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        "\$${queuedProduct.product.price.toStringAsFixed(2)}",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        queuedProduct.product.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Mensaje de error si falló
          if (queuedProduct.status == 'failed' && queuedProduct.errorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: CupertinoColors.systemRed.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: CupertinoColors.systemRed,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Error: ${queuedProduct.errorMessage}",
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
            ),
          
          // Botones de acción
          if (queuedProduct.status == 'failed' || queuedProduct.status == 'queued')
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón eliminar
                  CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minSize: 0,
                    child: Text(
                      "Eliminar",
                      style: GoogleFonts.inter(
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                    onPressed: () => _showRemoveConfirmation(context, queuedProduct),
                  ),
                  SizedBox(width: 8),
                  // Botón reintentar
                  if (queuedProduct.status == 'failed')
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.primaryBlue,
                      minSize: 0,
                      child: Text(
                        "Reintentar",
                        style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                        ),
                      ),
                      onPressed: () => _productService.retryQueuedUpload(queuedProduct.queueId),
                    ),
                ],
              ),
            ),
          
          // Botón "Subir ahora" cuando se está online
          if (queuedProduct.status == 'queued' && _connectivityService.hasInternetAccess)
            Padding(
              padding: EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  color: AppColors.primaryBlue,
                  child: Text(
                    "Subir Ahora",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    _productService.retryQueuedUpload(queuedProduct.queueId);
                    _productService.processQueue();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildProductThumbnail(QueuedProductModel queuedProduct) {
    // Si el producto tiene URLs de imágenes
    if (queuedProduct.product.imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          queuedProduct.product.imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultImagePlaceholder(),
        ),
      );
    }
    
    // Si el producto tiene imágenes locales pendientes
    if (queuedProduct.product.pendingImagePaths != null && 
        queuedProduct.product.pendingImagePaths!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(queuedProduct.product.pendingImagePaths!.first),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultImagePlaceholder(),
        ),
      );
    }
    
    // Respaldo
    return _buildDefaultImagePlaceholder();
  }
  
  Widget _buildDefaultImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: CupertinoColors.systemGrey3,
          size: 30,
        ),
      ),
    );
  }
  
  void _showRemoveConfirmation(BuildContext context, QueuedProductModel product) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("¿Eliminar producto?"),
        content: Text(
          "¿Estás seguro de querer eliminar \"${product.product.title}\" de la cola? Esta acción no se puede deshacer.",
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text("Eliminar"),
            onPressed: () {
              Navigator.of(context).pop();
              _productService.removeFromQueue(product.queueId);
            },
          ),
          CupertinoDialogAction(
            child: Text("Cancelar"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return "hace ${difference.inDays} día${difference.inDays == 1 ? '' : 's'}";
    } else if (difference.inHours > 0) {
      return "hace ${difference.inHours} hora${difference.inHours == 1 ? '' : 's'}";
    } else if (difference.inMinutes > 0) {
      return "hace ${difference.inMinutes} minuto${difference.inMinutes == 1 ? '' : 's'}";
    } else {
      return "justo ahora";
    }
  }
}