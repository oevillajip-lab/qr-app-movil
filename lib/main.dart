import 'package:path_provider/path_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image/image.dart' as img_lib;
import 'package:share_plus/share_plus.dart'; // NUEVO: Importación para compartir
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/rendering.dart';

void main() => runApp(const MaterialApp(
@@ -43,7 +44,7 @@ class _SplashScreenState extends State<SplashScreen> {
  }
}

// ── Main Screen ───────────────────────────────────────────────────
// ── Main Screen (Con Pestañas) ────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
@@ -58,9 +59,15 @@ class _MainScreenState extends State<MainScreen> {
  final TextEditingController _c5 = TextEditingController();

  String _qrType = "Sitio Web (URL)";
  
  // Variables Básico
  String _estilo = "Liquid Pro (Gusano)";
  String _qrColorMode = "Automático (Logo)";
  String _qrGradDir = "Vertical";
  
  // Variables Avanzado
  String _estiloAvanzado = "QR Circular";

  Color _qrC1 = Colors.black;
  Color _qrC2 = const Color(0xFF1565C0);
  bool _customEyes = false;
@@ -74,7 +81,8 @@ class _MainScreenState extends State<MainScreen> {
  Uint8List? _logoBytes;
  img_lib.Image? _logoImage;
  List<List<bool>>? _outerMask; 
  double _logoSize = 65.0;
  double _logoSize = 65.0; // Tope 75 en básico
  double _logoSizeAvanzado = 200.0; // En avanzado el logo puede ser enorme
  double _auraSize = 1.0; 

  final GlobalKey _qrKey = GlobalKey();
@@ -133,15 +141,8 @@ class _MainScreenState extends State<MainScreen> {
      _logoImage = image;
      _outerMask = finalMask;
      if (_qrColorMode == "Automático (Logo)") {
        // RETOQUE 1: Forzar colores oscuros/fuertes para el C1, y el secundario para C2.
        _qrC1 = palette.darkVibrantColor?.color ?? 
                palette.darkMutedColor?.color ?? 
                palette.dominantColor?.color ?? 
                Colors.black;
        // Si no hay secundario fuerte, se repite C1 para que sea un color sólido
        _qrC2 = palette.vibrantColor?.color ?? 
                palette.lightVibrantColor?.color ?? 
                _qrC1; 
        _qrC1 = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? palette.dominantColor?.color ?? Colors.black;
        _qrC2 = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _qrC1; 
      }
    });
  }
@@ -159,8 +160,7 @@ class _MainScreenState extends State<MainScreen> {
      if (visited[y][x]) return;
      final p = src.getPixel(x, y);
      if (p.r > thresh && p.g > thresh && p.b > thresh) {
        visited[y][x] = true;
        queue.add([x, y]);
        visited[y][x] = true; queue.add([x, y]);
      }
    }

@@ -169,8 +169,7 @@ class _MainScreenState extends State<MainScreen> {

    while (queue.isNotEmpty) {
      final pos = queue.removeLast();
      final int x = pos[0];
      final int y = pos[1];
      final int x = pos[0]; final int y = pos[1];
      enqueue(x + 1, y); enqueue(x - 1, y); enqueue(x, y + 1); enqueue(x, y - 1);
    }

@@ -204,26 +203,47 @@ class _MainScreenState extends State<MainScreen> {

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
            title: const Text("QR + Logo PRO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white, elevation: 0, centerTitle: true,
            bottom: const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              tabs: [Tab(text: "Básico"), Tab(text: "Avanzado")],
            )
        ),
        body: TabBarView(
          children: [
            _buildTabContent(isAdvanced: false),
            _buildTabContent(isAdvanced: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({required bool isAdvanced}) {
    final String finalData = _getFinalData();
    final bool isEmpty = finalData.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
          title: const Text("QR + Logo", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          _buildCard("1. Contenido", Column(children: [
            DropdownButtonFormField<String>(
                value: _qrType,
                items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _qrType = v!)),
            const SizedBox(height: 10),
            _buildInputs(),
          ])),
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(children: [
        _buildCard("1. Contenido", Column(children: [
          DropdownButtonFormField<String>(
              value: _qrType,
              items: ["Sitio Web (URL)", "WhatsApp", "Red WiFi", "VCard (Contacto)", "Teléfono", "E-mail", "SMS (Mensaje)", "Texto Libre"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _qrType = v!)),
          const SizedBox(height: 10),
          _buildInputs(),
        ])),

        if (!isAdvanced)
          _buildCard("2. Estilo y Color QR", Column(children: [
            DropdownButtonFormField<String>(
                value: _estilo,
@@ -236,104 +256,105 @@ class _MainScreenState extends State<MainScreen> {
            _buildColorPicker("Colores QR", _qrC1, _qrC2, (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c), isGrad: _qrColorMode != "Sólido (Un Color)"),
            if (_qrColorMode != "Sólido (Un Color)")
              DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: "Dirección Degradado"), value: _qrGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _qrGradDir = v!)),
          ])),

          _buildCard("3. Posicionamiento y Fondo", Column(children: [
            SwitchListTile(title: const Text("Personalizar Ojos"), value: _customEyes, onChanged: (v) => setState(() => _customEyes = v), contentPadding: EdgeInsets.zero),
            if (_customEyes) _buildColorPicker("Colores Ojos", _eyeExt, _eyeInt, (c) => setState(() => _eyeExt = c), (c) => setState(() => _eyeInt = c), isGrad: true),
            const Divider(),
            DropdownButtonFormField<String>(value: _bgMode, items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgMode = v!)),
            if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
              _buildColorPicker("Colores Fondo", _bgC1, _bgC2, (c) => setState(() => _bgC1 = c), (c) => setState(() => _bgC2 = c), isGrad: _bgMode == "Degradado"),
              if (_bgMode == "Degradado")
                DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: "Dirección Fondo"), value: _bgGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgGradDir = v!)),
            ]
          ])),

          _buildCard("4. Logo", Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton.icon(
                onPressed: () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (img != null) await _processLogo(File(img.path));
                },
                icon: const Icon(Icons.image),
                label: Text(_logoBytes == null ? "CARGAR LOGO" : "LOGO CARGADO ✅"),
                // RETOQUE 4: Botón Negro, letra blanca
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.black, foregroundColor: Colors.white)),
            
            // RETOQUE 1: Advertencia sobre logos blancos
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text("💡 Nota: Si su diseño es blanco, recuerde seleccionar un fondo oscuro.", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
          ]))
        else
          _buildCard("2. Estilo Avanzado", Column(children: [
            DropdownButtonFormField<String>(
                value: _estiloAvanzado,
                items: ["QR Circular", "Split Liquid (Mitades)", "Forma de Mapa (Máscara)", "Logo Fusión (Camuflaje)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _estiloAvanzado = v!)),
             _buildColorPicker("Colores Base", _qrC1, _qrC2, (c) => setState(() => _qrC1 = c), (c) => setState(() => _qrC2 = c), isGrad: true),
             const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text("⚠️ Cuidado: Forma de Mapa y Fusión requieren logos muy grandes o el QR perderá lectura.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),

            if (_logoBytes != null) ...[
              const SizedBox(height: 12),
              Text("Tamaño del logo: ${_logoSize.toInt()}px (Tope Seguro)"),
              // RETOQUE 2: Freno funcional. Tope máximo 75px.
              Slider(value: _logoSize, min: 30, max: 75, divisions: 9, activeColor: Colors.black, onChanged: (v) => setState(() => _logoSize = v)),
            ],
          ])),

        _buildCard("3. Posicionamiento y Fondo", Column(children: [
          SwitchListTile(title: const Text("Personalizar Ojos"), value: _customEyes, onChanged: (v) => setState(() => _customEyes = v), contentPadding: EdgeInsets.zero),
          if (_customEyes) _buildColorPicker("Colores Ojos", _eyeExt, _eyeInt, (c) => setState(() => _eyeExt = c), (c) => setState(() => _eyeInt = c), isGrad: true),
          const Divider(),
          DropdownButtonFormField<String>(value: _bgMode, items: ["Blanco (Default)", "Transparente", "Sólido (Color)", "Degradado"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgMode = v!)),
          if (_bgMode != "Blanco (Default)" && _bgMode != "Transparente") ...[
            _buildColorPicker("Colores Fondo", _bgC1, _bgC2, (c) => setState(() => _bgC1 = c), (c) => setState(() => _bgC2 = c), isGrad: _bgMode == "Degradado"),
            if (_bgMode == "Degradado")
              DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: "Dirección Fondo"), value: _bgGradDir, items: ["Vertical", "Horizontal", "Diagonal"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _bgGradDir = v!)),
          ]
        ])),

        _buildCard("4. Logo", Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ElevatedButton.icon(
              onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) await _processLogo(File(img.path));
              },
              icon: const Icon(Icons.image),
              label: Text(_logoBytes == null ? "CARGAR LOGO" : "LOGO CARGADO ✅"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.black, foregroundColor: Colors.white)),
          const Padding(padding: EdgeInsets.only(top: 8.0, bottom: 4.0), child: Text("💡 Nota: Si su diseño es blanco, seleccione un fondo oscuro.", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
          if (_logoBytes != null) ...[
            const SizedBox(height: 12),
            Text("Tamaño del logo: ${isAdvanced ? _logoSizeAvanzado.toInt() : _logoSize.toInt()}px"),
            if (!isAdvanced)
              Slider(value: _logoSize, min: 30, max: 75, divisions: 9, activeColor: Colors.black, onChanged: (v) => setState(() => _logoSize = v))
            else
              Slider(value: _logoSizeAvanzado, min: 50, max: 270, divisions: 22, activeColor: Colors.black, onChanged: (v) => setState(() => _logoSizeAvanzado = v)),
          ],
        ])),

        if (!isAdvanced)
          _buildCard("5. Ajuste de Aura (Separación QR ↔ Logo)", Column(children: [
            Text("Margen: ${_auraSize.toInt()} Nivel(es)"),
            // RETOQUE 2: Freno funcional. Tope máximo 3 niveles.
            Slider(value: _auraSize, min: 0, max: 3, divisions: 3, activeColor: Colors.black, onChanged: (v) => setState(() => _auraSize = v)),
          ])),

          const SizedBox(height: 10),

          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(color: _bgMode == "Transparente" ? Colors.transparent : (_bgMode == "Sólido (Color)" ? _bgC1 : Colors.white), gradient: _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null),
              child: Center(
                child: isEmpty
                    ? const Text("Esperando contenido...", style: TextStyle(color: Colors.grey))
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(270, 270),
                            painter: QrMasterPainter(
                              data: finalData, estilo: _estilo, logoImage: _logoImage, outerMask: _outerMask, logoSize: _logoSize, auraSize: _auraSize,
                              qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                            ),
        const SizedBox(height: 10),

        RepaintBoundary(
          key: _qrKey,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(color: _bgMode == "Transparente" ? Colors.transparent : (_bgMode == "Sólido (Color)" ? _bgC1 : Colors.white), gradient: _bgMode == "Degradado" ? _getGrad(_bgC1, _bgC2, _bgGradDir) : null),
            child: Center(
              child: isEmpty
                  ? const Text("Esperando contenido...", style: TextStyle(color: Colors.grey))
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(270, 270),
                          painter: isAdvanced 
                            ? QrAdvancedPainter(
                                data: finalData, estiloAvanzado: _estiloAvanzado, logoImage: _logoImage, outerMask: _outerMask, logoSize: _logoSizeAvanzado,
                                qrC1: _qrC1, qrC2: _qrC2, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                              )
                            : QrMasterPainter( // EL CÓDIGO PRO INTACTO
                                data: finalData, estilo: _estilo, logoImage: _logoImage, outerMask: _outerMask, logoSize: _logoSize, auraSize: _auraSize,
                                qrC1: _qrC1, qrC2: _qrC2, qrMode: _qrColorMode, qrDir: _qrGradDir, customEyes: _customEyes, eyeExt: _eyeExt, eyeInt: _eyeInt,
                              ),
                        ),
                        // En "Forma de Mapa", ocultamos el logo visual normal para que solo se vea el QR
                        if (_logoBytes != null && (!isAdvanced || _estiloAvanzado != "Forma de Mapa (Máscara)")) 
                          SizedBox(
                            width: isAdvanced ? _logoSizeAvanzado : _logoSize, 
                            height: isAdvanced ? _logoSizeAvanzado : _logoSize, 
                            child: Image.memory(_logoBytes!, fit: BoxFit.contain, color: isAdvanced && _estiloAvanzado == "Logo Fusión (Camuflaje)" ? Colors.white.withOpacity(0.5) : null, colorBlendMode: BlendMode.lighten)
                          ),
                          if (_logoBytes != null) SizedBox(width: _logoSize, height: _logoSize, child: Image.memory(_logoBytes!, fit: BoxFit.contain)),
                        ],
                      ),
              ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 25),
          
          // RETOQUE 3 Y 4: Botones Guardar y Compartir (Blancos y Negros)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isEmpty ? null : () => _exportar(), 
                  icon: const Icon(Icons.save_alt),
                  label: const Text("GUARDAR"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60))
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isEmpty ? null : () => _compartir(), 
                  icon: const Icon(Icons.share),
                  label: const Text("COMPARTIR"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60))
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ]),
      ),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            Expanded(child: ElevatedButton.icon(onPressed: isEmpty ? null : () => _exportar(), icon: const Icon(Icons.save_alt), label: const Text("GUARDAR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60)))),
            const SizedBox(width: 15),
            Expanded(child: ElevatedButton.icon(onPressed: isEmpty ? null : () => _compartir(), icon: const Icon(Icons.share), label: const Text("COMPARTIR"), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60)))),
          ],
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

