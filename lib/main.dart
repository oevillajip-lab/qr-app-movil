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
  // Controladores para los campos
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  final TextEditingController _c3 = TextEditingController();
  
  String _qrType = "Sitio Web (URL)";
  String _selectedStyle = "Liquid Pro (Gusano)";
  File? _logoFile;
  Uint8List? _resultImage;
  bool _loading = false;

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  // Lógica exacta de tu código V53 para armar los textos
  String _buildDataString() {
    String v1 = _c1.text; String v2 = _c2.text; String v3 = _c3.text;
    if (_qrType == "Sitio Web (URL)") return v1;
    if (_qrType == "Red WiFi") return "WIFI:T:WPA;S:$v1;P:$v2;;";
    if (_qrType == "WhatsApp") return "https://wa.me/$v1?text=${Uri.encodeComponent(v2)}";
    if (_qrType == "VCard (Contacto)") return "BEGIN:VCARD\nVERSION:3.0\nFN:$v1\nORG:Comagro\nTEL:$v2\nEMAIL:$v3\nEND:VCARD";
    return v1;
  }

  Future<void> _generate() async {
    if (_c1.text.isEmpty) return;
    setState(() { _loading = true; _resultImage = null; });
    
    var request = http.MultipartRequest('POST', Uri.parse('https://qr-motor-v53.onrender.com/generate'));
    request.fields['texto'] = _buildDataString();
    request.fields['estilo'] = _selectedStyle;
    
    if (_logoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('logo', _logoFile!.path));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) setState(() => _resultImage = response.bodyBytes);
    } catch (e) { print(e); }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("COMAGRO QR V53"), backgroundColor: Color(0xFF1A237E)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _qrType,
              items: ["Sitio Web (URL)", "Red WiFi", "WhatsApp", "VCard (Contacto)", "Texto Libre"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() { _qrType = v!; _c1.clear(); _c2.clear(); _c3.clear(); }),
              decoration: InputDecoration(labelText: "Tipo de Contenido", border: OutlineInputBorder()),
            ),
            SizedBox(height: 15),
            TextField(controller: _c1, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Nombre Red (SSID)" : "Dato Principal", border: OutlineInputBorder())),
            if (_qrType == "Red WiFi" || _qrType == "WhatsApp" || _qrType == "VCard (Contacto)") ...[
              SizedBox(height: 10),
              TextField(controller: _c2, decoration: InputDecoration(labelText: _qrType == "Red WiFi" ? "Contraseña" : "Dato Secundario", border: OutlineInputBorder())),
            ],
            if (_qrType == "VCard (Contacto)") ...[
              SizedBox(height: 10),
              TextField(controller: _c3, decoration: InputDecoration(labelText: "Correo", border: OutlineInputBorder())),
            ],
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: ["Normal (Cuadrado)", "Liquid Pro (Gusano)", "Circular (Puntos)"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedStyle = v!),
              decoration: InputDecoration(labelText: "Estilo Visual", border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _pickLogo, icon: Icon(Icons.image), label: Text(_logoFile == null ? "Seleccionar Logo" : "Logo Cargado ✅")),
            SizedBox(height: 30),
            _loading ? CircularProgressIndicator() : ElevatedButton(
              onPressed: _generate, 
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60), backgroundColor: Colors.green[700]),
              child: Text("GENERAR QR NATIVO", style: TextStyle(color: Colors.white, fontSize: 18))
            ),
            if (_resultImage != null) Padding(padding: EdgeInsets.only(top: 25), child: Image.memory(_resultImage!)),
          ],
        ),
      ),
    );
  }
}
