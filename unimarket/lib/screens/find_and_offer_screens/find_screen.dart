import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class FindsScreen extends StatefulWidget {
  final FindModel find;

  const FindsScreen({
    Key? key,
    required this.find,
  }) : super(key: key);

  @override
  State<FindsScreen> createState() => _FindsScreenState();
}

class _FindsScreenState extends State<FindsScreen> {
  final FindService _findService = FindService();
  List<OfferModel> _offers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _findService.getOffersForFind(widget.find.id);
      setState(() {
        _offers = offers;
        _isLoading = false;
      });
      print("Loaded ${offers.length} offers for find: ${widget.find.id}");
    } catch (e) {
      print("Error loading offers: $e");
      setState(() {
        _isLoading = false;
      });
    }
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
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen principal
                    _buildMainImage(),
                    
                    // Detalles del Find
                    _buildFindDetails(),
                    
                    // Sección de Ofertas
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        "Available Offers",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // Lista de ofertas o mensaje de "no hay ofertas"
                    _offers.isEmpty
                        ? _buildNoOffersWidget()
                        : _buildOffersList(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
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
          ? Image.network(
              widget.find.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: 50,
                  color: CupertinoColors.systemGrey,
                ),
              ),
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
                  builder: (ctx) => const ConfirmProductScreen(
                    postType: "offer",
                  ),
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

  Widget _buildOffersList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _offers.length,
      itemBuilder: (context, index) {
        final offer = _offers[index];
        return Container(
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
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Image.network(
                      offer.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ),
                ),
                
              // Detalles de la oferta
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Precio
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "\$${offer.price.toStringAsFixed(2)}",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          offer.status,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: offer.status.toLowerCase() == 'active'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 12),
                    
                    // Información del usuario
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_circle_fill,
                          color: AppColors.primaryBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          offer.userName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(offer.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Botón de contactar
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () {
                          // Acción de contactar
                          _showContactDialog(offer);
                        },
                        child: Text(
                          "Contact",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.white
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
}