import 'dart:math' as math;

class CenteredLogoLayout {
  final double left;
  final double top;
  final double width;
  final double height;

  const CenteredLogoLayout({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

CenteredLogoLayout buildCenteredLogoLayout({
  required List<List<bool>>? outerMask,
  required double logoSizeFraction,
}) {
  if (outerMask == null || outerMask.isEmpty || outerMask.first.isEmpty || logoSizeFraction <= 0) {
    return const CenteredLogoLayout(left: 0.5, top: 0.5, width: 0.0, height: 0.0);
  }

  final double h = outerMask.length.toDouble();
  final double w = outerMask.first.length.toDouble();
  final double maxDim = math.max(w, h);
  final double drawW = (logoSizeFraction * (w / maxDim)).clamp(0.0, 1.0);
  final double drawH = (logoSizeFraction * (h / maxDim)).clamp(0.0, 1.0);

  return CenteredLogoLayout(
    left: (1.0 - drawW) / 2.0,
    top: (1.0 - drawH) / 2.0,
    width: drawW,
    height: drawH,
  );
}

double effectiveLogoAuraModules(double uiValue) {
  if (uiValue <= 0) return 0.0;
  final normalized = ((uiValue - 1.0) / 2.0).clamp(0.0, 1.0);
  return 0.10 + (normalized * 0.32);
}

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

  final int maskH = outerMask.length;
  final int maskW = outerMask.first.length;
  final layout = buildCenteredLogoLayout(
    outerMask: outerMask,
    logoSizeFraction: logoSizeFraction,
  );
  if (layout.width <= 0 || layout.height <= 0) return excl;

  const int supersample = 8;
  final int hiSize = modules * supersample;
  final hiMask = List.generate(hiSize, (_) => List.filled(hiSize, false));

  for (int y = 0; y < hiSize; y++) {
    final double ny = (y + 0.5) / hiSize;
    if (ny < layout.top || ny > layout.top + layout.height) continue;
    for (int x = 0; x < hiSize; x++) {
      final double nx = (x + 0.5) / hiSize;
      if (nx < layout.left || nx > layout.left + layout.width) continue;

      final double u = (nx - layout.left) / layout.width;
      final double v = (ny - layout.top) / layout.height;
      final int px = (u * maskW).clamp(0.0, maskW - 1.0).toInt();
      final int py = (v * maskH).clamp(0.0, maskH - 1.0).toInt();
      hiMask[y][x] = outerMask[py][px];
    }
  }

  final double radius = effectiveLogoAuraModules(logoAuraModules) * supersample;
  final int ceilRadius = math.max(1, radius.ceil());
  final dilated = List.generate(hiSize, (_) => List.filled(hiSize, false));

  for (int y = 0; y < hiSize; y++) {
    for (int x = 0; x < hiSize; x++) {
      if (!hiMask[y][x]) continue;
      for (int dy = -ceilRadius; dy <= ceilRadius; dy++) {
        final int ny = y + dy;
        if (ny < 0 || ny >= hiSize) continue;
        for (int dx = -ceilRadius; dx <= ceilRadius; dx++) {
          final int nx = x + dx;
          if (nx < 0 || nx >= hiSize) continue;
          final double dist = math.sqrt((dx * dx + dy * dy).toDouble());
          if (dist <= radius + 0.001) {
            dilated[ny][nx] = true;
          }
        }
      }
    }
  }

  for (int r = 0; r < modules; r++) {
    for (int c = 0; c < modules; c++) {
      bool hit = false;
      for (int sy = 0; sy < supersample && !hit; sy++) {
        for (int sx = 0; sx < supersample && !hit; sx++) {
          if (dilated[r * supersample + sy][c * supersample + sx]) {
            hit = true;
          }
        }
      }
      excl[r][c] = hit;
    }
  }

  return excl;
}