@@ -346,13 +367,7 @@ class _MainScreenState extends State<MainScreen> {

  Widget _buildInputs() {
    switch (_qrType) {
      case "VCard (Contacto)":
        return Column(children: [
          Row(children: [Expanded(child: TextField(controller: _c1, decoration: const InputDecoration(hintText: "Nombre"), onChanged: (v) => setState(() {}))), const SizedBox(width: 5), Expanded(child: TextField(controller: _c2, decoration: const InputDecoration(hintText: "Apellido"), onChanged: (v) => setState(() {})))]),
          TextField(controller: _c3, decoration: const InputDecoration(hintText: "Empresa"), onChanged: (v) => setState(() {})),
          TextField(controller: _c4, decoration: const InputDecoration(hintText: "Teléfono"), keyboardType: TextInputType.phone, onChanged: (v) => setState(() {})),
          TextField(controller: _c5, decoration: const InputDecoration(hintText: "Email"), keyboardType: TextInputType.emailAddress, onChanged: (v) => setState(() {})),
        ]);
      case "VCard (Contacto)": return Column(children: [Row(children: [Expanded(child: TextField(controller: _c1, decoration: const InputDecoration(hintText: "Nombre"), onChanged: (v) => setState(() {}))), const SizedBox(width: 5), Expanded(child: TextField(controller: _c2, decoration: const InputDecoration(hintText: "Apellido"), onChanged: (v) => setState(() {})))]), TextField(controller: _c3, decoration: const InputDecoration(hintText: "Empresa"), onChanged: (v) => setState(() {})), TextField(controller: _c4, decoration: const InputDecoration(hintText: "Teléfono"), keyboardType: TextInputType.phone, onChanged: (v) => setState(() {})), TextField(controller: _c5, decoration: const InputDecoration(hintText: "Email"), keyboardType: TextInputType.emailAddress, onChanged: (v) => setState(() {}))]);
      case "WhatsApp":
      case "SMS (Mensaje)": return Column(children: [TextField(controller: _c1, decoration: const InputDecoration(hintText: "Número (+595...)"), keyboardType: TextInputType.phone, onChanged: (v) => setState(() {})), TextField(controller: _c2, decoration: const InputDecoration(hintText: "Mensaje"), onChanged: (v) => setState(() {}))]);
      case "Red WiFi": return Column(children: [TextField(controller: _c1, decoration: const InputDecoration(hintText: "SSID (Nombre Red)"), onChanged: (v) => setState(() {})), TextField(controller: _c2, decoration: const InputDecoration(hintText: "Contraseña"), onChanged: (v) => setState(() {}))]);
@@ -365,45 +380,20 @@ class _MainScreenState extends State<MainScreen> {
  Widget _buildColorPicker(String label, Color c1, Color c2, Function(Color) onC1, Function(Color) onC2, {bool isGrad = false}) { return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text(label), const Spacer(), _colorBtn(c1, onC1), if (isGrad) ...[const SizedBox(width: 15), _colorBtn(c2, onC2)]])); }
  Widget _colorBtn(Color current, Function(Color) onTap) { return GestureDetector(onTap: () => _showPalette(onTap), child: CircleAvatar(backgroundColor: current, radius: 20, child: Icon(Icons.colorize, size: 16, color: current == Colors.white ? Colors.black : Colors.white))); }
  void _showPalette(Function(Color) onSelect) { showDialog(context: context, builder: (ctx) => AlertDialog(content: Wrap(spacing: 12, runSpacing: 12, children: [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, const Color(0xFF1565C0), Colors.grey].map((c) => GestureDetector(onTap: () { onSelect(c); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: c, radius: 25))).toList()))); }
  
  Future<void> _exportar() async { 
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary; 
    final ui.Image image = await boundary.toImage(pixelRatio: 4.0); 
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png); 
    await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List()); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ QR Guardado"))); 
  }

  // RETOQUE 3: Función para compartir el QR generado
  Future<void> _compartir() async {
    final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/qr_generado.png').create();
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Generado con QR + Logo');
  }
  Future<void> _exportar() async { final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary; final ui.Image image = await boundary.toImage(pixelRatio: 4.0); final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png); await ImageGallerySaver.saveImage(byteData!.buffer.asUint8List()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ QR Guardado"))); }
  Future<void> _compartir() async { final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary; final ui.Image image = await boundary.toImage(pixelRatio: 4.0); final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png); final Uint8List pngBytes = byteData!.buffer.asUint8List(); final tempDir = await getTemporaryDirectory(); final file = await File('${tempDir.path}/qr_generado.png').create(); await file.writeAsBytes(pngBytes); await Share.shareXFiles([XFile(file.path)], text: 'Generado con QR + Logo'); }
}

