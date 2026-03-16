// ═══════════════════════════════════════════════════════════════════
// qr_svg_exporter.dart
// Generador SVG vectorial para QR+Logo
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert' show base64Encode;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Color;
import 'package:qr/qr.dart';

class QrSvgExporter {
  QrSvgExporter._();

  // ── Punto de entrada ─────────────────────────────────────────────
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
    Uint8List? logoBytes,
    double logoSizeFrac = 0.0,
    double logoAuraModules = 0.0,
    double size = 1024,
  }) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    final qr = QrImage(qrCode);
    final int m = qr.moduleCount;
    final double t = size / m;

    // ── Quiet-zone padding (igual que PNG) ──────────────────────────
    final bool hasBg = bgMode != "Transparente";
    final double pad = hasBg ? size * 0.078125 : 0.0; // ~80/1024
    final double totalSize = size + 2 * pad;
    final double cornerRadius = pad * 0.9;

    final buf = StringBuffer();

    // ── Cabecera SVG ────────────────────────────────────────────────
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="${_f(totalSize)}" height="${_f(totalSize)}" '
        'viewBox="0 0 ${_f(totalSize)} ${_f(totalSize)}">');

    // ── Definiciones ────────────────────────────────────────────────
    buf.writeln('<defs>');
    if (qrMode == "Degradado Custom") {
      // Degradado QR relativo al área QR (size × size), no al canvas total
      buf.write(_linearGradientDef('qrGrad', qrC1, qrC2, qrDir, size));
    }
    if (bgMode == "Degradado") {
      buf.write(_linearGradientDef('bgGrad', bgC1, bgC2, bgGradDir, totalSize));
    }
    buf.writeln('</defs>');

    // ── Fondo con bordes redondeados ────────────────────────────────
    if (hasBg) {
      final String fill;
      if (bgMode == "Degradado") {
        fill = 'url(#bgGrad)';
      } else if (bgMode == "Sólido (Color)") {
        fill = _hex(bgC1);
      } else {
        fill = '#ffffff';
      }
      if (cornerRadius > 0) {
        buf.writeln('<rect width="${_f(totalSize)}" height="${_f(totalSize)}" '
            'rx="${_f(cornerRadius)}" ry="${_f(cornerRadius)}" fill="$fill"/>');
      } else {
        buf.writeln('<rect width="${_f(totalSize)}" height="${_f(totalSize)}" fill="$fill"/>');
      }
    }

    // ── Todo el contenido QR se desplaza pad,pad ────────────────────
    if (pad > 0) buf.writeln('<g transform="translate(${_f(pad)},${_f(pad)})">');

    // ── Fill del QR ─────────────────────────────────────────────────
    final String qrFill = qrMode == "Degradado Custom"
        ? 'url(#qrGrad)'
        : _hex(qrC1);

    final bool isSplitStyle = estilo.contains("Split");
    final bool isShapeStyle = estilo.contains("Forma") || estilo.contains("Mapa");

    final String effectiveStyle = isShapeStyle
        ? (mapSubStyle ?? "Liquid Pro (Gusano)")
        : isSplitStyle
            ? (advSubStyle ?? "Liquid Pro (Gusano)")
            : estilo;

    final bool isLiquid =
        effectiveStyle.contains("Gusano") || effectiveStyle.contains("Liquid");
    final bool isBars = effectiveStyle.contains("Barras");
    final bool isDots = effectiveStyle.contains("Puntos");
    final bool isDiamonds =
        effectiveStyle.contains("Diamantes") || effectiveStyle.contains("Rombos");

    final double effectiveLogoFrac =
        (logoBytes != null && logoSizeFrac > 0) ? logoSizeFrac : 0.0;
    final double effectiveAuraModules =
        (logoBytes != null && logoSizeFrac > 0) ? logoAuraModules : 0.0;

    // ── Módulos (sin ojos) ──────────────────────────────────────────
    if (isLiquid) {
      buf.write(_drawLiquid(qr, m, t, qrFill, size,
          logoSizeFrac: effectiveLogoFrac, logoAuraModules: effectiveAuraModules));
    } else if (isBars) {
      buf.write(_drawBars(qr, m, t, qrFill,
          logoSizeFrac: effectiveLogoFrac, logoAuraModules: effectiveAuraModules));
    } else if (isDots) {
      buf.write(_drawDots(qr, m, t, qrFill,
          logoSizeFrac: effectiveLogoFrac, logoAuraModules: effectiveAuraModules));
    } else if (isDiamonds) {
      buf.write(_drawDiamonds(qr, m, t, qrFill,
          logoSizeFrac: effectiveLogoFrac, logoAuraModules: effectiveAuraModules));
    } else {
      buf.write(_drawSquares(qr, m, t, qrFill,
          logoSizeFrac: effectiveLogoFrac, logoAuraModules: effectiveAuraModules));
    }

    // ── Ojos ────────────────────────────────────────────────────────
    final String extFill = customEyes ? _hex(eyeExt) : qrFill;
    final String intFill = customEyes ? _hex(eyeInt) : qrFill;

    final bool eyeCircle = isDots;
    final bool eyeDiamond = isDiamonds;

    buf.write(_eye(0,       0,       t, extFill, intFill, eyeCircle, eyeDiamond));
    buf.write(_eye((m-7)*t, 0,       t, extFill, intFill, eyeCircle, eyeDiamond));
    buf.write(_eye(0,       (m-7)*t, t, extFill, intFill, eyeCircle, eyeDiamond));

    // ── Logo centrado ────────────────────────────────────────────────
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

    if (pad > 0) buf.writeln('</g>');
    buf.writeln('</svg>');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS DE MÓDULOS
  // ═══════════════════════════════════════════════════════════════

  static String _drawSquares(QrImage qr, int m, double t, String fill,
      {double logoSizeFrac = 0.0, double logoAuraModules = 0.0}) {
    final buf = StringBuffer();
    buf.writeln('<g fill="$fill">');
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c)) continue;
        if (_isEye(r, c, m)) continue;
        if (_isReservedCenterModule(r, c, m,
            logoSizeFrac: logoSizeFrac, logoAuraModules: logoAuraModules)) continue;
        final double x = c * t, y = r * t;
        buf.writeln('  <rect x="${_f(x)}" y="${_f(y)}" '
            'width="${_f(t)}" height="${_f(t)}"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  static String _drawLiquid(QrImage qr, int m, double t, String fill, double size,
      {double logoSizeFrac = 0.0, double logoAuraModules = 0.0}) {
    final segs = StringBuffer();

    bool ok(int r, int c) {
      if (r < 0 || r >= m || c < 0 || c >= m) return false;
      if (!qr.isDark(r, c)) return false;
      if (_isEye(r, c, m)) return false;
      if (_isReservedCenterModule(
        r,
        c,
        m,
        logoSizeFrac: logoSizeFrac,
        logoAuraModules: logoAuraModules,
      )) {
        return false;
      }
      return true;
    }

    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!ok(r, c)) continue;
        final double cx = c * t + t / 2;
        final double cy = r * t + t / 2;
        segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy)} ');
        if (ok(r, c + 1)) {
          segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx + t)} ${_f(cy)} ');
        }
        if (ok(r + 1, c)) {
          segs.write('M ${_f(cx)} ${_f(cy)} L ${_f(cx)} ${_f(cy + t)} ');
        }
      }
    }

    final sw = _f(t);
    return '<path d="${segs.toString().trim()}" '
        'stroke="$fill" stroke-width="$sw" '
        'stroke-linecap="round" stroke-linejoin="round" fill="none"/>\n';
  }

  // ── Barras verticales ───────────────────────────────────────────
    static String _drawBars(
    QrImage qr,
    int m,
    double t,
    String fill, {
    double logoSizeFrac = 0.0,
    double logoAuraModules = 0.0,
  }) {
    final buf = StringBuffer();
    final drawn = List.generate(m, (_) => List.filled(m, false));
    buf.writeln('<g fill="$fill">');

    bool reserved(int r, int c) => _isReservedCenterModule(
          r,
          c,
          m,
          logoSizeFrac: logoSizeFrac,
          logoAuraModules: logoAuraModules,
        );

    for (int c = 0; c < m; c++) {
      for (int r = 0; r < m; r++) {
        if (drawn[r][c]) continue;
        if (!qr.isDark(r, c)) continue;
        if (_isEye(r, c, m)) continue;
        if (reserved(r, c)) continue;

        int er = r;
        while (er + 1 < m &&
            qr.isDark(er + 1, c) &&
            !_isEye(er + 1, c, m) &&
            !drawn[er + 1][c] &&
            !reserved(er + 1, c)) {
          er++;
        }

        for (int k = r; k <= er; k++) {
          drawn[k][c] = true;
        }

        final double x = c * t + t * 0.1;
        final double y = r * t;
        final double w = t * 0.8;
        final double h = (er - r + 1) * t;
        final double rx = t * 0.38;

        buf.writeln('  <rect x="${_f(x)}" y="${_f(y)}" '
            'width="${_f(w)}" height="${_f(h)}" '
            'rx="${_f(rx)}" ry="${_f(rx)}"/>');
      }
    }

    buf.writeln('</g>');
    return buf.toString();
  }
  // ── Circular / Puntos ───────────────────────────────────────────
    static String _drawDots(
    QrImage qr,
    int m,
    double t,
    String fill, {
    double logoSizeFrac = 0.0,
    double logoAuraModules = 0.0,
  }) {
    final buf = StringBuffer();
    buf.writeln('<g fill="$fill">');
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c)) continue;
        if (_isEye(r, c, m)) continue;
        if (_isReservedCenterModule(
          r,
          c,
          m,
          logoSizeFrac: logoSizeFrac,
          logoAuraModules: logoAuraModules,
        )) {
          continue;
        }
        final double h = ((r * 13 + c * 29) % 100) / 100.0;
        final double cx = c * t + t / 2;
        final double cy = r * t + t / 2;
        // Max radius = 0.45t — keeps circles inside cell, prevents edge clipping
        final double rad = t * (0.33 + 0.12 * h);
        buf.writeln('  <circle cx="${_f(cx)}" cy="${_f(cy)}" r="${_f(rad)}"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  // ── Diamantes / Rombos ──────────────────────────────────────────
    static String _drawDiamonds(
    QrImage qr,
    int m,
    double t,
    String fill, {
    double logoSizeFrac = 0.0,
    double logoAuraModules = 0.0,
  }) {
    final buf = StringBuffer();
    buf.writeln('<g fill="$fill">');
    for (int r = 0; r < m; r++) {
      for (int c = 0; c < m; c++) {
        if (!qr.isDark(r, c)) continue;
        if (_isEye(r, c, m)) continue;
        if (_isReservedCenterModule(
          r,
          c,
          m,
          logoSizeFrac: logoSizeFrac,
          logoAuraModules: logoAuraModules,
        )) {
          continue;
        }
        final double h = ((r * 17 + c * 31) % 100) / 100.0;
        final double sc = 0.65 + 0.22 * h;
        final double x = c * t, y = r * t;
        final double off = t * (1 - sc) / 2;
        final double cx = x + t / 2, cy = y + t / 2;
        final String d =
            'M ${_f(cx)},${_f(y + off)} '
            'L ${_f(x + t - off)},${_f(cy)} '
            'L ${_f(cx)},${_f(y + t - off)} '
            'L ${_f(x + off)},${_f(cy)} Z';
        buf.writeln('  <path d="$d"/>');
      }
    }
    buf.writeln('</g>');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // OJOS — usa fill-rule="evenodd" para que el hueco sea transparente
  // (igual que el painter PNG, que usa PathFillType.evenOdd)
  // ═══════════════════════════════════════════════════════════════
  static String _eye(double ox, double oy, double t,
      String extFill, String intFill,
      bool isCircle, bool isDiamond) {
    final buf = StringBuffer();
    final double s = 7 * t;

    if (isCircle) {
      // Anillo exterior con hueco transparente (evenodd)
      final double r0 = s / 2;
      final double r1 = (s - 2 * t) / 2;
      final double cx = ox + s / 2, cy = oy + s / 2;
      // Dos subpaths en un <path> con evenodd → el interior queda transparente
      buf.writeln('<path fill-rule="evenodd" fill="$extFill" d="'
          'M ${_f(cx - r0)},${_f(cy)} '
          'a ${_f(r0)},${_f(r0)} 0 1,0 ${_f(r0 * 2)},0 '
          'a ${_f(r0)},${_f(r0)} 0 1,0 ${_f(-r0 * 2)},0 Z '
          'M ${_f(cx - r1)},${_f(cy)} '
          'a ${_f(r1)},${_f(r1)} 0 1,0 ${_f(r1 * 2)},0 '
          'a ${_f(r1)},${_f(r1)} 0 1,0 ${_f(-r1 * 2)},0 Z"/>');
      // Punto interior
      final double ri = (s - 4.2 * t) / 2;
      buf.writeln('<circle cx="${_f(cx)}" cy="${_f(cy)}" '
          'r="${_f(ri)}" fill="$intFill"/>');

    } else if (isDiamond) {
      final double cx = ox + 3.5 * t, cy = oy + 3.5 * t;
      // Marco exterior rombo + hueco interior en un path evenodd
      buf.writeln('<path fill-rule="evenodd" fill="$extFill" d="'
          'M ${_f(cx)},${_f(oy)} '
          'L ${_f(ox + 7 * t)},${_f(cy)} '
          'L ${_f(cx)},${_f(oy + 7 * t)} '
          'L ${_f(ox)},${_f(cy)} Z '
          'M ${_f(cx)},${_f(oy + 1.2 * t)} '
          'L ${_f(ox + 5.8 * t)},${_f(cy)} '
          'L ${_f(cx)},${_f(oy + 5.8 * t)} '
          'L ${_f(ox + 1.2 * t)},${_f(cy)} Z"/>');
      // Rombo interior
      buf.writeln('<path d="'
          'M ${_f(cx)},${_f(oy + 2.2 * t)} '
          'L ${_f(ox + 4.8 * t)},${_f(cy)} '
          'L ${_f(cx)},${_f(oy + 4.8 * t)} '
          'L ${_f(ox + 2.2 * t)},${_f(cy)} Z" '
          'fill="$intFill"/>');

    } else {
      // Cuadrado: borde exterior + hueco interior en un path evenodd
      buf.writeln('<path fill-rule="evenodd" fill="$extFill" d="'
          'M ${_f(ox)},${_f(oy)} '
          'h ${_f(s)} v ${_f(s)} h ${_f(-s)} Z '
          'M ${_f(ox + t)},${_f(oy + t)} '
          'h ${_f(s - 2 * t)} v ${_f(s - 2 * t)} h ${_f(-(s - 2 * t))} Z"/>');
      // Cuadrado interior (punto)
      buf.writeln('<rect x="${_f(ox + 2.1 * t)}" y="${_f(oy + 2.1 * t)}" '
          'width="${_f(s - 4.2 * t)}" height="${_f(s - 4.2 * t)}" '
          'fill="$intFill"/>');
    }

    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════

   static bool _isEye(int r, int c, int m) =>
      (r < 7 && c < 7) ||
      (r < 7 && c >= m - 7) ||
      (r >= m - 7 && c < 7);

  static bool _isReservedCenterModule(
    int r,
    int c,
    int m, {
    required double logoSizeFrac,
    required double logoAuraModules,
  }) {
    if (logoSizeFrac <= 0) return false;

    final double nx = (c + 0.5) / m;
    final double ny = (r + 0.5) / m;

    final double halfLogo = logoSizeFrac / 2.0;
    final double auraFrac = logoAuraModules / m;
    final double half = halfLogo + auraFrac;

    final double minX = 0.5 - half;
    final double maxX = 0.5 + half;
    final double minY = 0.5 - half;
    final double maxY = 0.5 + half;

    return nx >= minX && nx <= maxX && ny >= minY && ny <= maxY;
  }

  // Color a hex SVG
  static String _hex(Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  // Float con 2 decimales
  static String _f(double v) => v.toStringAsFixed(2);

  // Definición de degradado lineal SVG
  static String _linearGradientDef(
      String id, Color c1, Color c2, String dir, double size) {
    double x1 = 0, y1 = 0, x2 = 0, y2 = 1;
    if (dir == "Horizontal") { x1 = 0; y1 = 0; x2 = 1; y2 = 0; }
    if (dir == "Diagonal")   { x1 = 0; y1 = 0; x2 = 1; y2 = 1; }
    if (dir == "Vertical")   { x1 = 0; y1 = 0; x2 = 0; y2 = 1; }
    return '<linearGradient id="$id" '
        'x1="${_f(x1)}" y1="${_f(y1)}" x2="${_f(x2)}" y2="${_f(y2)}">\n'
        '  <stop offset="0%" stop-color="${_hex(c1)}"/>\n'
        '  <stop offset="100%" stop-color="${_hex(c2)}"/>\n'
        '</linearGradient>\n';
  }
}
