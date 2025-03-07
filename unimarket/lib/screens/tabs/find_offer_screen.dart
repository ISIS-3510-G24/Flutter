import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:unimarket/screens/tabs/offer_screen.dart';

class FindAndOfferScreen extends StatefulWidget {
  const FindAndOfferScreen({super.key});

  @override
  _FindAndOfferScreenState createState() => _FindAndOfferScreenState();
}

class _FindAndOfferScreenState extends State<FindAndOfferScreen> {
  bool isFindSelected = true; // Variable de estado para controlar la selección

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: SizedBox.shrink(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildToggleButtons(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {},
                    child: const Icon(CupertinoIcons.search, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildCategoryChips(),
                  const SizedBox(height: 12),
                  _buildSectionHeader("From your major"),
                  _buildMajorItem("Computer", "Lenovo"),
                  const SizedBox(height: 12),
                  _buildSectionHeader("Your wishlist"),
                  _buildWishlistItem("Set pink rulers", "Pink reference"),
                  _buildWishlistItem("Pink scissors", "Any reference"),
                  const SizedBox(height: 12),
                  _buildSectionHeader("Selling out"),
                  _buildMajorItem("Smartphone", "Samsung Galaxy S21"),
                  _buildMajorItem("Headphones", "Sony WH-1000XM4"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Row(
      children: [
        _buildChip("FIND", isFindSelected),
        const SizedBox(width: 4),
        _buildChip("OFFER", !isFindSelected),
      ],
    );
  }

  Widget _buildChip(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        color: isSelected ? const Color.fromRGBO(102, 183, 240, 1) : CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(18),
        onPressed: () {
          setState(() {
            if (text == "FIND") {
              isFindSelected = true;
            } else {
              isFindSelected = false;
              if (text == "OFFER") {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => const OfferScreen()),
                );
              }
            }
          });
        },
        child: Text(
          text,
          style: TextStyle(fontSize: 14, color: isSelected ? CupertinoColors.white : CupertinoColors.black),
        ),
      ),
    );
  }

  // ... el resto de tu código _buildCategoryChips, _buildSectionHeader, etc. ...

  Widget _buildCategoryChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChip("ALL REQUESTS", false),
        _buildChip("MATERIALS", true),
        _buildChip("TECHNOLOGY", false),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: const Text("See more", style: TextStyle(fontSize: 14, color: Color(0xFF66B7F0))),
        ),
      ],
    );
  }

  Widget _buildMajorItem(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildPlaceholderImage(size: 60),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                const SizedBox(height: 6),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  color: const Color(0xFF66B7F0),
                  borderRadius: BorderRadius.circular(18),
                  onPressed: () {},
                  child: const Text("Buy", style: TextStyle(fontSize: 12, color: CupertinoColors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistItem(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildPlaceholderImage(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGrey),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage({double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.photo, size: 20, color: CupertinoColors.white),
      ),
    );
  }
}