enum EyeStyle { rect, circ, diamond }

// ── CÓDIGO PRO BÁSICO (INTACTO BAJO LLAVE) ────────────────────────
class QrMasterPainter extends CustomPainter {
  final String data, estilo, qrMode, qrDir;
  final img_lib.Image? logoImage;
  final List<List<bool>>? outerMask;
  final img_lib.Image? logoImage; final List<List<bool>>? outerMask;
  final double logoSize, auraSize;
  final bool customEyes;
  final Color qrC1, qrC2, eyeExt, eyeInt;
  final bool customEyes; final Color qrC1, qrC2, eyeExt, eyeInt;

  QrMasterPainter({
    required this.data, required this.estilo, required this.logoImage, required this.outerMask,
    required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2,
    required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt,
  });
  QrMasterPainter({required this.data, required this.estilo, required this.logoImage, required this.outerMask, required this.logoSize, required this.auraSize, required this.qrC1, required this.qrC2, required this.qrMode, required this.qrDir, required this.customEyes, required this.eyeExt, required this.eyeInt});

  bool _isEyeModule(int r, int c, int modules) => (r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7);

@@ -416,47 +406,34 @@ class QrMasterPainter extends CustomPainter {

    final paint = Paint()..isAntiAlias = true;
    ui.Shader? gradShader;

    if (qrMode != "Sólido (Un Color)") {
      Alignment beg = Alignment.topCenter; Alignment end = Alignment.bottomCenter;
      if (qrDir == "Horizontal") { beg = Alignment.centerLeft; end = Alignment.centerRight; }
      if (qrDir == "Diagonal") { beg = Alignment.topLeft; end = Alignment.bottomRight; }
      gradShader = ui.Gradient.linear(Offset(size.width * (beg.x + 1) / 2, size.height * (beg.y + 1) / 2), Offset(size.width * (end.x + 1) / 2, size.height * (end.y + 1) / 2), [qrC1, qrC2]);
      paint.shader = gradShader;
    } else {
      paint.color = qrC1;
    }
    } else { paint.color = qrC1; }

