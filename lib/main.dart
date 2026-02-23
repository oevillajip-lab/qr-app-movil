import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';

void main() => runApp(MaterialApp(home: QRApp(), debugShowCheckedModeBanner: false));

class QRApp extends StatefulWidget {
  @override
  _QRAppState createState() => _QRAppState();
}

class _QRAppState extends State<QRApp> {
  final TextEditingController _mainController = TextEditingController();
  final TextEditingController _extraController = TextEditingController(); // Para WiFi pass o Apellido
  String _qrType = "Sitio Web (URL)";
  String _selectedStyle = "Liquid Pro (Gusano)";
  File? _logoFile;
  Uint8List? _resultImage;
  bool _loading = false;

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  String _buildDataString() {
    String val = _mainController.text;
    if (_qrType == "Red WiFi") return "WIFI:T:WPA;S:$val;P:${_extraController.text};;";
    if (_qrType == "WhatsApp") return "https://wa.me/$val";
    return val;
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    var request = http.MultipartRequest('POST', Uri.parse('https://qr-motor-v53.onrender.com/generate'));
    request.fields['texto'] = _buildDataString();
    request.fields['estilo'] = _selectedStyle;
    if (_logoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('logo', _logoFile!.path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      setState(() => _resultImage = response.bodyBytes);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("COMAGRO QR V53"), backgroundColor: Colors.indigo),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _qrType,
              items: ["Sitio Web (URL)", "Red WiFi", "WhatsApp", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _qrType = v!),
              decoration: InputDecoration(labelText: "Tipo de QR"),
            ),
            TextField(controller: _mainController, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Nombre Red (SSID)" : "Contenido")),
            if (_qrType == "Red WiFi") TextField(controller: _extraController, decoration: InputDecoration(labelText: "Contraseña WiFi")),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Circular (Puntos)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedStyle = v!),
              decoration: InputDecoration(labelText: "Estilo Visual"),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _pickLogo, icon: Icon(Icons.image), label: Text(_logoFile == null ? "Subir Logo" : "Logo Seleccionado ✅")),
            SizedBox(height: 30),
            _loading ? CircularProgressIndicator() : ElevatedButton(
              onPressed: _generate, 
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.green),
              child: Text("GENERAR QR V53", style: TextStyle(color: Colors.white))
            ),
            if (_resultImage != null) Padding(padding: EdgeInsets.only(top: 20), child: Image.memory(_resultImage!)),
          ],
        ),
      ),
    );
  }
}
