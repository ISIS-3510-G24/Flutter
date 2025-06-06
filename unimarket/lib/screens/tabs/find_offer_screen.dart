import 'package:unimarket/widgets/dropdowns/custom_dropdown_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';
import 'package:unimarket/screens/find_and_offer_screens/find_screen.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/models/recommendation_model.dart';
import 'package:unimarket/services/recommendation_service.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/screens/upload/create_offer_screen.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/location_preferences/distance_calculation.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:unimarket/services/screen_metrics_service.dart';
import 'package:unimarket/data/hive_find_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FindAndOfferScreen extends StatefulWidget {
  const FindAndOfferScreen({super.key});

  @override
  State<FindAndOfferScreen> createState() => _FindAndOfferScreenState();
}

class _FindAndOfferScreenState extends State<FindAndOfferScreen> {
  StreamSubscription? _connectivitySubscription; // Declare the variable
  final String _selectedCategory = "All requests"; 
  final FindService _findService = FindService();
  List<FindModel> _finds = [];
  List<Map<String, dynamic>> _recommendedFinds = []; // Nueva lista para finds recomendados
  List<FindModel> _majorFinds = []; // Nueva lista para finds por major
  String? _userMajor; // Para almacenar el major del usuario
  bool _isLoading = true;
  bool _isConnected = true; // Variable para verificar la conectividad
  final Connectivity _connectivity = Connectivity();

  final List<Map<String, String>> _wishlistItems = [
    {"title": "Wishlist Item 1", "subtitle": "Description 1"},
    {"title": "Wishlist Item 2", "subtitle": "Description 2"},
  ];
  final List<Map<String, String>> _sellingItems = [
    {"title": "Selling Item 1", "subtitle": "Description 1"},
    {"title": "Selling Item 2", "subtitle": "Description 2"},
  ];
  List<RecommendationModel> _recommendedProducts = []; // Nueva lista para productos recomendados
  List<FindModel> _nearbyFinds = []; // Nueva lista para finds cercanos
  final ScreenMetricsService _metricsService = ScreenMetricsService(); 

  @override
void initState() {
  super.initState();
  _metricsService.recordScreenEntry('find_metrics');
  _setupConnectivityListener();

  // Cargar todos los datos de forma secuencial
  _loadAllData();
}

Future<void> _loadAllData() async {
  setState(() {
    _isLoading = true; // Mostrar indicador de carga
  });

  try {
    // Ejecutar todas las tareas en paralelo
    await Future.wait([
      _loadFindsFromNetworkThenCache(),
      _loadRecommendedFinds(),
      _loadFinds(), // Esto incluye la carga de nearby finds
    ]);

    print("All data loaded successfully.");
  } catch (e) {
    print("Error loading data: $e");
  } finally {
    setState(() {
      _isLoading = false; // Ocultar indicador de carga
    });
  }
}
  @override
  void dispose() {
    _connectivitySubscription?.cancel(); // Cancelar el listener de conectividad
    _metricsService.recordScreenExit('find_metrics');
    super.dispose();
  }


  //CARGA DE FINDS

