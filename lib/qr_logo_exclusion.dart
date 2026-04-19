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
  return 0.18 + (normalized * 0.86);
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

  final int h = outerMask.length;
  final int w = outerMask.first.length;
  final layout = buildCenteredLogoLayout(
    outerMask: outerMask,
    logoSizeFraction: logoSizeFraction,
  );
  if (layout.width <= 0 || layout.height <= 0) return excl;

  final base = List.generate(modules, (_) => List.filled(modules, false));
  const samples = [0.12, 0.30, 0.50, 0.70, 0.88];

  for (int r = 0; r < modules; r++) {
    for (int c = 0; c < modules; c++) {
      bool hit = false;
      for (final dy in samples) {
        for (final dx in samples) {
          final double nx = (c + dx) / modules;
          final double ny = (r + dy) / modules;
          if (nx < layout.left || nx > layout.left + layout.width) continue;
          if (ny < layout.top || ny > layout.top + layout.height) continue;

          final double u = (nx - layout.left) / layout.width;
          final double v = (ny - layout.top) / layout.height;
          final int px = (u * w).clamp(0.0, w - 1.0).toInt();
          final int py = (v * h).clamp(0.0, h - 1.0).toInt();
          if (outerMask[py][px]) {
            hit = true;
            break;
          }
        }
        if (hit) break;
      }
      if (hit) base[r][c] = true;
    }
  }

  final double radius = effectiveLogoAuraModules(logoAuraModules);
  final int ceilRadius = radius.ceil();
  for (int r = 0; r < modules; r++) {
    for (int c = 0; c < modules; c++) {
      if (!base[r][c]) continue;
      for (int dr = -ceilRadius; dr <= ceilRadius; dr++) {
        for (int dc = -ceilRadius; dc <= ceilRadius; dc++) {
          final int nr = r + dr;
          final int nc = c + dc;
          if (nr < 0 || nr >= modules || nc < 0 || nc >= modules) continue;
          final double dist = math.sqrt((dr * dr + dc * dc).toDouble());
          if (dist <= radius + 0.001) {
            excl[nr][nc] = true;
          }
        }
      }
    }
  }

  return excl;
}
