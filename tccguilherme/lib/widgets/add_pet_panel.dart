import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tccguilherme/map_screen.dart';
import 'package:http/http.dart' as http;
import 'package:tccguilherme/api_client.dart';

/// Eu criei este widget como o formulário para adicionar um novo pet.
/// Ele é um `StatefulWidget` porque precisa gerenciar os dados do formulário,
/// como a imagem selecionada, a localização, o nome e a descrição, além do estado
/// de carregamento (`_isLoading`) durante o envio para a API.
class AddPetPanel extends StatefulWidget {
  const AddPetPanel({super.key});

  @override
  State<AddPetPanel> createState() => _AddPetPanelState();
}

class _AddPetPanelState extends State<AddPetPanel> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isFound = true;
  File? _image;
  LatLng? _selectedLocation;
  bool _useCurrentLocation = false;
  bool _isLoading = false;
  String? _selectedSize;
  final List<String> _selectedColors = [];
  final List<String> _colors = ['Preto', 'Branco', 'Marrom', 'Cinza', 'Laranja', 'Dourado', 'Creme'];


  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Este método usa o plugin `image_picker` para buscar uma imagem.
  /// Ele recebe a fonte (`ImageSource.camera` ou `ImageSource.gallery`) e,
  /// se o usuário selecionar uma imagem, eu atualizo o estado com o arquivo
  /// para que a imagem apareça na pré-visualização do formulário.
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceActionSheet() {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              child: const Text('Tirar foto'),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('Escolher da galeria'),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _getCurrentLocationAndOpenMap() async {
    final position = await _determinePosition();
    if (position == null) return;
    final initialLocation = LatLng(position.latitude, position.longitude);
    final selectedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (ctx) => MapScreen(initialLocation: initialLocation),
      ),
    );
    if (selectedLocation != null) {
      setState(() {
        _selectedLocation = selectedLocation;
      });
    }
  }

  Future<void> _getCurrentLocationOnly() async {
    final position = await _determinePosition();
    if (position != null) {
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  /// Eu centralizei toda a lógica de permissão de localização neste método.
  /// Ele usa o `geolocator` para verificar se o serviço está ativo e se o app
  /// tem permissão. Se não tiver, ele solicita. Eu lido com todos os casos
  /// (negado, negado para sempre) e só retorno a posição se estiver tudo certo.
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verifica se serviço de localização está ativo
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviços de localização estão desabilitados.'),
        ),
      );
      return null;
    }

    // Verifica permissão atual
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Solicita permissão se negada
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissões de localização negadas.')),
        );
        return null;
      }
    }

    // Trata caso de negação permanente
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissão de localização negada permanentemente, não podemos pedir a localização.',
          ),
        ),
      );
      return null;
    }

    // Se tudo OK, retorna a posição atual
    return await Geolocator.getCurrentPosition();
  }

  /// Este é o método que envia os dados do formulário para o meu backend.
  /// Ele valida se a imagem e a localização foram fornecidas, monta uma
  /// requisição `MultipartRequest` (porque preciso enviar um arquivo de imagem),
  /// adiciona os campos do formulário e o token de autenticação, e envia para a API.
  /// Eu também controlo o estado de `_isLoading` para mostrar um indicador de
  /// progresso e trato as respostas de sucesso e erro do servidor.
  Future<void> _submit() async {
    if (_image == null ||
        _selectedLocation == null ||
        _selectedSize == null ||
        _selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Todos os campos são obrigatórios, incluindo a imagem, localização, tamanho e pelo menos uma cor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }
      final token = await user.getIdToken();

      final petName =
          _nameController.text.isEmpty ? 'Não informado' : _nameController.text;
      final status = _isFound ? 'encontrado' : 'perdido';
      final locationData = {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
      };

      final uri = Uri.parse('${getBaseUrl()}/api/pets');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = petName
        ..fields['description'] = _descriptionController.text
        ..fields['status'] = status
        ..fields['size'] = _selectedSize!
        ..fields['colors'] = json.encode(_selectedColors)
        ..fields['location'] = json.encode(locationData)
        ..files.add(
          await http.MultipartFile.fromPath('image', _image!.path),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pet registrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (response.statusCode == 400) {
        final decodedBody = json.decode(responseBody);
        final errorMessage = decodedBody['error'] ??
            'A imagem enviada não parece ser de um animal.';

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Erro'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        throw Exception(
          'Falha ao registrar o pet: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecione as Cores'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _colors.map((color) {
                    return CheckboxListTile(
                      title: Text(color),
                      value: _selectedColors.contains(color),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            if (!_selectedColors.contains(color)) {
                              _selectedColors.add(color);
                            }
                          } else {
                            _selectedColors.remove(color);
                          }
                        });
                        // Also call the parent setState to rebuild the widget showing the selected colors
                        this.setState(() {});
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FECHAR'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cor(es) do animal:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showColorPicker,
          child: InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: _selectedColors.isNotEmpty
                  ? _selectedColors
                      .map((color) => Chip(
                            label: Text(color),
                            onDeleted: () {
                              setState(() {
                                _selectedColors.remove(color);
                              });
                            },
                          ))
                      .toList()
                  : [const Text('Selecione as cores')],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _showImageSourceActionSheet,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: Colors.grey.shade300),
                    image: _image != null
                        ? DecorationImage(
                            image: FileImage(_image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _image == null
                      ? Icon(
                          Icons.image_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isFound = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isFound
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: !_isFound
                                ? [
                                    BoxShadow(
                                      color: Colors.grey.withAlpha((255 * 0.3).round()),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                    ),
                                  ]
                                : [],
                          ),
                          child: const Text(
                            'Perdi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isFound = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isFound
                                ? Colors.grey[600]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'Encontrei',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isFound ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nome do animal:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Localização:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Switch(
                              value: _useCurrentLocation,
                              onChanged: (value) {
                                setState(() {
                                  _useCurrentLocation = value;
                                  if (_useCurrentLocation) {
                                    _getCurrentLocationOnly();
                                  } else {
                                    _selectedLocation = null;
                                  }
                                });
                              },
                            ),
                            const Expanded(
                              child: Text(
                                'Pegar localização atual',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        _selectedLocation == null && !_useCurrentLocation
                            ? ElevatedButton.icon(
                                icon: const Icon(Icons.location_on),
                                label: const Text('Selecionar'),
                                onPressed: _getCurrentLocationAndOpenMap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              )
                            : ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _useCurrentLocation ? 'Atual' : 'Selecionada',
                                ),
                                onPressed: _useCurrentLocation
                                    ? null
                                    : _getCurrentLocationAndOpenMap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _useCurrentLocation
                                      ? Colors.blue
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSizeSelector(),
              const SizedBox(height: 16),
              _buildColorSelector(),
              const SizedBox(height: 16),
              const Text(
                'Descrição:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Enviar'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tamanho do animal:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedSize,
          hint: const Text('Selecione o tamanho'),
          onChanged: (value) {
            setState(() {
              _selectedSize = value;
            });
          },
          items: const [
            DropdownMenuItem(
              value: 'Pequeno',
              child: Text('Pequeno (até 10kg)'),
            ),
            DropdownMenuItem(
              value: 'Médio',
              child: Text('Médio (até 20kg)'),
            ),
            DropdownMenuItem(
              value: 'Grande',
              child: Text('Grande (mais de 20kg)'),
            ),
          ],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
