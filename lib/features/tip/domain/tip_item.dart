enum TipItem {
  juice(productId: 'tip_juice_1'),
  coffee(productId: 'tip_coffee_3'),
  ramen(productId: 'tip_ramen_9');

  const TipItem({required this.productId});

  final String productId;

  static TipItem? fromProductId(String productId) {
    for (final item in values) {
      if (item.productId == productId) return item;
    }
    return null;
  }
}