  Future<void> _loadFindsFromNetworkThenCache() async {
  //setState(() {
    //_isLoading = true; // Mostrar indicador de carga
  //});

  try {
    print("Fetching finds from server...");
    final serverFinds = await _findService.getFind(); // Obtener datos del servidor

    // Guardar los datos más recientes en Hive
    await HiveFindStorage.clearAllFinds(); // Limpiar el cache anterior
    for (final find in serverFinds) {
      await HiveFindStorage.saveFind(find.toMap());
    }

    setState(() {
      _finds = serverFinds; // Actualizar la interfaz con los datos más recientes
    });

    print("Loaded ${serverFinds.length} finds from server.");
  } catch (e) {
    print("Error fetching finds from server: $e");

    // Usar datos en cache como respaldo
    try {
      print("Loading finds from cache...");
      final cachedFinds = await HiveFindStorage.getAllFinds();
      final finds = cachedFinds.values.map((findMap) => FindModel.fromMap(findMap)).toList();

      setState(() {
        _finds = finds; // Mostrar los datos en cache
      });

      print("Loaded ${finds.length} finds from cache.");
    } catch (cacheError) {
      print("Error loading finds from cache: $cacheError");
    }
  } finally {
    setState(() {
      _isLoading = false; // Ocultar indicador de carga
    });
  }
}

Future<void> _loadRecommendedFinds() async {
  final recommendationService = RecommendationService();

  try {
    print("Fetching recommended finds...");
    final recommendedFinds = await recommendationService.getRecommendedFinds();
    setState(() {
      _recommendedFinds = recommendedFinds;
      _isLoading = false; // Cambiar el estado a false después de cargar los datos
    });
  } catch (e) {
    print("Error loading recommended finds: $e");
    setState(() {
      _isLoading = false; // Cambiar el estado a false incluso si ocurre un error
    });
  }
}

Future<void> _loadFinds() async {
  //setState(() {
    //_isLoading = true;
  //});

  try {
    // Cargar todos los Finds
    final finds = await _findService.getFind();

    // Cargar los Finds cercanos
    final nearbyFinds = await getFindsByLocation();

    // Cargamos los finds por major si el usuario tiene un major asignado
      List<FindModel> majorFinds = [];
      if (_userMajor != null && _userMajor!.isNotEmpty) {
        majorFinds = await _findService.getFindsByMajor(_userMajor!);
        print("Loaded ${majorFinds.length} finds from user's major: $_userMajor");
      }

    setState(() {
      _finds = finds; // Todos los Finds
      _nearbyFinds = nearbyFinds; // Finds cercanos
      _majorFinds = majorFinds;
      _isLoading = false;
    });

    print("Loaded ${finds.length} total finds successfully");
    print("Loaded ${nearbyFinds.length} nearby finds successfully");
  } catch (e) {
    print("Error fetching finds: $e");

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Failed to load data. Please try again later."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }
}



  
  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isConnected = results.isNotEmpty && results.any((result) => result != ConnectivityResult.none);
      });
      
    });}

 Future<void> _checkInitialConnectivity() async {
  try {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _isConnected = result != ConnectivityResult.none;
    });
  } catch (e) {
    print("Error checking initial connectivity: $e");
    setState(() {
      _isConnected = false; // Asume que no hay conexión si ocurre un error
    });
  }
}

Future<void> deleteHiveFiles() async {
  try {
    await Hive.deleteBoxFromDisk('pendingFinds');
    await Hive.deleteBoxFromDisk('offline_finds');
    print("Hive: Archivos de Hive eliminados del dispositivo.");
  } catch (e) {
    print("Error al eliminar los archivos de Hive: $e");
  }
}

Future<void> _clearHiveCache() async {
  try {
    // Llama al método que limpia ambas cajas de Hive
    await HiveFindStorage.clearAllFinds();

    print("Hive: Cajas 'pendingFinds' y 'offline_finds' limpiadas.");

    // Limpia las listas en memoria
    setState(() {
      _finds = [];
      _recommendedFinds = [];
      _nearbyFinds = [];
      _majorFinds = [];
      _recommendedProducts = [];
    });

    print("Memoria local limpiada. Listo para guardar nuevos datos.");
  } catch (e) {
    print("Error al limpiar las cajas Hive: $e");
  }
}