    List<List<bool>> exclusionMask = List.generate(modules, (_) => List.filled(modules, false));
    if (logoImage != null && outerMask != null) {
      final double canvasSize = 270.0;
      final double logoFrac = logoSize / canvasSize;
      final double logoStart = (1.0 - logoFrac) / 2.0;
      final double logoEnd = logoStart + logoFrac;

      final double canvasSize = 270.0; final double logoFrac = logoSize / canvasSize;
      final double logoStart = (1.0 - logoFrac) / 2.0; final double logoEnd = logoStart + logoFrac;
      List<List<bool>> baseLogoModules = List.generate(modules, (_) => List.filled(modules, false));

      for (int r = 0; r < modules; r++) {
        for (int c = 0; c < modules; c++) {
          bool hit = false;
          for (double dy = 0.2; dy <= 0.8; dy += 0.3) {
            for (double dx = 0.2; dx <= 0.8; dx += 0.3) {
              double nx = (c + dx) / modules;
              double ny = (r + dy) / modules;
              double nx = (c + dx) / modules; double ny = (r + dy) / modules;
              if (nx >= logoStart && nx <= logoEnd && ny >= logoStart && ny <= logoEnd) {
                double relX = (nx - logoStart) / logoFrac;
                double relY = (ny - logoStart) / logoFrac;
                int px = (relX * logoImage!.width).clamp(0, logoImage!.width - 1).toInt();
                int py = (relY * logoImage!.height).clamp(0, logoImage!.height - 1).toInt();
                double relX = (nx - logoStart) / logoFrac; double relY = (ny - logoStart) / logoFrac;
                int px = (relX * logoImage!.width).clamp(0, logoImage!.width - 1).toInt(); int py = (relY * logoImage!.height).clamp(0, logoImage!.height - 1).toInt();
                if (outerMask![py][px]) { hit = true; break; }
              }
            }
            if (hit) break;
          }
          if (hit) baseLogoModules[r][c] = true;
            } if (hit) break;
          } if (hit) baseLogoModules[r][c] = true;
        }
      }

      int auraRadius = auraSize.toInt();
      for (int r = 0; r < modules; r++) {
        for (int c = 0; c < modules; c++) {
@@ -480,114 +457,166 @@ class QrMasterPainter extends CustomPainter {
      return true;
    }

    // ── MOTOR DE DIBUJO FLUIDO INTACTO (CÓDIGO PRO) ────────────────
    final Path liquidPath = Path();
    final Path barrasPath = Path();

    final Paint liquidPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (gradShader != null) {
      liquidPaint.shader = gradShader;
    } else {
      liquidPaint.color = qrC1;
    }
    final Path liquidPath = Path(); final Path barrasPath = Path();
    final Paint liquidPaint = Paint()..isAntiAlias = true..style = PaintingStyle.stroke..strokeWidth = tileSize..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    if (gradShader != null) liquidPaint.shader = gradShader; else liquidPaint.color = qrC1;

    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (!isSafeDark(r, c)) continue;

        final double x = c * tileSize;
        final double y = r * tileSize;
        final double centerX = x + tileSize / 2;
        final double centerY = y + tileSize / 2;
        final double x = c * tileSize; final double y = r * tileSize;
        final double centerX = x + tileSize / 2; final double centerY = y + tileSize / 2;

        if (estilo.contains("Gusano")) {
          liquidPath.moveTo(centerX, centerY);
          liquidPath.lineTo(centerX, centerY);

          if (isSafeDark(r, c + 1)) {
            liquidPath.moveTo(centerX, centerY);
            liquidPath.lineTo(centerX + tileSize, centerY);
          }
          if (isSafeDark(r + 1, c)) {
            liquidPath.moveTo(centerX, centerY);
            liquidPath.lineTo(centerX, centerY + tileSize);
          }

          liquidPath.moveTo(centerX, centerY); liquidPath.lineTo(centerX, centerY);
          if (isSafeDark(r, c + 1)) { liquidPath.moveTo(centerX, centerY); liquidPath.lineTo(centerX + tileSize, centerY); }
          if (isSafeDark(r + 1, c)) { liquidPath.moveTo(centerX, centerY); liquidPath.lineTo(centerX, centerY + tileSize); }
        } else if (estilo.contains("Barras")) {
          if (r == 0 || !isSafeDark(r - 1, c)) {
            int endR = r;
            while (endR + 1 < modules && isSafeDark(endR + 1, c)) {
              endR++;
            }
            int endR = r; while (endR + 1 < modules && isSafeDark(endR + 1, c)) endR++;
            final double barHeight = (endR - r + 1) * tileSize;
            final Rect barRect = Rect.fromLTWH(x + tileSize * 0.1, y, tileSize * 0.8, barHeight);
            barrasPath.addRRect(RRect.fromRectAndRadius(barRect, Radius.circular(tileSize * 0.3)));
            barrasPath.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + tileSize * 0.1, y, tileSize * 0.8, barHeight), Radius.circular(tileSize * 0.3)));
          }

        } else if (estilo.contains("Puntos")) {
          double hash = ((r * 13 + c * 29) % 100) / 100.0;
          double radius = tileSize * 0.35 + (tileSize * 0.15 * hash);
          canvas.drawCircle(Offset(centerX, centerY), radius, paint);

          canvas.drawCircle(Offset(centerX, centerY), tileSize * 0.35 + (tileSize * 0.15 * hash), paint);
        } else if (estilo.contains("Diamantes")) {
          double hash = ((r * 17 + c * 31) % 100) / 100.0;
          double scale = 0.65 + (0.5 * hash);
          double offset = tileSize * (1.0 - scale) / 2;
          Path path = Path()
            ..moveTo(centerX, y + offset)
            ..lineTo(x + tileSize - offset, centerY)
            ..lineTo(centerX, y + tileSize - offset)
            ..lineTo(x + offset, centerY)
            ..close();
          canvas.drawPath(path, paint);

        } else { 
          canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3), paint);
        }
          double hash = ((r * 17 + c * 31) % 100) / 100.0; double scale = 0.65 + (0.5 * hash); double offset = tileSize * (1.0 - scale) / 2;
          canvas.drawPath(Path()..moveTo(centerX, y + offset)..lineTo(x + tileSize - offset, centerY)..lineTo(centerX, y + tileSize - offset)..lineTo(x + offset, centerY)..close(), paint);
        } else canvas.drawRect(Rect.fromLTWH(x, y, tileSize + 0.3, tileSize + 0.3), paint);
      }
    }
    if (estilo.contains("Gusano")) canvas.drawPath(liquidPath, liquidPaint);
    else if (estilo.contains("Barras")) canvas.drawPath(barrasPath, paint);

    if (estilo.contains("Gusano")) {
      canvas.drawPath(liquidPath, liquidPaint);
    } else if (estilo.contains("Barras")) {
      canvas.drawPath(barrasPath, paint);
    final pE = Paint()..isAntiAlias = true; final pI = Paint()..isAntiAlias = true;
    if (customEyes) { pE.color = eyeExt; pI.color = eyeInt; } else if (gradShader != null) { pE.shader = gradShader; pI.shader = gradShader; } else { pE.color = qrC1; pI.color = qrC1; }
    EyeStyle eStyle = EyeStyle.rect; if (estilo.contains("Puntos")) eStyle = EyeStyle.circ; if (estilo.contains("Diamantes")) eStyle = EyeStyle.diamond;
    _drawEye(canvas, 0, 0, tileSize, pE, pI, eStyle); _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, pE, pI, eStyle); _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, pE, pI, eStyle);
  }
  void _drawEye(Canvas canvas, double x, double y, double t, Paint pE, Paint pI, EyeStyle eStyle) {
    final double s = 7 * t;
    if (eStyle == EyeStyle.circ) { canvas.drawPath(Path()..addOval(Rect.fromLTWH(x, y, s, s))..addOval(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE); canvas.drawOval(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.2 * t), pI);
    } else if (eStyle == EyeStyle.diamond) { double cx = x + 3.5 * t; double cy = y + 3.5 * t; canvas.drawPath(Path()..moveTo(cx, y)..lineTo(x + 7*t, cy)..lineTo(cx, y + 7*t)..lineTo(x, cy)..moveTo(cx, y + 1.2*t)..lineTo(x + 5.8*t, cy)..lineTo(cx, y + 5.8*t)..lineTo(x + 1.2*t, cy)..fillType = PathFillType.evenOdd, pE); canvas.drawPath(Path()..moveTo(cx, y + 2.2*t)..lineTo(x + 4.8*t, cy)..lineTo(cx, y + 4.8*t)..lineTo(x + 2.2*t, cy)..close(), pI);
    } else { canvas.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE); canvas.drawRect(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.4 * t), pI); }
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}

