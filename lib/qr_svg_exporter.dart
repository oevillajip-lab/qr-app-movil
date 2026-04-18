// qr_svg_exporter.dart
import 'dart:convert' show base64Encode;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Color;
import 'package:qr/qr.dart';

import 'qr_logo_exclusion.dart';

class QrSvgExporter {
  QrSvgExporter._();

  static String generate({
    required String data,
    required String estilo,
    required Color qrC1,
    required Color qrC2,
    required String qrMode,
    required String qrDir,
    required String bgMode,
    required Color bgC1,
    required Color bgC2,
    required String bgGradDir,
    required bool customEyes,
    required Color eyeExt,
    required Color eyeInt,
    String? mapSubStyle,
    String? advSubStyle,
    String? splitDir,
    Uint8List? logoBytes,
    List<List<bool>>? outerMask,
    List<List<bool>>? shapeMask,
    double logoSizeFrac = 0.0,
    double logoAuraModules = 0.0,
    double shapeGap = 0.8,
    double size = 1024,
  }) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final qr = QrImage(qrCode);
    final int m = qr.moduleCount;
    final double t = size / m;

    final bool hasBg = bgMode != 'Transparente';
    final double pad = hasBg ? size * 0.078125 : 0.0;
    final double totalSize = size + 2 * pad;
    final double cornerRadius = pad * 0.9;
    final bool useGradient = qrMode != 'Sólido (Un Color)';

