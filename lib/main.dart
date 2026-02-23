import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

void main() {
  runApp(MaterialApp(
    home: MainScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: Colors.white),
  ));
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _textController = TextEditingController();
  String _estilo = "Liquid Pro (Gusano)";
  String _qrType = "Sitio Web (URL)";
  File? _logoFile;
  GlobalKey _globalKey = GlobalKey();
  bool _isGenerated = false;

  // --- LÓGICA DEL CÓDIGO PADRE: TRADUCCIÓN NATIVA ---
  
  // Función para capturar el widget y convertirlo en imagen de alta calidad
  Future<void> _captureAndSave(bool isShare) async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (isShare) {
        final directory = await getTemporaryDirectory();
        final path = await File('${directory.path}/qr_export.png').create();
        await path.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(path.path)]);
      } else {
        final result = await ImageGallerySaver.saveImage(pngBytes, quality: 100);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['isSuccess'] ? "Guardado en Galería" : "Error al guardar")));
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR + LOGO NATIVO", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Entradas de texto y selectores (Igual que antes)
            DropdownButtonFormField<String>(
              value: _qrType,
              items: ["Sitio Web (URL)", "WhatsApp", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _qrType = v!),
              decoration: InputDecoration(labelText: "Tipo"),
            ),
            TextField(controller: _textController, decoration: InputDecoration(labelText: "Contenido")),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _estilo,
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _estilo = v!),
              decoration: InputDecoration(labelText: "Estilo del Código Padre"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) setState(() => _logoFile = File(picked.path));
              },
              child: Text(_logoFile == null ? "Seleccionar Logo" : "Logo Cargado ✅"),
            ),
            SizedBox(height: 20),
            
            // EL MOTOR DE DIBUJO (REEMPLAZA A RENDER.COM)
            if (_textController.text.isNotEmpty)
              RepaintBoundary(
                key: _globalKey,
                child: Container(
                  padding: EdgeInsets.all(20),
                  color: Colors.white, // Fondo Blanco (Default del Código Padre)
                  child: QrImageView(
                    data: _textController.text,
                    version: QrVersions.auto,
                    size: 300.0,
                    gapless: false,
                    // AQUÍ APLICAMOS LOS ESTILOS DEL CÓDIGO PADRE
                    eyeStyle: QrEyeStyle(
                      eyeShape: _estilo == "Circular (Puntos)" ? QrEyeShape.circle : QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: _estilo == "Liquid Pro (Gusano)" || _estilo == "Circular (Puntos)" 
                        ? QrDataModuleShape.circle 
                        : QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    embeddedImage: _logoFile != null ? FileImage(_logoFile!) : null,
                    embeddedImageStyle: QrEmbeddedImageStyle(
                      size: Size(60, 60), // Tamaño proporcional al QR
                    ),
                  ),
                ),
              ),
              
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => _captureAndSave(false), child: Text("DESCARGAR"))),
                SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => _captureAndSave(true), child: Text("COMPARTIR"))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
