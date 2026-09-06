import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Maps the icon names stored in the `categories` table to Material icons.
///
/// Names are persisted, so entries may be added but never renamed. Anything
/// unknown falls back to a neutral icon rather than crashing.
class CategoryIcons {
  const CategoryIcons._();

  static const IconData fallback = Icons.label_outline_rounded;

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'home': Icons.home_rounded,
    'bolt': Icons.bolt_rounded,
    'favorite': Icons.favorite_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'movie': Icons.movie_rounded,
    'school': Icons.school_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'flight': Icons.flight_rounded,
    'group': Icons.group_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'payments': Icons.payments_rounded,
    'storefront': Icons.storefront_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'undo': Icons.undo_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'savings': Icons.savings_rounded,
    'bank': Icons.account_balance_rounded,
    'card': Icons.credit_card_rounded,
    'phone': Icons.smartphone_rounded,
    'pets': Icons.pets_rounded,
    'fitness': Icons.fitness_center_rounded,
    'coffee': Icons.local_cafe_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'gift': Icons.redeem_rounded,
    'star': Icons.star_rounded,
    'beach': Icons.beach_access_rounded,
    'car': Icons.directions_car_rounded,
    'child': Icons.child_care_rounded,
    'medical': Icons.medical_services_rounded,
    'book': Icons.menu_book_rounded,
    'tools': Icons.handyman_rounded,
    'wifi': Icons.wifi_rounded,
    'shield': Icons.shield_rounded,
  };

  /// Names offered in the icon picker, in display order.
  static List<String> get pickable => _icons.keys.toList();

  static IconData resolve(String? name) => _icons[name] ?? fallback;

  /// Falls back to a stable palette colour derived from the id, so two
  /// categories without an explicit colour still look distinct.
  static Color resolveColor(int? color, {int seed = 0}) =>
      color != null ? Color(color) : AppColors.chartColorAt(seed);
}
