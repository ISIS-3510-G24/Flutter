import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';

class OrdersScreen extends StatefulWidget {
    const OrdersScreen({super.key});

    @override
    _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
    int _selectedTab = 1; // Inicia en "Available"

    // Datos de ejemplo de productos (simulados)
    final List<Map<String, String>> products = [
        {
            "name": "Linoleum Sheets",
            "details": "Black / M",
            "price": "20.500 COP",
            "image": "assets/svgs/ImagePlaceHolder.svg",
        },
        {
            "name": "Organizer",
            "details": "Gold / L",
            "price": "20.500 COP",
            "image": "assets/svgs/ImagePlaceHolder.svg",
        },
        {
            "name": "Beautiful Colorful Folders",
            "details": "Blue, pink, yellow",
            "price": "20.500 COP",
            "image": "assets/svgs/ImagePlaceHolder.svg",
        },
    ];

    @override
    Widget build(BuildContext context) {
        return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
                middle: Text(
                    "Orders",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
            ),
            child: SafeArea(
                child: Column(
                    children: [
                        const SizedBox(height: 10),

                        // 🔹 Tab Selector (Not Available, Available, Purchased)
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: CupertinoSegmentedControl<int>(
                                groupValue: _selectedTab,
                                onValueChanged: (int newIndex) {
                                    setState(() {
                                        _selectedTab = newIndex;
                                    });
                                },
                                children: {
                                    0: _buildTabItem("Not available", 0),
                                    1: _buildTabItem("Available", 1),
                                    2: _buildTabItem("Purchased", 2),
                                },
                                selectedColor: const Color(0xFF66B7F0),
                                borderColor: CupertinoColors.systemGrey2,
                                unselectedColor: CupertinoColors.systemGrey6,
                                pressedColor: CupertinoColors.systemGrey5,
                            ),
                        ),

                        const SizedBox(height: 10),

                        // 🔹 Lista de productos basada en el tab seleccionado
                        Expanded(
                            child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: products.length,
                                separatorBuilder: (context, index) => Container(
                                    height: 1,
                                    color: CupertinoColors.systemGrey5,
                                ),
                                itemBuilder: (context, index) {
                                    final product = products[index];
                                    return _buildProductItem(product);
                                },
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    // 🔹 Widget para cada tab en la barra superior
    Widget _buildTabItem(String title, int index) {
        final bool isSelected = _selectedTab == index;
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Text(
                title,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? CupertinoColors.white : CupertinoColors.black,
                ),
            ),
        );
    }

    // 🔹 Widget para cada producto en la lista
    Widget _buildProductItem(Map<String, String> product) {
        return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
                Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
            },
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        // 🔹 Imagen del producto (Placeholder)
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SvgPicture.asset(
                                product["image"]!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                            ),
                        ),
                        const SizedBox(width: 10),

                        // 🔹 Detalles del producto
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        product["name"]!,
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                        product["details"]!,
                                        style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
                                    ),
                                    Text(
                                        product["price"]!,
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                ],
                            ),
                        ),

                        // 🔹 Botón de acción (Comprar o más información)
                        CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF66B7F0),
                                ),
                                child: const Icon(
                                    CupertinoIcons.chat_bubble,
                                    color: CupertinoColors.white,
                                    size: 20,
                                ),
                            ),
                            onPressed: () {
                                Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
                            },
                        ),

                        const SizedBox(width: 10),

                        // 🔹 Botón de compra (Por ahora solo un placeholder)
                        Text(
                            "Buy",
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF66B7F0),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}
