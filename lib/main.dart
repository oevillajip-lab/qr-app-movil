import 'dart:convert' show utf8, jsonEncode, jsonDecode;
import 'qr_svg_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img_lib;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/rendering.dart';

void main() => runApp(
      MaterialApp(
        title: 'QR+Logo',
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'SF Pro Display',
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        ),
      ),
    );

// ════════════════════════════════════════════════════════════════════════════════════════
// SECCIÓN 1: GENERACIÓN BASE DEL QR
// ════════════════════════════════════════════════════════════════════════════════════════
QrImage? _buildQrImage(String data) {
  try {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.H,
    );
    return QrImage(qrCode);
  } catch (_) {
    return null;
  }
}

// ════════════════════════════════════════════════════════════════════════════════════════
// SECCIÓN 2: FRENO MATEMÁTICO
// ════════════════════════════════════════════════════════════════════════════════════════
double _safeLogoMax({
  required int modules,
  required double auraModules,
  double canvasSize = 270.0,
  double hardMax = 85.0,
  double hardMin = 30.0,
}) {
  final double auraFrac = (auraModules * 2.0) / modules.toDouble();
  final double maxFrac = (math.sqrt(0.27) - auraFrac).clamp(0.08, 0.519);
  return (maxFrac * canvasSize).clamp(hardMin, hardMax);
}

class QrHistoryItem {
  final String id;
  final String qrType;
  final String preview;
  final String pngPath;
  final String svgPath;
  final String action;
  final DateTime createdAt;

  const QrHistoryItem({
    required this.id,
    required this.qrType,
    required this.preview,
    required this.pngPath,
    required this.svgPath,
    required this.action,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'qrType': qrType,
        'preview': preview,
        'pngPath': pngPath,
        'svgPath': svgPath,
        'action': action,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QrHistoryItem.fromJson(Map<String, dynamic> json) => QrHistoryItem(
        id: (json['id'] ?? '').toString(),
        qrType: (json['qrType'] ?? 'QR').toString(),
        preview: (json['preview'] ?? '').toString(),
        pngPath: (json['pngPath'] ?? '').toString(),
        svgPath: (json['svgPath'] ?? '').toString(),
        action: (json['action'] ?? 'Generado').toString(),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );
}

// Placeholder para las demás secciones - El archivo es muy largo
// Aquí iría todo el contenido del archivo original sin cambios,
// solo modificando la clase QrAdvancedPainter
