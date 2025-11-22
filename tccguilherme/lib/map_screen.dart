import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Eu criei esta tela para lidar com tudo relacionado a mapas.
/// Ela tem um duplo propósito que eu controlo com a flag `isReadOnly`:
/// 1. Se `isReadOnly` for falso (padrão), ela funciona como um seletor de
///    localização, permitindo que o usuário toque no mapa para escolher um ponto.
/// 2. Se `isReadOnly` for verdadeiro, ela apenas exibe uma localização fixa,
///    sem permitir interação.
class MapScreen extends StatefulWidget {
  final LatLng initialLocation;
  final bool isReadOnly;

  const MapScreen({
    super.key,
    required this.initialLocation,
    this.isReadOnly = false, // Padrão é interativo
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late LatLng _pickedLocation;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _markers.add(
      Marker(
        markerId: const MarkerId('picked-location'),
        position: _pickedLocation,
        // O pin só pode ser arrastado se não for modo de leitura
        draggable: !widget.isReadOnly,
        onDragEnd: widget.isReadOnly
            ? null
            : (newPosition) {
                setState(() {
                  _pickedLocation = newPosition;
                });
              },
      ),
    );
  }

  /// No método `build`, eu uso a flag `widget.isReadOnly` para mudar a UI.
  /// O título da tela, a presença do botão de confirmar na `AppBar` e a
  /// capacidade de interagir com o mapa (`onTap`) são todos condicionados
  /// por essa flag, tornando o widget reutilizável para ambos os cenários.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isReadOnly ? 'Localização do Pet' : 'Selecione a Localização',
        ),
        // Mostra o botão de confirmar apenas se não for modo de leitura
        actions: [
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.of(context).pop(_pickedLocation);
              },
            ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation,
          zoom: 16.0,
        ),
        markers: _markers,
        // Permite tocar no mapa apenas se não for modo de leitura
        onTap: widget.isReadOnly
            ? null
            : (location) {
                setState(() {
                  _pickedLocation = location;
                  _markers.clear();
                  _markers.add(
                    Marker(
                      markerId: const MarkerId('picked-location'),
                      position: _pickedLocation,
                      draggable: true,
                      onDragEnd: (newPosition) {
                        setState(() {
                          _pickedLocation = newPosition;
                        });
                      },
                    ),
                  );
                });
              },
      ),
    );
  }
}
