class Responsive {
  /// Returns a reasonable grid column count based on width.
  static int columnsForWidth(double w) {
    if (w >= 1400) return 6;
    if (w >= 1100) return 5;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }
}
