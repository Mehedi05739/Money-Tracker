/// Orderings offered by the transaction list.
///
/// A closed set, because each option maps to a fixed `ORDER BY` fragment. A
/// free-form sort string would be user input reaching SQL text, which is the
/// one thing the query layer never allows.
enum TransactionSort {
  newestFirst,
  oldestFirst,
  largestFirst,
  smallestFirst,
  titleAZ;

  String get label => switch (this) {
    TransactionSort.newestFirst => 'Newest first',
    TransactionSort.oldestFirst => 'Oldest first',
    TransactionSort.largestFirst => 'Largest amount',
    TransactionSort.smallestFirst => 'Smallest amount',
    TransactionSort.titleAZ => 'Title A–Z',
  };

  /// True when rows still arrive newest-day-first, so the list can keep its
  /// date grouping. Amount and title orders interleave days, so grouping by
  /// date would produce one section per row.
  bool get groupsByDate =>
      this == TransactionSort.newestFirst ||
      this == TransactionSort.oldestFirst;

  bool get isDefault => this == TransactionSort.newestFirst;
}
