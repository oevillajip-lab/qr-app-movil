// ============================================================
// REEMPLAZA TODA LA CLASE QrMasterPainter en tu main.dart
// ============================================================

class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final List<List<bool>> collisionMap;
  final double auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;

  QrMasterPainter({
    required this.data,
    required this.estilo,
    required this.collisionMap,
    required this.auraSize,
    required this.qrC1,
    required this.qrC2,
    required this.qrMode,
    required this.qrDir,
    required this.customEyes,
    required this.eyeExt,
    required this.eyeInt,
  });

  // ── Zonas fijas de los 3 "ojos" del QR (en unidades de módulo) ──
  bool _isEyeModule(int r, int c, int modules) {
    return (r < 7 && c < 7) ||
        (r < 7 && c >= modules - 7) ||
        (r >= modules - 7 && c < 7);
  }

  // ── ¿Este módulo colisiona con el logo + aura? ──────────────────
  // Trabaja 100% en espacio de módulos normalizado [0..1].
  bool _hitsLogo(int r, int c, int modules) {
    if (collisionMap.isEmpty) return false;

    // Tamaño del logo en fracción del QR total (65px de 270px ≈ 0.2407)
    const double logoFrac = 65.0 / 270.0;
    final double logoStart = (1.0 - logoFrac) / 2.0; // ~0.3796
    final double logoEnd = logoStart + logoFrac;      // ~0.6204

    final int mapSize = collisionMap.length; // 100

    // Centro del módulo en espacio normalizado
    final double nx = (c + 0.5) / modules;
    final double ny = (r + 0.5) / modules;

    // Convertir a coordenadas dentro del logo [-logoFrac/2 .. logoFrac/2]
    final double relX = (nx - logoStart) / logoFrac;
    final double relY = (ny - logoStart) / logoFrac;

    // Margen de aura en unidades del mapa de colisión
    // auraSize va de 1..10; lo escalamos a módulos del mapa
    final double auraFrac = auraSize / modules; // margen en espacio normalizado
    final double auraInMap = (auraFrac / logoFrac) * mapSize;
    final int auraInt = auraInMap.ceil().clamp(1, 8);

    // Rango de píxeles del mapa a revisar
    final int mapX = (relX * mapSize).round();
    final int mapY = (relY * mapSize).round();

    for (int dy = -auraInt; dy <= auraInt; dy++) {
      for (int dx = -auraInt; dx <= auraInt; dx++) {
        final int ny2 = mapY + dy;
        final int nx2 = mapX + dx;
        if (ny2 >= 0 && ny2 < mapSize && nx2 >= 0 && nx2 < mapSize) {
          if (collisionMap[ny2][nx2]) return true;
        }
      }
    }
    return false;
  }

  // ── Sin logo: excluir zona central cuadrada simple ───────────────
  bool _hitsCenter(int r, int c, int modules) {
    // Reservar zona 5x5 módulos en el centro para que el logo pueda verse
    final int center = modules ~/ 2;
    const int half = 3;
    return r >= center - half &&
        r <= center + half &&
        c >= center - half &&
        c <= center + half;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;

    // ── Paint con gradiente o sólido ────────────────────────────────
    final paint = Paint()..isAntiAlias = true;
    ui.Shader? gradShader;

    if (qrMode != "Sólido (Un Color)") {
      Alignment beg = Alignment.topCenter;
      Alignment end = Alignment.bottomCenter;
      if (qrDir == "Horizontal") {
        beg = Alignment.centerLeft;
        end = Alignment.centerRight;
      }
      if (qrDir == "Diagonal") {
        beg = Alignment.topLeft;
        end = Alignment.bottomRight;
      }
      gradShader = ui.Gradient.linear(
        Offset(size.width * (beg.x + 1) / 2, size.height * (beg.y + 1) / 2),
        Offset(size.width * (end.x + 1) / 2, size.height * (end.y + 1) / 2),
        [qrC1, qrC2],
      );
      paint.shader = gradShader;
    } else {
      paint.color = qrC1;
    }

    // ── Dibujar módulos ─────────────────────────────────────────────
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (!qrImage.isDark(r, c)) continue;

        // Saltar ojos (se dibujan aparte con estilo especial)
        if (_isEyeModule(r, c, modules) && estilo != "Normal (Cuadrado)") continue;

        // Saltar módulos que colisionan con el logo
        if (collisionMap.isNotEmpty) {
          if (_hitsLogo(r, c, modules)) continue;
        } else {
          // Sin logo: no excluir nada (o puedes activar _hitsCenter si quieres)
        }

        final double x = c * tileSize;
        final double y = r * tileSize;

        _drawModule(canvas, paint, x, y, tileSize, r, c, modules, qrImage);
      }
    }

    // ── Dibujar ojos ────────────────────────────────────────────────
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;

    if (customEyes) {
      pE.color = eyeExt;
      pI.color = eyeInt;
    } else {
      if (gradShader != null) {
        pE.shader = gradShader;
        pI.shader = gradShader;
      } else {
        pE.color = qrC1;
        pI.color = qrC1;
      }
    }

    final bool circEyes = estilo.contains("Puntos");
    _drawEye(canvas, 0, 0, tileSize, pE, pI, circEyes);
    _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, pE, pI, circEyes);
    _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, pE, pI, circEyes);
  }

  void _drawModule(Canvas canvas, Paint paint, double x, double y,
      double tileSize, int r, int c, int modules, QrImage qrImage) {
    if (estilo.contains("Gusano")) {
      // Módulo base redondeado
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 0.5, y + 0.5, tileSize - 0.5, tileSize - 0.5),
          Radius.circular(tileSize * 0.35),
        ),
        paint,
      );
      // Conexión derecha
      if (c + 1 < modules && qrImage.isDark(r, c + 1)) {
        canvas.drawRect(
          Rect.fromLTWH(x + tileSize / 2, y + 0.5, tileSize, tileSize - 0.5),
          paint,
        );
      }
      // Conexión abajo
      if (r + 1 < modules && qrImage.isDark(r + 1, c)) {
        canvas.drawRect(
          Rect.fromLTWH(x + 0.5, y + tileSize / 2, tileSize - 0.5, tileSize),
          paint,
        );
      }
    } else if (estilo.contains("Barras")) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + tileSize * 0.1, y, tileSize * 0.8, tileSize + 0.5),
          Radius.circular(tileSize * 0.3),
        ),
        paint,
      );
      if (r + 1 < modules && qrImage.isDark(r + 1, c)) {
        canvas.drawRect(
          Rect.fromLTWH(
              x + tileSize * 0.1, y + tileSize / 2, tileSize * 0.8, tileSize),
          paint,
        );
      }
    } else if (estilo.contains("Puntos")) {
      canvas.drawCircle(
        Offset(x + tileSize / 2, y + tileSize / 2),
        tileSize * 0.45,
        paint,
      );
    } else {
      // Normal cuadrado
      canvas.drawRect(
        Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3),
        paint,
      );
    }
  }

  void _drawEye(Canvas canvas, double x, double y, double t, Paint pE,
      Paint pI, bool circ) {
    double s = 7 * t;
    if (circ) {
      canvas.drawPath(
        Path()
          ..addOval(Rect.fromLTWH(x, y, s, s))
          ..addOval(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))
          ..fillType = PathFillType.evenOdd,
        pE,
      );
      canvas.drawOval(
        Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.2 * t),
        pI,
      );
    } else {
      canvas.drawPath(
        Path()
          ..addRect(Rect.fromLTWH(x, y, s, s))
          ..addRect(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))
          ..fillType = PathFillType.evenOdd,
        pE,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.4 * t),
        pI,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
}