    final buf = StringBuffer();
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="${_f(totalSize)}" height="${_f(totalSize)}" '
        'viewBox="0 0 ${_f(totalSize)} ${_f(totalSize)}">');

    buf.writeln('<defs>');
    if (useGradient) {
      buf.write(_linearGradientDef('qrGrad', qrC1, qrC2, qrDir, size));
    }
    if (bgMode == 'Degradado') {
      buf.write(_linearGradientDef('bgGrad', bgC1, bgC2, bgGradDir, totalSize));
    }
    buf.writeln('</defs>');

    if (hasBg) {
      final String fill = bgMode == 'Degradado'
          ? 'url(#bgGrad)'
          : (bgMode == 'Sólido (Color)' ? _hex(bgC1) : '#ffffff');
      buf.writeln('<rect width="${_f(totalSize)}" height="${_f(totalSize)}" '
          '${cornerRadius > 0 ? 'rx="${_f(cornerRadius)}" ry="${_f(cornerRadius)}" ' : ''}'
          'fill="$fill"/>');
    }

    if (pad > 0) {
      buf.writeln('<g transform="translate(${_f(pad)},${_f(pad)})">');
    }

    final bool isSplitStyle = estilo.contains('Split');
    final bool isShapeStyle = estilo.contains('Forma') || estilo.contains('Mapa');
    final String effectiveStyle = isShapeStyle
        ? (mapSubStyle ?? 'Liquid Pro (Gusano)')
        : isSplitStyle
            ? (advSubStyle ?? 'Liquid Pro (Gusano)')
            : estilo;

    final String qrFill = useGradient ? 'url(#qrGrad)' : _hex(qrC1);
    final String extFill = customEyes ? _hex(eyeExt) : qrFill;
    final String intFill = customEyes ? _hex(eyeInt) : qrFill;

    if (isShapeStyle && shapeMask != null && shapeMask.isNotEmpty && shapeMask.first.isNotEmpty) {
      buf.write(_drawShapeMode(
        qr: qr,
        m: m,
        size: size,
        qrFill: qrFill,
        extFill: extFill,
        intFill: intFill,
        style: effectiveStyle,
        shapeMask: shapeMask,
        shapeGap: shapeGap,
      ));
    } else {
      final excl = _buildLogoExclusion(
        m,
        outerMask,
        logoSizeFrac,
        logoAuraModules,
      );

      final bool isLiquid = effectiveStyle.contains('Gusano') || effectiveStyle.contains('Liquid');
      final bool isBars = effectiveStyle.contains('Barras');
      final bool isDots = effectiveStyle.contains('Puntos');
      final bool isDiamonds = effectiveStyle.contains('Diamantes') || effectiveStyle.contains('Rombos');

      if (isSplitStyle) {
        buf.write(_drawSplit(
          qr: qr,
          m: m,
          t: t,
          style: effectiveStyle,
          gradientFill: qrFill,
          c1: qrC1,
          c2: qrC2,
          useGradient: useGradient,
          splitDir: splitDir ?? 'Vertical',
          excl: excl,
        ));
      } else if (isLiquid) {
        buf.write(_drawLiquid(qr, m, t, qrFill, excl));
      } else if (isBars) {
        buf.write(_drawBars(qr, m, t, qrFill, excl));
      } else if (isDots) {
        buf.write(_drawDots(qr, m, t, qrFill, excl));
      } else if (isDiamonds) {
        buf.write(_drawDiamonds(qr, m, t, qrFill, excl));
      } else {
        buf.write(_drawSquares(qr, m, t, qrFill, excl));
      }

      final bool eyeCircle = isDots;
      final bool eyeDiamond = isDiamonds;
      buf.write(_eye(0, 0, t, extFill, intFill, eyeCircle, eyeDiamond));
      buf.write(_eye((m - 7) * t, 0, t, extFill, intFill, eyeCircle, eyeDiamond));
      buf.write(_eye(0, (m - 7) * t, t, extFill, intFill, eyeCircle, eyeDiamond));

      if (logoBytes != null && logoSizeFrac > 0) {
        final b64 = base64Encode(logoBytes);
        final double ls = size * logoSizeFrac;
        final double lo = (size - ls) / 2;
        buf.writeln('<image x="${_f(lo)}" y="${_f(lo)}" '
            'width="${_f(ls)}" height="${_f(ls)}" '
            'preserveAspectRatio="xMidYMid meet" '
            'href="data:image/png;base64,$b64" '
            'xlink:href="data:image/png;base64,$b64"/>');
      }
    }

    if (pad > 0) {
      buf.writeln('</g>');
    }
    buf.writeln('</svg>');
    return buf.toString();
  }

  static String _drawShapeMode({
    required QrImage qr,
    required int m,
    required double size,
    required String qrFill,
    required String extFill,
    required String intFill,
    required String style,
    required List<List<bool>> shapeMask,
    required double shapeGap,
  }) {
    final int maskW = math.max(size.round(), 1);
    final int maskH = math.max(size.round(), 1);
    final canvasMask = _buildCanvasShapeMask(shapeMask, maskW, maskH);

    int qrDataCells = 0;
    int qrDarkCells = 0;
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (_isEye(r, c, m)) continue;
        qrDataCells++;
        if (qr.isDark(r, c)) qrDarkCells++;
      }
    }
    double targetDensity = qrDataCells == 0 ? 0.50 : (qrDarkCells / qrDataCells);

    final bool isLiquid = style.contains('Gusano') || style.contains('Liquid');
    final bool isBars = style.contains('Barras');
    final bool isDots = style.contains('Puntos');
    final bool isDiamonds = style.contains('Diamantes') || style.contains('Rombos');

    if (isBars) targetDensity += 0.02;
    if (isDots || isDiamonds) targetDensity -= 0.01;
    targetDensity = targetDensity.clamp(0.22, 0.80);

    bool insideShapePoint(double px, double py) {
      final int x = px.floor().clamp(0, maskW - 1).toInt();
      final int y = py.floor().clamp(0, maskH - 1).toInt();
      return canvasMask[y][x];
    }

    double rectCoverage(double left, double top, double width, double height) {
      const probes = [0.12, 0.30, 0.50, 0.70, 0.88];
      int ok = 0;
      int total = 0;
      for (final py in probes) {
        for (final px in probes) {
          total++;
          if (insideShapePoint(left + width * px, top + height * py)) {
            ok++;
          }
        }
      }
      return total == 0 ? 0.0 : ok / total;
    }

    int minSX = maskW;
    int minSY = maskH;
    int maxSX = 0;
    int maxSY = 0;
    int shapeCount = 0;
    double sumSX = 0;
    double sumSY = 0;

    for (int y = 0; y < maskH; y++) {
      for (int x = 0; x < maskW; x++) {
        if (!canvasMask[y][x]) continue;
        shapeCount++;
        sumSX += x + 0.5;
        sumSY += y + 0.5;
        if (x < minSX) minSX = x;
        if (x > maxSX) maxSX = x;
        if (y < minSY) minSY = y;
        if (y > maxSY) maxSY = y;
      }
    }

    final double shapeLeft = shapeCount == 0 ? 0 : minSX.toDouble();
    final double shapeTop = shapeCount == 0 ? 0 : minSY.toDouble();
    final double shapeRight = shapeCount == 0 ? size : (maxSX + 1).toDouble();
    final double shapeBottom = shapeCount == 0 ? size : (maxSY + 1).toDouble();
    final double shapeWidth = shapeRight - shapeLeft;
    final double shapeHeight = shapeBottom - shapeTop;
    final double shapeCenterX = shapeCount == 0 ? size / 2 : sumSX / shapeCount;
    final double shapeCenterY = shapeCount == 0 ? size / 2 : sumSY / shapeCount;

    double bestLeft = (size - size * 0.48) / 2;
    double bestTop = (size - size * 0.48) / 2;
    double bestSide = math.min(size, size) * 0.48;
    double bestScore = -1e18;

    final double aspectRatio = shapeWidth / math.max(shapeHeight, 1.0);
    final bool isNarrowShape = aspectRatio < 0.6 || aspectRatio > 1.6;
    final double maxCandidateSide = isNarrowShape
        ? math.min(shapeWidth, shapeHeight) * 0.88
        : math.min(shapeWidth, shapeHeight) * 0.78;
    final double minCandidateSide = math.max(48.0, (m + 2) * 1.80);

    for (double side = maxCandidateSide; side >= minCandidateSide; side -= 5.0) {
      final double step = math.max(3.0, side * 0.045);
      final double safetyPad = side * (0.18 + (shapeGap.clamp(0.0, 3.0) * 0.04));

      for (double top = shapeTop; top <= shapeBottom - side; top += step) {
        for (double left = shapeLeft; left <= shapeRight - side; left += step) {
          final double cov = rectCoverage(left, top, side, side);
          final double minCov = isNarrowShape ? 0.62 : 0.88;
          if (cov < minCov) continue;

          final double safeCov = rectCoverage(left - safetyPad, top - safetyPad, side + safetyPad * 2, side + safetyPad * 2);
          final double minSafeCov = isNarrowShape ? 0.48 : 0.70;
          if (safeCov < minSafeCov) continue;

          final double eyeW = side * 7.0 / (m + 2.0);
          bool eyeStrictlyInside(double ex, double ey) {
            for (final fy in [0.05, 0.25, 0.5, 0.75, 0.95]) {
              for (final fx in [0.05, 0.25, 0.5, 0.75, 0.95]) {
                if (!insideShapePoint(ex + fx * eyeW, ey + fy * eyeW)) return false;
              }
            }
            return true;
          }

          if (!eyeStrictlyInside(left, top)) continue;
          if (!eyeStrictlyInside(left + side - eyeW, top)) continue;
          if (!eyeStrictlyInside(left, top + side - eyeW)) continue;

          final double dx = (left + side / 2) - shapeCenterX;
          final double dy = (top + side / 2) - shapeCenterY;
          final double centerPenalty = (dx * dx + dy * dy) / (side * side);

          double edgePenalty = 0.0;
          if (left - shapeLeft < side * 0.10) edgePenalty += 0.22;
          if (shapeRight - (left + side) < side * 0.10) edgePenalty += 0.22;
          if (top - shapeTop < side * 0.14) edgePenalty += 0.34;
          if (shapeBottom - (top + side) < side * 0.10) edgePenalty += 0.20;

          final double score =
              (side * 0.045) +
              (cov * 2.9) +
              (safeCov * 4.2) -
              (centerPenalty * 1.30) -
              edgePenalty;

          if (score > bestScore) {
            bestScore = score;
            bestLeft = left;
            bestTop = top;
            bestSide = side;
          }
        }
      }
    }

    final double gapModules = shapeGap.clamp(0.0, 3.0);
    final double probeQt = bestSide / (m + 2.0);
    final double embedInsetModules = 1.10 + gapModules * 0.55;
    final double embedInsetPx = math.min(probeQt * embedInsetModules, bestSide * 0.18);
    final double embeddedLeft = bestLeft + embedInsetPx;
    final double embeddedTop = bestTop + embedInsetPx;
    final double embeddedSide = bestSide - embedInsetPx * 2;
    const double quietModules = 0.35;
    final double qt = embeddedSide / (m + quietModules * 2.0);
    final double qrDataLeft = embeddedLeft + qt * quietModules;
    final double qrDataTop = embeddedTop + qt * quietModules;
    final double qrDataSide = qt * m;
    final double quietPad = qt * gapModules;
    final double quietLeft = qrDataLeft - quietPad;
    final double quietTop = qrDataTop - quietPad;
    final double quietRight = qrDataLeft + qrDataSide + quietPad;
    final double quietBottom = qrDataTop + qrDataSide + quietPad;

    int hashCell(int rr, int cc) {
      int v = ((rr + 101) * 73856093) ^
          ((cc + 211) * 19349663) ^
          ((m + 307) * 83492791);
      v ^= (v >> 13);
      v ^= (v << 7);
      return v & 0x7fffffff;
    }

    final double decoStep = qt;
    final double originX = qrDataLeft;
    final double originY = qrDataTop;
    final int minCol = (((0.0 - originX) / decoStep).floor()) - 2;
    final int maxCol = (((size - originX) / decoStep).ceil()) + 2;
    final int minRow = (((0.0 - originY) / decoStep).floor()) - 2;
    final int maxRow = (((size - originY) / decoStep).ceil()) + 2;

    final Map<String, bool> active = <String, bool>{};
    String key(int rr, int cc) => '$rr:$cc';

    bool cellAllowed(int rr, int cc) {
      final double left = originX + cc * decoStep;
      final double top = originY + rr * decoStep;
      final double right = left + decoStep;
      final double bottom = top + decoStep;

      if (right <= 0 || bottom <= 0 || left >= size || top >= size) return false;
      if (!(right <= quietLeft || left >= quietRight || bottom <= quietTop || top >= quietBottom)) {
        return false;
      }
      return rectCoverage(left, top, decoStep, decoStep) >= 0.60;
    }

    for (int rr = minRow; rr <= maxRow; rr++) {
      for (int cc = minCol; cc <= maxCol; cc++) {
        if (!cellAllowed(rr, cc)) {
          active[key(rr, cc)] = false;
          continue;
        }
        final double v = (hashCell(rr, cc) % 1000) / 1000.0;
        active[key(rr, cc)] = v < targetDensity;
      }
    }

    bool on(int rr, int cc) => active[key(rr, cc)] ?? false;

    final buf = StringBuffer();

    if (isBars) {
      buf.writeln('<g fill="$qrFill">');
      for (int cc = minCol; cc <= maxCol; cc++) {
        for (int rr = minRow; rr <= maxRow; rr++) {
          if (!on(rr, cc)) continue;
          if (on(rr - 1, cc)) continue;
          int endR = rr;
          while (on(endR + 1, cc)) {
            endR++;
          }
          final double x = originX + cc * decoStep + decoStep * 0.10;
          final double y = originY + rr * decoStep;
          final double w = decoStep * 0.80;
          final double h = (endR - rr + 1) * decoStep;
          final double rx = decoStep * 0.38;
          buf.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(w)}" height="${_f(h)}" rx="${_f(rx)}" ry="${_f(rx)}"/>');
        }
      }
      buf.writeln('</g>');
    } else if (isLiquid) {
      final segs = StringBuffer();
      for (int rr = minRow; rr <= maxRow; rr++) {
        for (int cc = minCol; cc <= maxCol; cc++) {
          if (!on(rr, cc)) continue;
          final double x = originX + cc * decoStep;
          final double y = originY + rr * decoStep;
          final double cx = x + decoStep / 2;
          final double cy = y + decoStep / 2;
          segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy)} ');
          if (on(rr, cc + 1)) {
            segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx + decoStep)} ${_f(cy)} ');
          }
          if (on(rr + 1, cc)) {
            segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy + decoStep)} ');
          }
        }
      }
      buf.writeln('<path d="${segs.toString().trim()}" stroke="$qrFill" '
          'stroke-width="${_f(decoStep)}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>');
    } else {
      buf.writeln('<g fill="$qrFill">');
      for (int rr = minRow; rr <= maxRow; rr++) {
        for (int cc = minCol; cc <= maxCol; cc++) {
          if (!on(rr, cc)) continue;
          final double x = originX + cc * decoStep;
          final double y = originY + rr * decoStep;
          final double cx = x + decoStep / 2;
          final double cy = y + decoStep / 2;
          if (isDots) {
            final double h = (hashCell(rr, cc) % 100) / 100.0;
            final double rad = decoStep * (0.33 + 0.12 * h);
            buf.writeln('<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(rad)}"/>');
          } else if (isDiamonds) {
            final double h = (hashCell(rr, cc) % 100) / 100.0;
            final double sc = 0.65 + 0.22 * h;
            final double off = decoStep * (1 - sc) / 2;
            final String d =
                'M ${_f(cx)},${_f(y + off)} '
                'L ${_f(x + decoStep - off)},${_f(cy)} '
                'L ${_f(cx)},${_f(y + decoStep - off)} '
                'L ${_f(x + off)},${_f(cy)} Z';
            buf.writeln('<path d="$d"/>');
          } else {
            buf.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(decoStep + 0.2)}" height="${_f(decoStep + 0.2)}"/>');
          }
        }
      }
      buf.writeln('</g>');
    }

    bool darkOk(int r, int c) {
      if (r < 0 || r >= m || c < 0 || c >= m) return false;
      if (!qr.isDark(r, c)) return false;
      if (_isEye(r, c, m)) return false;
      return true;
    }

    final EyeKind eyeKind = isDots ? EyeKind.circle : (isDiamonds ? EyeKind.diamond : EyeKind.rect);

    if (isLiquid) {
      final segs = StringBuffer();
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;
          final double x = qrDataLeft + c * qt;
          final double y = qrDataTop + r * qt;
          final double cx = x + qt / 2;
          final double cy = y + qt / 2;
          segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy)} ');
          if (darkOk(r, c + 1)) {
            segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx + qt)} ${_f(cy)} ');
          }
          if (darkOk(r + 1, c)) {
            segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy + qt)} ');
          }
        }
      }
      buf.writeln('<path d="${segs.toString().trim()}" stroke="$qrFill" '
          'stroke-width="${_f(qt)}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>');
    } else if (isBars) {
      buf.writeln('<g fill="$qrFill">');
      for (int c = 0; c < m; c++) {
        for (int r = 0; r < m; r++) {
          if (!darkOk(r, c)) continue;
          if (r > 0 && darkOk(r - 1, c)) continue;
          int er = r;
          while (er + 1 < m && darkOk(er + 1, c)) {
            er++;
          }
          final double x = qrDataLeft + c * qt + qt * 0.10;
          final double y = qrDataTop + r * qt;
          final double w = qt * 0.80;
          final double h = (er - r + 1) * qt;
          final double rx = qt * 0.38;
          buf.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(w)}" height="${_f(h)}" rx="${_f(rx)}" ry="${_f(rx)}"/>');
        }
      }
      buf.writeln('</g>');
    } else if (isDots) {
      buf.writeln('<g fill="$qrFill">');
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;
          final double x = qrDataLeft + c * qt;
          final double y = qrDataTop + r * qt;
          final double cx = x + qt / 2;
          final double cy = y + qt / 2;
          final double h = ((r * 13 + c * 29) % 100) / 100.0;
          final double rad = qt * (0.35 + 0.15 * h);
          buf.writeln('<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(rad)}"/>');
        }
      }
      buf.writeln('</g>');
    } else if (isDiamonds) {
      buf.writeln('<g fill="$qrFill">');
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;
          final double x = qrDataLeft + c * qt;
          final double y = qrDataTop + r * qt;
          final double cx = x + qt / 2;
          final double cy = y + qt / 2;
          final double h = ((r * 17 + c * 31) % 100) / 100.0;
          final double sc = 0.65 + 0.22 * h;
          final double off = qt * (1 - sc) / 2;
          final String d =
              'M ${_f(cx)},${_f(y + off)} '
              'L ${_f(x + qt - off)},${_f(cy)} '
              'L ${_f(cx)},${_f(y + qt - off)} '
              'L ${_f(x + off)},${_f(cy)} Z';
          buf.writeln('<path d="$d"/>');
        }
      }
      buf.writeln('</g>');
    } else {
      buf.writeln('<g fill="$qrFill">');
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;
          final double x = qrDataLeft + c * qt;
          final double y = qrDataTop + r * qt;
          buf.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(qt + 0.2)}" height="${_f(qt + 0.2)}"/>');
        }
      }
      buf.writeln('</g>');
    }

    buf.write(_eyeAt(qrDataLeft, qrDataTop, qt, extFill, intFill, eyeKind));
    buf.write(_eyeAt(qrDataLeft + qrDataSide - 7 * qt, qrDataTop, qt, extFill, intFill, eyeKind));
    buf.write(_eyeAt(qrDataLeft, qrDataTop + qrDataSide - 7 * qt, qt, extFill, intFill, eyeKind));

    return buf.toString();
  }

  static List<List<bool>> _buildCanvasShapeMask(List<List<bool>> shapeMask, int width, int height) {
    final canvasMask = List.generate(height, (_) => List.filled(width, false));
    final int sh = shapeMask.length;
    final int sw = shapeMask.first.length;
    final double scale = math.min(width / sw, height / sh);
    final double drawW = sw * scale;
    final double drawH = sh * scale;
    final double offX = (width - drawW) / 2.0;
    final double offY = (height - drawH) / 2.0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final double sx = ((x + 0.5) - offX) / scale;
        final double sy = ((y + 0.5) - offY) / scale;
        if (sx >= 0 && sx < sw && sy >= 0 && sy < sh) {
          canvasMask[y][x] = shapeMask[sy.floor().clamp(0, sh - 1)][sx.floor().clamp(0, sw - 1)];
        }
      }
    }
    return canvasMask;
  }

  static String _drawSquares(QrImage qr, int m, double t, String fill, List<List<bool>> excl) {
    final buf = StringBuffer();
    buf.writeln('<g fill="$fill">');
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c) || _isEye(r, c, m) || excl[r][c]) continue;
        buf.writeln('<rect x="${_f(c * t)}" y="${_f(r * t)}" width="${_f(t)}" height="${_f(t)}"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  static String _drawLiquid(QrImage qr, int m, double t, String fill, List<List<bool>> excl) {
    final segs = StringBuffer();
    bool ok(int r, int c) {
      if (r < 0 || r >= m || c < 0 || c >= m) return false;
      if (!qr.isDark(r, c) || _isEye(r, c, m) || excl[r][c]) return false;
      return true;
    }
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!ok(r, c)) continue;
        final double cx = c * t + t / 2;
        final double cy = r * t + t / 2;
        segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy)} ');
        if (ok(r, c + 1)) segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx + t)} ${_f(cy)} ');
        if (ok(r + 1, c)) segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy + t)} ');
      }
    }
    return '<path d="${segs.toString().trim()}" stroke="$fill" stroke-width="${_f(t)}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>\n';
  }

  static String _drawBars(QrImage qr, int m, double t, String fill, List<List<bool>> excl) {
    final buf = StringBuffer();
    final drawn = List.generate(m, (_) => List.filled(m, false));
    buf.writeln('<g fill="$fill">');
    for (int c = 0; c < m; c++) {
      for (int r = 0; r < m; r++) {
        if (drawn[r][c] || !qr.isDark(r, c) || _isEye(r, c, m) || excl[r][c]) continue;
        int er = r;
        while (er + 1 < m && qr.isDark(er + 1, c) && !_isEye(er + 1, c, m) && !drawn[er + 1][c] && !excl[er + 1][c]) {
          er++;
        }
        for (int k = r; k <= er; k++) {
          drawn[k][c] = true;
        }
        final double x = c * t + t * 0.10;
        final double y = r * t;
        final double w = t * 0.80;
        final double h = (er - r + 1) * t;
        final double rx = t * 0.38;
        buf.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(w)}" height="${_f(h)}" rx="${_f(rx)}" ry="${_f(rx)}"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  static String _drawDots(QrImage qr, int m, double t, String fill, List<List<bool>> excl) {
    final buf = StringBuffer();
    buf.writeln('<g fill="$fill">');
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c) || _isEye(r, c, m) || excl[r][c]) continue;
        final double h = ((r * 13 + c * 29) % 100) / 100.0;
        final double cx = c * t + t / 2;
        final double cy = r * t + t / 2;
        final double rad = t * (0.33 + 0.12 * h);
        buf.writeln('<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(rad)}"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  static String _drawDiamonds(QrImage qr, int m, double t, String fill, List<List<bool>> excl) {
    final buf = StringBuffer();
    buf.writeln('<g fill="$fill">');
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c) || _isEye(r, c, m) || excl[r][c]) continue;
        final double h = ((r * 17 + c * 31) % 100) / 100.0;
        final double sc = 0.65 + 0.22 * h;
        final double x = c * t;
        final double y = r * t;
        final double off = t * (1 - sc) / 2;
        final double cx = x + t / 2;
        final double cy = y + t / 2;
        final String d = 'M ${_f(cx)},${_f(y + off)} L ${_f(x + t - off)},${_f(cy)} L ${_f(cx)},${_f(y + t - off)} L ${_f(x + off)},${_f(cy)} Z';
        buf.writeln('<path d="$d"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  static String _drawSplit({
    required QrImage qr,
    required int m,
    required double t,
    required String style,
    required String gradientFill,
    required Color c1,
    required Color c2,
    required bool useGradient,
    required String splitDir,
    required List<List<bool>> excl,
  }) {
    final bool isLiquid = style.contains('Gusano') || style.contains('Liquid');
    final bool isBars = style.contains('Barras');
    final bool isDots = style.contains('Puntos');
    final bool isDiamonds = style.contains('Diamantes') || style.contains('Rombos');

    String sideFill(bool side1) => useGradient ? gradientFill : _hex(side1 ? c1 : c2);

    bool darkOk(int r, int c) {
      if (r < 0 || r >= m || c < 0 || c >= m) return false;
      if (!qr.isDark(r, c) || _isEye(r, c, m) || excl[r][c]) return false;
      return true;
    }
    bool isSide1(int r, int c) {
      if (splitDir == 'Horizontal') return r < m / 2;
      if (splitDir == 'Diagonal') return (r + c) < m;
      return c < m / 2;
    }
    bool sameSide(int r, int c, int r2, int c2) {
      if (r2 < 0 || r2 >= m || c2 < 0 || c2 >= m) return false;
      return isSide1(r, c) == isSide1(r2, c2);
    }

    final buf = StringBuffer();
    if (isLiquid) {
      final seg1 = StringBuffer();
      final seg2 = StringBuffer();
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;
          final double cx = c * t + t / 2;
          final double cy = r * t + t / 2;
          final target = isSide1(r, c) ? seg1 : seg2;
          target.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy)} ');
          if (darkOk(r, c + 1) && sameSide(r, c, r, c + 1)) target.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx + t)} ${_f(cy)} ');
          if (darkOk(r + 1, c) && sameSide(r, c, r + 1, c)) target.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy + t)} ');
        }
      }
      if (seg1.isNotEmpty) buf.writeln('<path d="${seg1.toString().trim()}" stroke="${sideFill(true)}" stroke-width="${_f(t)}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>');
      if (seg2.isNotEmpty) buf.writeln('<path d="${seg2.toString().trim()}" stroke="${sideFill(false)}" stroke-width="${_f(t)}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>');
      return buf.toString();
    }

    final g1 = StringBuffer()..writeln('<g fill="${sideFill(true)}">');
    final g2 = StringBuffer()..writeln('<g fill="${sideFill(false)}">');

    if (isBars) {
      final drawn = List.generate(m, (_) => List.filled(m, false));
      for (int c = 0; c < m; c++) {
        for (int r = 0; r < m; r++) {
          if (drawn[r][c] || !darkOk(r, c)) continue;
          final bool side1 = isSide1(r, c);
          int er = r;
          while (er + 1 < m && darkOk(er + 1, c) && !drawn[er + 1][c] && isSide1(er + 1, c) == side1) {
            er++;
          }
          for (int k = r; k <= er; k++) drawn[k][c] = true;
          final target = side1 ? g1 : g2;
          final double x = c * t + t * 0.10;
          final double y = r * t;
          final double w = t * 0.80;
          final double h = (er - r + 1) * t;
          final double rx = t * 0.38;
          target.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(w)}" height="${_f(h)}" rx="${_f(rx)}" ry="${_f(rx)}"/>');
        }
      }
    } else {
      for (int r = 0; r < m; r++) {
        for (int c = 0; c < m; c++) {
          if (!darkOk(r, c)) continue;
          final target = isSide1(r, c) ? g1 : g2;
          final double x = c * t;
          final double y = r * t;
          final double cx = x + t / 2;
          final double cy = y + t / 2;
          if (isDots) {
            final double h = ((r * 13 + c * 29) % 100) / 100.0;
            final double rad = t * (0.33 + 0.12 * h);
            target.writeln('<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(rad)}"/>');
          } else if (isDiamonds) {
            final double h = ((r * 17 + c * 31) % 100) / 100.0;
            final double sc = 0.65 + 0.22 * h;
            final double off = t * (1 - sc) / 2;
            final String d = 'M ${_f(cx)},${_f(y + off)} L ${_f(x + t - off)},${_f(cy)} L ${_f(cx)},${_f(y + t - off)} L ${_f(x + off)},${_f(cy)} Z';
            target.writeln('<path d="$d"/>');
          } else {
            target.writeln('<rect x="${_f(x)}" y="${_f(y)}" width="${_f(t)}" height="${_f(t)}"/>');
          }
        }
      }
    }

    g1.writeln('</g>');
    g2.writeln('</g>');
    return g1.toString() + g2.toString();
  }

  static List<List<bool>> _buildLogoExclusion(int m, List<List<bool>>? outerMask, double logoSizeFrac, double logoAuraModules) {
    return buildCenteredLogoExclusion(
      modules: m,
      outerMask: outerMask,
      logoSizeFraction: logoSizeFrac,
      logoAuraModules: logoAuraModules,
    );
  }

  static String _eye(double ox, double oy, double t, String extFill, String intFill, bool isCircle, bool isDiamond) {
    final EyeKind kind = isCircle ? EyeKind.circle : (isDiamond ? EyeKind.diamond : EyeKind.rect);
    return _eyeAt(ox, oy, t, extFill, intFill, kind);
  }

  static String _eyeAt(double ox, double oy, double t, String extFill, String intFill, EyeKind kind) {
    final buf = StringBuffer();
    final double s = 7 * t;
    if (kind == EyeKind.circle) {
      final double r0 = s / 2;
      final double r1 = (s - 2 * t) / 2;
      final double cx = ox + s / 2;
      final double cy = oy + s / 2;
      buf.writeln('<path fill-rule="evenodd" fill="$extFill" d="M ${_f(cx - r0)},${_f(cy)} a ${_f(r0)},${_f(r0)} 0 1,0 ${_f(r0 * 2)},0 a ${_f(r0)},${_f(r0)} 0 1,0 ${_f(-r0 * 2)},0 Z M ${_f(cx - r1)},${_f(cy)} a ${_f(r1)},${_f(r1)} 0 1,0 ${_f(r1 * 2)},0 a ${_f(r1)},${_f(r1)} 0 1,0 ${_f(-r1 * 2)},0 Z"/>');
      final double ri = (s - 4.2 * t) / 2;
      buf.writeln('<circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(ri)}" fill="$intFill"/>');
    } else if (kind == EyeKind.diamond) {
      final double cx = ox + 3.5 * t;
      final double cy = oy + 3.5 * t;
      buf.writeln('<path fill-rule="evenodd" fill="$extFill" d="M ${_f(cx)},${_f(oy)} L ${_f(ox + 7 * t)},${_f(cy)} L ${_f(cx)},${_f(oy + 7 * t)} L ${_f(ox)},${_f(cy)} Z M ${_f(cx)},${_f(oy + 1.2 * t)} L ${_f(ox + 5.8 * t)},${_f(cy)} L ${_f(cx)},${_f(oy + 5.8 * t)} L ${_f(ox + 1.2 * t)},${_f(cy)} Z"/>');
      buf.writeln('<path d="M ${_f(cx)},${_f(oy + 2.2 * t)} L ${_f(ox + 4.8 * t)},${_f(cy)} L ${_f(cx)},${_f(oy + 4.8 * t)} L ${_f(ox + 2.2 * t)},${_f(cy)} Z" fill="$intFill"/>');
    } else {
      buf.writeln('<path fill-rule="evenodd" fill="$extFill" d="M ${_f(ox)},${_f(oy)} h ${_f(s)} v ${_f(s)} h ${_f(-s)} Z M ${_f(ox + t)},${_f(oy + t)} h ${_f(s - 2 * t)} v ${_f(s - 2 * t)} h ${_f(-(s - 2 * t))} Z"/>');
      buf.writeln('<rect x="${_f(ox + 2.1 * t)}" y="${_f(oy + 2.1 * t)}" width="${_f(s - 4.2 * t)}" height="${_f(s - 4.2 * t)}" fill="$intFill"/>');
    }
    return buf.toString();
  }

  static bool _isEye(int r, int c, int m) =>
      (r < 7 && c < 7) || (r < 7 && c >= m - 7) || (r >= m - 7 && c < 7);

  static String _hex(Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static String _f(double v) => v.toStringAsFixed(2);

  static String _linearGradientDef(String id, Color c1, Color c2, String dir, double span) {
    double x1 = 0, y1 = 0, x2 = 0, y2 = span;
    if (dir == 'Horizontal') {
      x2 = span;
      y2 = 0;
    } else if (dir == 'Diagonal') {
      x2 = span;
      y2 = span;
    }
    return '<linearGradient id="$id" gradientUnits="userSpaceOnUse" '
        'x1="${_f(x1)}" y1="${_f(y1)}" x2="${_f(x2)}" y2="${_f(y2)}">\n'
        '  <stop offset="0%" stop-color="${_hex(c1)}"/>\n'
        '  <stop offset="100%" stop-color="${_hex(c2)}"/>\n'
        '</linearGradient>\n';
  }
}

enum EyeKind { rect, circle, diamond }
