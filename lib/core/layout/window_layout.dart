/// Breakpoints for a tablet or a wide BlueStacks window.
/// Widths under 600dp keep the phone grid and the bottom bar.
int photoColumnCount(double width) {
  if (width >= 1200) return 5;
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// The upload picker is already 3 columns on a phone. Wider windows add
/// columns and never drop below that.
int uploadColumnCount(double width) {
  final columns = photoColumnCount(width);
  return columns < 3 ? 3 : columns;
}

bool useNavigationRail(double width) => width >= 840;
