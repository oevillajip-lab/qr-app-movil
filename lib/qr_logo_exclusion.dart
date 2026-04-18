List<List<bool>> buildCenteredLogoExclusion({
  required int modules,
  required List<List<bool>>? outerMask,
  required double logoSizeFraction,
  required double logoAuraModules,
}) {
  final excl = List.generate(modules, (_) => List.filled(modules, false));
  if (outerMask == null || outerMask.isEmpty || outerMask.first.isEmpty || logoSizeFraction <= 0) {
    return excl;
  }

  final int h = outerMask.length;
  final int w = outerMask.first.length;
  final double lf = logoSizeFraction;
  final double ls = (1 - lf) / 2.0;
  final double le = ls + lf;
  final base = List.generate(modules, (_) => List.filled(modules, false));
  const samples = [0.2, 0.5, 0.8];

  for (int r = 0; r < modules; r++) {
    for (int c = 0; c < modules; c++) {
      bool hit = false;
      for (final dy in samples) {
        for (final dx in samples) {
          final double nx = (c + dx) / modules;
          final double ny = (r + dy) / modules;
          if (nx >= ls && nx <= le && ny >= ls && ny <= le) {
            final int px = (((nx - ls) / lf) * w).clamp(0.0, w - 1.0).toInt();
            final int py = (((ny - ls) / lf) * h).clamp(0.0, h - 1.0).toInt();
            if (outerMask[py][px]) {
              hit = true;
              break;
            }
          }
        }
        if (hit) break;
      }
      if (hit) base[r][c] = true;
    }
  }

  final int ar = logoAuraModules.toInt();
  for (int r = 0; r < modules; r++) {
    for (int c = 0; c < modules; c++) {
      if (!base[r][c]) continue;
      for (int dr = -ar; dr <= ar; dr++) {
        for (int dc = -ar; dc <= ar; dc++) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < modules && nc >= 0 && nc < modules) {
            excl[nr][nc] = true;
          }
        }
      }
    }
  }

  return excl;
}
