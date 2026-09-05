/// Field-by-field equality for the immutable domain entities.
///
/// The entities used to compare on `id` alone. That reads as harmless — two
/// rows with the same primary key *are* the same record — but it breaks GetX:
/// `Rx.value = x` skips the assignment (and the rebuild) when the incoming
/// value `==` the one already held. Reloading a goal after a contribution
/// therefore left the old object in place, so the screen kept rendering a
/// stale balance while the database held the new one.
///
/// Comparing every field instead keeps identity lookups working — two reads of
/// an unchanged row still compare equal — while letting an actual change
/// through.
mixin ValueEquality {
  /// The fields that make up this value, in a stable order.
  List<Object?> get props;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    final a = props;
    final b = (other as ValueEquality).props;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(props);
}
