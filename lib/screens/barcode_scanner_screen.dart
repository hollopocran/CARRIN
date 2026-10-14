import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _found = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: const Text('Escanear Produto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off: return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on: return const Icon(Icons.flash_on, color: Colors.white);
                  case TorchState.unavailable: return const Icon(Icons.flash_off, color: Colors.white70);
                  case TorchState.auto: return const Icon(Icons.flash_auto, color: Colors.white);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front: return const Icon(Icons.camera_front, color: Colors.white);
                  case CameraFacing.back: return const Icon(Icons.camera_rear, color: Colors.white);
                }
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (_found) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.displayValue != null) {
                setState(() => _found = true);
                Vibration.vibrate(duration: 100);
                Navigator.pop(context, barcodes.first.displayValue);
              }
            },
          ),
          // Overlay de Mira
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(top: 0, left: 0, child: _corner(0)),
                  Positioned(top: 0, right: 0, child: _corner(1)),
                  Positioned(bottom: 0, left: 0, child: _corner(2)),
                  Positioned(bottom: 0, right: 0, child: _corner(3)),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Aponte para o código de barras',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, backgroundColor: Colors.black26),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _corner(int index) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: (index == 0 || index == 1) ? BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          bottom: (index == 2 || index == 3) ? BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          left: (index == 0 || index == 2) ? BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          right: (index == 1 || index == 3) ? BorderSide(color: Colors.white, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}
