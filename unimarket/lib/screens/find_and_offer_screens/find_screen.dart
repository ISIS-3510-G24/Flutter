import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';
import 'package:unimarket/screens/upload/create_offer_screen.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/user_service.dart';
import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimarket/screens/find_and_offer_screens/offerDetailScreen.dart';
import 'package:unimarket/services/connectivity_service.dart';

class FindsScreen extends StatefulWidget {
  final FindModel find;

  const FindsScreen({
    super.key,
    required this.find,
  });

  @override
  State<FindsScreen> createState() => _FindsScreenState();
}

class _FindsScreenState extends State<FindsScreen> {
  final FindService _findService = FindService();
  final ConnectivityService _connectivityService = ConnectivityService(); // Servicio de conectividad
  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  List<OfferModel> _offers = [];
  bool _isLoading = true;
  bool _isConnected = true; // Estado de conexión
  bool _isCheckingConnectivity = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _loadOffers();
    _loadSavedFilter();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen((bool isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
      if (!_isConnected) {
        print("You are offline. Some features may not work.");
      } else {
        print("You are online.");
      }
    });

    _checkingSubscription = _connectivityService.checkingStream.listen((bool isChecking) {
      setState(() {
        _isCheckingConnectivity = isChecking;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _checkingSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _findService.getOffersForFind(widget.find.id);
      setState(() {
        _offers = offers;
      });
      print("Loaded ${offers.length} offers for find: ${widget.find.id}");

      // Aplicar el filtro después de cargar las ofertas
      await _loadSavedFilter();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading offers: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFilter(String filter) async {
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print("No user is currently logged in.");
      return;
    }

    // Guardar el filtro en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("offer_filter_$userId", filter);

    // Usar un isolate para ordenar las ofertas
    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_filterOffersInIsolate, receivePort.sendPort);

    final SendPort sendPort = await receivePort.first as SendPort;
    final responsePort = ReceivePort();

    // Enviar las ofertas y el filtro al isolate
    sendPort.send([_offers, filter, responsePort.sendPort]);

    // Esperar la respuesta del isolate
    final sortedOffers = await responsePort.first as List<OfferModel>;

    // Actualizar la lista de ofertas en el hilo principal
    setState(() {
      _offers = sortedOffers;
    });

    print("Applied filter for user $userId: $filter");
  }

  Future<void> _loadSavedFilter() async {
    // Obtener el userId del usuario actual
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print("No user is currently logged in.");
      return;
    }

    // Cargar el filtro desde SharedPreferences usando la clave específica del usuario
    final prefs = await SharedPreferences.getInstance();
    final savedFilter = prefs.getString("offer_filter_$userId") ?? "low_to_high"; // Filtro predeterminado
    print("Loaded saved filter for user $userId: $savedFilter");

    // Aplicar el filtro guardado
    _applyFilter(savedFilter);
  }

  Future<String?> _getCurrentUserId() async {
    // Aquí puedes usar un servicio como UserService para obtener el userId
    final user = await UserService().getCurrentUserProfile();
    return user?.id;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.find.title,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        previousPageTitle: "Find & Offer",
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildConnectivityBanner(), // Mostrar el banner de conectividad
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMainImage(),
                          _buildFindDetails(),
                          _offers.isEmpty
                              ? _buildNoOffersWidget()
                              : _buildOffersList(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainImage() {
  return Container(
    height: 200,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.lightGreyBackground,
    ),
    child: widget.find.image.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: widget.find.image, // URL de la imagen
            placeholder: (context, url) => const Center(
              child: CupertinoActivityIndicator(),
            ), // Indicador de carga
            errorWidget: (context, url, error) => const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 50,
                color: CupertinoColors.systemGrey,
              ),
            ), // Icono en caso de error
            fit: BoxFit.cover,
          )
        : const Center(
            child: Icon(
              CupertinoIcons.photo,
              size: 50,
              color: CupertinoColors.systemGrey,
            ),
          ),
  );
}
  Widget _buildFindDetails() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            widget.find.title,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Descripción
          Text(
            widget.find.description,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Etiquetas (labels)
          Wrap(
            spacing: 8,
            children: widget.find.labels.map((label) => _buildLabel(label)).toList(),
          ),
          
          const SizedBox(height: 12),
          
          // Información del usuario
          Row(
            children: [
              const Icon(
                CupertinoIcons.person_circle_fill,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                widget.find.userName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.hand_thumbsup,
                      color: AppColors.primaryBlue,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${widget.find.upvoteCount}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.tag,
                      color: AppColors.primaryBlue,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${widget.find.offerCount}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildNoOffersWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.info_circle,
            color: AppColors.primaryBlue,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            "There are no offers yet",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.darkBackgroundGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to make an offer for this product, what are you waiting for?",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(20),
            onPressed: () {
              // Navegar a la pantalla de crear oferta
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (ctx) => CreateOfferScreen(findId: widget.find.id),
                ),
              );
            },
            child: Text(
              "Make an offer",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOfferToLocalStorage(OfferModel offer) async {
  final prefs = await SharedPreferences.getInstance();
  final offerData = {
    "id": offer.id,
    "price": offer.price,
    "description": offer.description,
    "image": offer.image,
    "userName": offer.userName,
    "timestamp": offer.timestamp.toIso8601String(),
    "status": offer.status,
    "userId": offer.userId,
  };
  await prefs.setString("selected_offer", jsonEncode(offerData)); // Usar jsonEncode
  print("Saved offer to SharedPreferences: ${jsonEncode(offerData)}");
}

Future<OfferModel?> _getOfferFromLocalStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final offerDataString = prefs.getString("selected_offer");
  if (offerDataString == null) return null;

  final offerData = jsonDecode(offerDataString); // Decodificar JSON
  print("Retrieved offer from SharedPreferences: $offerData");
  return OfferModel(
    id: offerData["id"],
    price: offerData["price"],
    description: offerData["description"],
    image: offerData["image"],
    userName: offerData["userName"],
    timestamp: DateTime.parse(offerData["timestamp"]),
    status: offerData["status"],
    userId: offerData["userId"],
  );
}

  Widget _buildOffersList() {
  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _offers.length,
    itemBuilder: (context, index) {
      final offer = _offers[index];
      return GestureDetector(
        onTap: () async {
          if (_isConnected) {
            // Guardar los detalles de la oferta en el almacenamiento local
            await _saveOfferToLocalStorage(offer);

            // Navegar a la pantalla de detalles de la oferta
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => OfferDetailsScreen(offer: offer),
              ),
            );
          } else {
            // Recuperar los detalles de la oferta desde el almacenamiento local
            final cachedOffer = await _getOfferFromLocalStorage();
            if (cachedOffer != null) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => OfferDetailsScreen(offer: cachedOffer),
                ),
              );
            } else {
              // Mostrar un mensaje de error si no hay datos en caché
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text("No Internet Connection"),
                  content: const Text("Unable to load offer details offline."),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text("OK"),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen de la oferta (si existe)
              if (offer.image.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: offer.image,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Precio de la oferta
                    Text(
                      "\$${offer.price.toStringAsFixed(2)}",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Descripción de la oferta
                    Text(
                      offer.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Helper para formatear fecha
String _formatDate(DateTime date) {
  return "${date.day}/${date.month}/${date.year}";
}

// Mostrar diálogo de contacto
void _showContactDialog(OfferModel offer) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text("Contact the seller"),
      content: Text(
        "Do you want to contact ${offer.userName} about their \$${offer.price.toStringAsFixed(2)} offer?",
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text("Cancelar"),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text("Contactar"),
          onPressed: () {
            Navigator.pop(context);
            // Aquí iría la lógica para contactar al vendedor
            // (por ejemplo, abrir chat, enviar mensaje, etc.)
          },
        ),
      ],
    ),
  );
}

// Mostrar diálogo de filtro
void _showFilterDialog() {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: const Text("Sort Offers"),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            _applyFilter("high_to_low");
            Navigator.pop(context);
          },
          child: const Text("Price: High to Low"),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            _applyFilter("low_to_high");
            Navigator.pop(context);
          },
          child: const Text("Price: Low to High"),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text("Cancel"),
      ),
    ),
  );
}

Widget _buildConnectivityBanner() {
  if (!_isConnected || _isCheckingConnectivity) {
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemYellow.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          _isCheckingConnectivity
              ? const CupertinoActivityIndicator(radius: 8)
              : const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 16,
                  color: CupertinoColors.systemYellow,
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isCheckingConnectivity
                  ? "Checking internet connection..."
                  : "You are offline. Some features may not work.",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
  return const SizedBox.shrink();
}
}

void _filterOffersInIsolate(SendPort sendPort) {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  port.listen((message) {
    final List<OfferModel> offers = message[0];
    final String filter = message[1];
    final SendPort replyPort = message[2];

    // Aplicar el filtro
    if (filter == "high_to_low") {
      offers.sort((a, b) => b.price.compareTo(a.price));
    } else if (filter == "low_to_high") {
      offers.sort((a, b) => a.price.compareTo(b.price));
    }

    // Enviar la lista ordenada de vuelta al hilo principal
    replyPort.send(offers);
  });
}