@override
Widget build(BuildContext context) {
  print("Rendering screen with ${_finds.length} finds");
  return FutureBuilder<UniversityBuilding?>(
    future: _getNearestBuilding(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CupertinoActivityIndicator());
      }

      if (snapshot.hasError) {
        return Center(
          child: Text(
            "Error loading location",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        );
      }

      final nearestBuilding = snapshot.data;
      final nearestBuildingName = nearestBuilding?.name;

      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            "Find & Offer",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Banner de "Sin conexión a Internet"
                  if (!_isConnected)
                    Container(
                      width: double.infinity,
                      color: CupertinoColors.systemYellow.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 16,
                            color: CupertinoColors.systemYellow,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You are offline. Check your internet connection.",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Contenido principal
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _isLoading
                              ? const Center(child: CupertinoActivityIndicator())
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildTopRow(),

                                      _buildSectionHeader(
                                        title: "All",
                                      ),
                                      _buildMajorHorizontalList(),

                                      _buildSectionHeader(
                                        title: nearestBuildingName != null
                                            ? "Related to your location! ($nearestBuildingName)"
                                            : "Finds Nearby",
                                      ),
                                      _buildNearbyFindsList(),

                                      _buildSectionHeader(
                                        title: "Most popular",
                                      ),
                                      _buildMostPopularList(),

                                      _buildSectionHeader(
                                        title: "Finds According to Your Orders!",
                                      ),
                                      _buildRecommendedFindsList(),
                                    ],
                                  ),
                                ),
                        ),
                       
                        Positioned(
                          right: 20,
                          bottom: 20,
                          child: CupertinoButton(
                            color: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            borderRadius: BorderRadius.circular(30),
                            child: Text(
                              "New Find",
                              style: GoogleFonts.inter(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (ctx) => const ConfirmProductScreen(
                                    postType: "offer",
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

//ESTRUCTURA HASTA AQUÍ

Future<List<FindModel>> getFindsByLocation() async {
  try {
    // Obtener la ubicación actual usando el Singleton
    //LocationService locationService = LocationService();
    final locationService = LocationService();
    final userPosition = await locationService.getCurrentLocation();

    // Obtener el edificio más cercano
    final nearestBuilding = await findNearestBuilding(userPosition);

    if (nearestBuilding == null) {
      print("No nearby buildings found.");
      return []; // No hay edificios cercanos
    }

    print("Nearest building: ${nearestBuilding.name}, Labels: ${nearestBuilding.relatedLabels}");

    // Obtener todos los elementos disponibles (finds)
    final allFinds = await _findService.getFind();

    // Filtrar los elementos cuyos labels coincidan con los del edificio más cercano
    final filteredFinds = allFinds.where((find) {
      return nearestBuilding.relatedLabels.any((label) => find.labels.contains(label));
    }).toList();

    print("Filtered finds: ${filteredFinds.map((f) => f.title).toList()}");

    return filteredFinds;
  } catch (e) {
    print("Error in getFindsByLocation: $e");
    return [];
  }
}

Widget _buildRecommendedFindsList() {
  if (_recommendedFinds.isEmpty) {
    return Center(
      child: Text(
        "No recommendations available.",
        style: GoogleFonts.inter(
          fontSize: 14,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _recommendedFinds.length,
    itemBuilder: (context, index) {
      final findMap = _recommendedFinds[index];
      final find = FindModel.fromMap(findMap); // Convertir Map<String, dynamic> a FindModel

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (ctx) => FindsScreen(find: find), // Navegar a FindsScreen
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Imagen del find
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparentGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
               child: find.image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: find.image,
                          placeholder: (context, url) => const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.white,
                          ),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.photo,
                        color: CupertinoColors.white,
                      ),
              ),
              const SizedBox(width: 10),
              // Texto del find
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      find.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      find.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
      );
    },
  );
}
Widget _buildNearbyFindsList() {
  if (_nearbyFinds.isEmpty) {
    return Center(
      child: Text(
        "No nearby finds available.",
        style: GoogleFonts.inter(
          fontSize: 14,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _nearbyFinds.length,
    itemBuilder: (context, index) {
      final find = _nearbyFinds[index];
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (ctx) => FindsScreen(find: find),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparentGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: find.image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: find.image,
                          placeholder: (context, url) => const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.white,
                          ),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.photo,
                        color: CupertinoColors.white,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      find.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      find.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
      );
    },
  );
}

Future<void> verifyHiveCache() async {
  final findBox = await Hive.openBox('pendingFinds');
  final offlineBox = await Hive.openBox('offline_finds');

  print("Finds cache size: ${findBox.length}");
  print("Offline finds cache size: ${offlineBox.length}");
}

 // Este widget se mostrará cuando no haya ofertas para un find

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
          "No hay ofertas todavía",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.darkBackgroundGray,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Sé el primero en hacer una oferta para este producto.",
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
            "Hacer una oferta",
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

Widget _buildMostPopularList() {
  // If finds list is empty, show default items
  if (_finds.isEmpty) {
    return _buildVerticalList(_sellingItems, showBuyButton: true);
  }

  // Sort finds by upvoteCount in descending order
  final sortedFinds = List<FindModel>.from(_finds)
    ..sort((a, b) => b.upvoteCount.compareTo(a.upvoteCount));

  // Take the top 2 items or less if not enough items
  final topItems = sortedFinds.take(2).toList();
  
  // Create a list of items to display
  final List<Map<String, String>> popularItems = topItems.map((find) {
    return {
      "title": find.title,
      "subtitle": find.description,
      "upvotes": find.upvoteCount.toString(),
    };
  }).toList();

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: popularItems.length,
    itemBuilder: (ctx, index) {
      final item = popularItems[index];
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Try to get the find by matching title
            Builder(
              builder: (context) {
                final find = topItems[index];
                return Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.transparentGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: find.image.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: find.image,
                            placeholder: (context, url) => const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              CupertinoIcons.photo,
                              size: 40,
                              color: CupertinoColors.systemGrey,
                            ),
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          CupertinoIcons.photo,
                          size: 40,
                          color: CupertinoColors.systemGrey,
                        ),
                );
              }
            ),
            const SizedBox(width: 10),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"] ?? "",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item["subtitle"] ?? "",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Upvotes: ${item["upvotes"]}",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w500,
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
  /// TOP ROW: Botón circular "All requests" e ícono Search
 Widget _buildTopRow() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        // Botón circular "All requests"
        _buildAllRequestsButton(),
      ],
    ),
  );
}
  Widget _buildAllRequestsButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // No hacemos nada
        showCustomDropdownPicker(
          context,
          selectedCategory: _selectedCategory,
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryBlue,
        ),
        child: const Icon(
          CupertinoIcons.list_bullet,
          color: CupertinoColors.white,
          size: 20,
        ),
      ),
    );
  }
 /// Header de sección sin “See more”