// ── MOTOR AVANZADO (NUEVOS ESTILOS) ────────────────────────────────
class QrAdvancedPainter extends CustomPainter {
  final String data, estiloAvanzado;
  final img_lib.Image? logoImage; final List<List<bool>>? outerMask;
  final double logoSize;
  final bool customEyes; final Color qrC1, qrC2, eyeExt, eyeInt;

  QrAdvancedPainter({required this.data, required this.estiloAvanzado, required this.logoImage, required this.outerMask, required this.logoSize, required this.qrC1, required this.qrC2, required this.customEyes, required this.eyeExt, required this.eyeInt});

  bool _isEyeModule(int r, int c, int modules) => (r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7);

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode(4, QrErrorCorrectLevel.H)..addData(data);
    final qrImage = QrImage(qrCode);
    final int modules = qrImage.moduleCount;
    final double tileSize = size.width / modules;

    final Paint basePaint = Paint()..isAntiAlias = true..color = qrC1;
    final Path liquidPathC1 = Path(); final Path liquidPathC2 = Path();
    
    // Máscara del logo para los estilos de Forma de Mapa y Fusión
    List<List<bool>> logoMaskMap = List.generate(modules, (_) => List.filled(modules, false));
    List<List<Color?>> logoColorMap = List.generate(modules, (_) => List.filled(modules, null));
    
