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

void main() => runApp(MaterialApp(home: MainScreen(), debugShowCheckedModeBanner: false));

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _controller = TextEditingController();
  String _estilo = "Liquid Pro (Gusano)";
  File? _logo;
  GlobalKey _qrKey = GlobalKey(); // Clave para capturar el QR como imagen
  bool _mostrarBotones = false;

  Future<void> _exportar(bool compartir) async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (compartir) {
        final dir = await getTemporaryDirectory();
        final file = await File('${dir.path}/qr.png').create();
        await file.writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        await ImageGallerySaver.saveImage(pngBytes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Guardado en Galería")));
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text("QR NATIVO", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _controller, decoration: InputDecoration(labelText: "Contenido del QR", border: OutlineInputBorder())),
            SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _estilo,
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _estilo = v!),
              decoration: InputDecoration(labelText: "Estilo"),
            ),
            SizedBox(height: 15),
            OutlinedButton(
              onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
                if (img != null) setState(() => _logo = File(img.path));
              },
              child: Text(_logo == null ? "Seleccionar Logo" : "Logo Listo ✅"),
            ),
            SizedBox(height: 20),
            
            // EL MOTOR NATIVO (Dibuja en tiempo real)
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(20),
                child: QrImageView(
                  data: _controller.text.isEmpty ? " " : _controller.text,
                  version: QrVersions.auto,
                  size: 250,
                  eyeStyle: QrEyeStyle(
                    eyeShape: _estilo == "Circular (Puntos)" ? QrEyeShape.circle : QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: _estilo == "Normal (Cuadrado)" ? QrDataModuleShape.square : QrDataModuleShape.circle,
                    color: Colors.black,
                  ),
                  embeddedImage: _logo != null ? FileImage(_logo!) : null,
                  embeddedImageStyle: QrEmbeddedImageStyle(size: Size(50, 50)),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => _exportar(false), child: Text("DESCARGAR"))),
                SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => _exportar(true), child: Text("COMPARTIR"))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