Widget _buildSectionHeader({
  required String title,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

 Widget _buildMajorHorizontalList() {
  return SizedBox(
    height: 200, // Updated height to match card height
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _finds.isNotEmpty ? _finds.length : 5, // Mostrar 5 tarjetas vacías si no hay datos
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        if (_finds.isNotEmpty) {
          final find = _finds[index];
          return FutureBuilder<List<OfferModel>>(
            future: _findService.getOffersForFind(find.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildMajorCard(find, null);
              }
              final offer = snapshot.data!.first;
              return _buildMajorCard(find, offer);
            },
          );
        } else {
          return _buildEmptyCard();
        }
      },
    ),
  );
}

Widget _buildMajorCard(FindModel find, OfferModel? offer) {
  return Container(
    width: 160,
    height: 200, // Fixed height
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image or default icon
        Container(
          height: 90, // Reduced height
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.lightGreyBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: find.image.isNotEmpty
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: find.image,
                    placeholder: (context, url) => const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      CupertinoIcons.photo,
                      size: 40,
                      color: CupertinoColors.systemGrey,
                    ),
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(
                  CupertinoIcons.photo,
                  size: 40, // Smaller icon
                  color: CupertinoColors.systemGrey,
                ),
        ),
        
        // Date label
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 8), // Reduced padding
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Smaller padding
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "${find.timestamp.month}/${find.timestamp.day}",
              style: GoogleFonts.inter(
                fontSize: 9, // Smaller font
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
          
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
          child: Text(
            find.title, // Using title instead of id
            style: GoogleFonts.inter(
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), // Reduced padding
          child: Text(
            offer?.description ?? find.description,
            style: GoogleFonts.inter(
              fontSize: 10, // Smaller font
              color: CupertinoColors.systemGrey,
            ),
            maxLines: 1, // Reducido a 1 línea para dejar más espacio a los botones
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Spacer to push buttons to bottom
        const Spacer(),
        
        // Buttons "Find" and "Offer" at the bottom of the card
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 2), // Adjust padding
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30, // Increased height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (ctx) => FindsScreen(
                            find: find,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Find",
                      style: GoogleFonts.inter(
                        fontSize: 12, // Increased font size (was 8)
                        fontWeight: FontWeight.w600, // Added bold
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4), // Slightly wider gap
              Expanded(
                child: SizedBox(
                  height: 30, // Altura del botón
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Espaciado mínimo
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Tamaño mínimo
                    onPressed: () {
                      // Navegar a la pantalla de crear oferta sin importar la conectividad
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (ctx) => CreateOfferScreen(findId: find.id),
                        ),
                      );
                    },
                    child: Text(
                      "Offer",
                      style: GoogleFonts.inter(
                        fontSize: 12, // Tamaño de fuente
                        fontWeight: FontWeight.w600, // Negrita
                        color: CupertinoColors.white,
                      ),
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
}

 Widget _buildEmptyCard() {
  return Container(
    width: 160,
    height: 200, // Reduced height to match other cards
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ícono por defecto
        Container(
          height: 90, // Reduced height
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.lightGreyBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Icon(
            CupertinoIcons.photo,
            size: 40, // Smaller icon
            color: CupertinoColors.systemGrey,
          ),
        ),
        // Etiqueta de fecha
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 8), // Reduced padding
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Smaller padding
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "N/A",
              style: GoogleFonts.inter(
                fontSize: 9, // Smaller font
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
        // Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduced padding
          child: Text(
            "N/A",
            style: GoogleFonts.inter(
              fontSize: 12, // Smaller font
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Subtítulo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), // Reduced padding
          child: Text(
            "N/A",
            style: GoogleFonts.inter(
              fontSize: 10, // Smaller font
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        
        // Spacer to push buttons to bottom
        const Spacer(),
        
        // Botones "Find" y "Offer" at the bottom
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 2), // Adjust padding
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 24, // Fixed height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
                    onPressed: () {},
                    child: Text(
                      "Find",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Small font
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SizedBox(
                  height: 24, // Fixed height for button
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0), // Minimal padding
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 20, // Smaller minimum size
                    onPressed: () {},
                    child: Text(
                      "Offer",
                      style: GoogleFonts.inter(
                        fontSize: 8, // Small font
                        color: CupertinoColors.white,
                      ),
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
}

  /// Lista vertical (Your wishlist / Selling out)
  Widget _buildVerticalList(
    List<Map<String, String>> items, {
    bool showBuyButton = false,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Ícono por defecto
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparentGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.photo,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 10),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["title"] ?? "",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item["subtitle"] ?? "",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón “Buy” o flecha
              if (showBuyButton)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                  onPressed: () => debugPrint("Buy ${item["title"]}"),
                  child: Text(
                    "Buy",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.white,
                    ),
                  ),
                )
              else ...[
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Muestra un modal con un campo de búsqueda
  void _showSearchModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return Container(
          color: CupertinoColors.systemBackground,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CupertinoSearchTextField(),
            ],
          ),
        );
      },
    );
  }
}



Future<UniversityBuilding?> _getNearestBuilding() async {
  try {
    //LocationService locationService = LocationService();
    //Se mantiene inmutable la referencia
    final locationService = LocationService();
    // se obtien la ubicación actual con alta precisión
    final userPosition = await locationService.getCurrentLocation();
    // Imprime la ubicación actual para depuración
    print("Updated location: Latitude: ${userPosition.latitude}, Longitude: ${userPosition.longitude}");
    // Encuentra el edificio más cercano utilizando FirebaseDAO
    final nearestBuilding = await findNearestBuilding(userPosition);

    // Imprime el edificio más cercano para depuración
    if (nearestBuilding != null) {
      print("Nearest building: ${nearestBuilding.name}, Distance: ${calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        nearestBuilding.latitude,
        nearestBuilding.longitude,
      )} km");
    } else {
      print("No nearby buildings found.");
    }

    return nearestBuilding;
  } catch (e) {
    print("Error getting nearest building: $e");
    return null;
  }
}