    if (logoImage != null && outerMask != null) {
      final double logoFrac = logoSize / 270.0;
      final double logoStart = (1.0 - logoFrac) / 2.0;
      final double logoEnd = logoStart + logoFrac;
      for (int r = 0; r < modules; r++) {
        for (int c = 0; c < modules; c++) {
          double nx = (c + 0.5) / modules; double ny = (r + 0.5) / modules;
          if (nx >= logoStart && nx <= logoEnd && ny >= logoStart && ny <= logoEnd) {
            double relX = (nx - logoStart) / logoFrac; double relY = (ny - logoStart) / logoFrac;
            int px = (relX * logoImage!.width).clamp(0, logoImage!.width - 1).toInt(); 
            int py = (relY * logoImage!.height).clamp(0, logoImage!.height - 1).toInt();
            if (outerMask![py][px]) {
              logoMaskMap[r][c] = true;
              final pixel = logoImage!.getPixel(px, py);
              logoColorMap[r][c] = Color.fromARGB(255, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
            }
          }
        }
      }
    }

    // ── Ojos ─────────────────────────────────────────────────────
    final pE = Paint()..isAntiAlias = true;
    final pI = Paint()..isAntiAlias = true;
    if (customEyes) { pE.color = eyeExt; pI.color = eyeInt; } else if (gradShader != null) { pE.shader = gradShader; pI.shader = gradShader; } else { pE.color = qrC1; pI.color = qrC1; }
    bool shouldDrawAdvance(int r, int c) {
      if (r < 0 || r >= modules || c < 0 || c >= modules) return false;
      if (!qrImage.isDark(r, c)) return false;
      if (_isEyeModule(r, c, modules)) return false; 
      
      // Filtro QR Circular
      if (estiloAvanzado == "QR Circular") {
        double dist = math.sqrt(math.pow(c - modules/2, 2) + math.pow(r - modules/2, 2));
        if (dist > (modules / 2.1)) return false; // Dibuja solo dentro del círculo
      }
      // Filtro Forma de Mapa
      if (estiloAvanzado == "Forma de Mapa (Máscara)" && logoImage != null) {
        if (!logoMaskMap[r][c]) return false; // Dibuja solo donde está el logo
      }
      return true;
    }

    EyeStyle eStyle = EyeStyle.rect;
    if (estilo.contains("Puntos")) eStyle = EyeStyle.circ;
    if (estilo.contains("Diamantes")) eStyle = EyeStyle.diamond;
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if (!shouldDrawAdvance(r, c)) continue;
        
        final double x = c * tileSize; final double y = r * tileSize;
        final double cx = x + tileSize / 2; final double cy = y + tileSize / 2;

        if (estiloAvanzado == "Split Liquid (Mitades)") {
          Path activePath = (c < modules / 2) ? liquidPathC1 : liquidPathC2;
          activePath.moveTo(cx, cy); activePath.lineTo(cx, cy);
          if (shouldDrawAdvance(r, c + 1) && ((c + 1 < modules / 2) == (c < modules / 2))) {
            activePath.moveTo(cx, cy); activePath.lineTo(cx + tileSize, cy);
          }
          if (shouldDrawAdvance(r + 1, c)) {
            activePath.moveTo(cx, cy); activePath.lineTo(cx, cy + tileSize);
          }
        } else if (estiloAvanzado == "Logo Fusión (Camuflaje)") {
          Color dotColor = logoColorMap[r][c] ?? qrC1;
          Paint fusionPaint = Paint()..color = dotColor..strokeWidth = tileSize..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
          Path p = Path()..moveTo(cx, cy)..lineTo(cx, cy);
          if (shouldDrawAdvance(r, c + 1)) p.lineTo(cx + tileSize, cy);
          canvas.drawPath(p, fusionPaint);
          if (shouldDrawAdvance(r + 1, c)) canvas.drawPath(Path()..moveTo(cx, cy)..lineTo(cx, cy + tileSize), fusionPaint);
        } else {
          // Gusano normal para Circular y Mapa
          liquidPathC1.moveTo(cx, cy); liquidPathC1.lineTo(cx, cy);
          if (shouldDrawAdvance(r, c + 1)) { liquidPathC1.moveTo(cx, cy); liquidPathC1.lineTo(cx + tileSize, cy); }
          if (shouldDrawAdvance(r + 1, c)) { liquidPathC1.moveTo(cx, cy); liquidPathC1.lineTo(cx, cy + tileSize); }
        }
      }
    }

    _drawEye(canvas, 0, 0, tileSize, pE, pI, eStyle);
    _drawEye(canvas, (modules - 7) * tileSize, 0, tileSize, pE, pI, eStyle);
    _drawEye(canvas, 0, (modules - 7) * tileSize, tileSize, pE, pI, eStyle);
  }
    final Paint pen1 = Paint()..isAntiAlias=true..color=qrC1..style=PaintingStyle.stroke..strokeWidth=tileSize..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    final Paint pen2 = Paint()..isAntiAlias=true..color=qrC2..style=PaintingStyle.stroke..strokeWidth=tileSize..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    
    if (estiloAvanzado == "Split Liquid (Mitades)") {
      canvas.drawPath(liquidPathC1, pen1); canvas.drawPath(liquidPathC2, pen2);
    } else if (estiloAvanzado != "Logo Fusión (Camuflaje)") {
      canvas.drawPath(liquidPathC1, pen1);
    }

  void _drawEye(Canvas canvas, double x, double y, double t, Paint pE, Paint pI, EyeStyle eStyle) {
    final double s = 7 * t;
    if (eStyle == EyeStyle.circ) {
    // ── Ojos ─────────────────────────────────────────────────────
    final pE = Paint()..isAntiAlias = true..color = customEyes ? eyeExt : qrC1;
    final pI = Paint()..isAntiAlias = true..color = customEyes ? eyeInt : qrC1;
    
    void dEye(double x, double y) {
      final double s = 7 * tileSize; final double t = tileSize;
      canvas.drawPath(Path()..addOval(Rect.fromLTWH(x, y, s, s))..addOval(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      canvas.drawOval(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.2 * t), pI);
    } else if (eStyle == EyeStyle.diamond) {
      double cx = x + 3.5 * t; double cy = y + 3.5 * t;
      Path outPath = Path()..moveTo(cx, y)..lineTo(x + 7*t, cy)..lineTo(cx, y + 7*t)..lineTo(x, cy)..moveTo(cx, y + 1.2*t)..lineTo(x + 5.8*t, cy)..lineTo(cx, y + 5.8*t)..lineTo(x + 1.2*t, cy)..fillType = PathFillType.evenOdd;
      canvas.drawPath(outPath, pE);
      Path inPath = Path()..moveTo(cx, y + 2.2*t)..lineTo(x + 4.8*t, cy)..lineTo(cx, y + 4.8*t)..lineTo(x + 2.2*t, cy)..close();
      canvas.drawPath(inPath, pI);
    } else {
      canvas.drawPath(Path()..addRect(Rect.fromLTWH(x, y, s, s))..addRect(Rect.fromLTWH(x + t, y + t, s - 2 * t, s - 2 * t))..fillType = PathFillType.evenOdd, pE);
      canvas.drawRect(Rect.fromLTWH(x + 2.1 * t, y + 2.1 * t, s - 4.2 * t, s - 4.4 * t), pI);
    }
    dEye(0, 0); dEye((modules - 7) * tileSize, 0); dEye(0, (modules - 7) * tileSize);
  }
  @override bool shouldRepaint(CustomPainter old) => true;
}
