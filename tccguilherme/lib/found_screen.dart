import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tccguilherme/api_client.dart';
import 'package:tccguilherme/models/pet.dart';
import 'package:tccguilherme/map_screen.dart';
import 'package:tccguilherme/widgets/full_screen_image_screen.dart';

/// Esta tela é a versão "Encontrados" da `LostScreen`.
/// Ela mostra um feed público de todos os pets que foram registrados como
/// 'encontrados'. A lógica é muito similar, incluindo o filtro por imagem.
/// A principal diferença está no botão de ação, que aqui é "É MEU!",
/// permitindo que o dono de um pet perdido notifique quem o encontrou.
class FoundScreen extends StatefulWidget {
  const FoundScreen({super.key});

  @override
  State<FoundScreen> createState() => _FoundScreenState();
}

class _FoundScreenState extends State<FoundScreen> {
  late Future<List<Pet>> _foundPetsFuture;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<String> _activeFilters = []; // Lista de filtros ativos

  @override
  void initState() {
    super.initState();
    _loadFoundPets();
  }

  void _loadFoundPets() {
    setState(() {
      _foundPetsFuture = _fetchFoundPets();
    });
  }

  // --- Lógica de Filtro por Imagem ---
  Future<void> _filterByImage() async {
    final imageFile = await _pickImage();
    if (imageFile == null) return;

    // Exibe um indicador de carregamento
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analisando imagem...'),
        duration: Duration(seconds: 5),
      ),
    );

    try {
      final uri = Uri.parse('${getBaseUrl()}/api/pets/filter-by-image');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedBody = json.decode(responseBody);
        final characteristics = List<String>.from(
          decodedBody['characteristics'],
        );

        setState(() {
          _activeFilters = characteristics;
        });
        _loadFoundPets(); // Recarrega a lista com os filtros

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filtro aplicado: ${_activeFilters.join(', ')}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final decodedBody = json.decode(responseBody);
        final errorMessage =
            decodedBody['error'] ?? 'Erro ao analisar a imagem.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no filtro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<File?> _pickImage() async {
    final source = await _showImageSourceActionSheet();
    if (source == null) return null;

    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  Future<ImageSource?> _showImageSourceActionSheet() async {
    if (Platform.isIOS) {
      return await showCupertinoModalPopup<ImageSource>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              child: const Text('Tirar foto'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            CupertinoActionSheetAction(
              child: const Text('Escolher da galeria'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      return await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );
    }
  }

  /// Este método busca os pets encontrados na API.
  /// É idêntico ao `_fetchLostPets`, mas aqui eu passo `status=encontrado`
  /// como parâmetro na requisição para a minha API.
  Future<List<Pet>> _fetchFoundPets() async {
    var queryParams = {
      'status': 'encontrado',
      if (_activeFilters.isNotEmpty)
        'characteristics': _activeFilters.join(','),
    };
    final url = Uri.parse(
      '${getBaseUrl()}/api/pets',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> petsJson = json.decode(response.body);
        final pets = petsJson.map((json) => Pet.fromJson(json)).toList();
        if (_activeFilters.isEmpty) {
          pets.shuffle(); // Embaralha apenas se não houver filtro ativo
        }
        return pets;
      } else {
        throw Exception('Falha ao carregar os pets encontrados.');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Este método é chamado quando um usuário clica no botão "É MEU!".
  /// A lógica é a mesma do `_notifyOwner` na outra tela: eu envio uma
  /// requisição autenticada para o backend, que se encarrega de notificar
  /// o usuário que fez o post de "encontrado".
  Future<void> _notifyFinder(String petId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para realizar esta ação.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Ação'),
        content: const Text(
          'Deseja notificar o usuário que encontrou este pet que ele pode ser seu?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text(
              'Sim, notificar',
              style: TextStyle(color: Colors.green),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == null || !confirmed) return;

    try {
      final token = await user.getIdToken();
      final url = Uri.parse('${getBaseUrl()}/api/pets/$petId/notify');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message':
              'acredita que o pet que você encontrou é dele e entrou em contato',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário notificado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final responseBody = json.decode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Erro desconhecido ao notificar.';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadFoundPets(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Pets Encontrados na Região',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (_activeFilters.isNotEmpty)
                        TextButton(
                          child: const Text('Limpar'),
                          onPressed: () {
                            setState(() {
                              _activeFilters.clear();
                            });
                            _loadFoundPets();
                          },
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.filter_alt_outlined,
                          color: Colors.black,
                        ),
                        onPressed: _filterByImage,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Pet>>(
                  future: _foundPetsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text('Erro ao carregar: ${snapshot.error}'),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum pet encontrado na sua região por enquanto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    } else {
                      final pets = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: pets.length,
                        itemBuilder: (context, index) {
                          return _buildPetCard(pets[index]);
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetCard(Pet pet) {
    final bool wasFoundByMe = pet.userId == _currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenImageScreen(
                    imageUrl: pet.imageUrl,
                    heroTag: pet.id,
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
            child: Hero(
              tag: pet.id,
              child: Image.network(
                pet.imageUrl,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!wasFoundByMe)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _notifyFinder(pet.id),
                      icon: const Icon(Icons.pets, color: Colors.white),
                      label: const Text('É MEU!'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (!wasFoundByMe) const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Nome: ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              pet.name ?? 'Não especificado',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.normal,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (wasFoundByMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'VOCÊ ENCONTROU',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Encontrado por: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[850],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      pet.ownerName ?? 'Não informado',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Descrição:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pet.description ?? 'Sem descrição.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Encontrado em: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[850],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(pet.createdAt),
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => MapScreen(
                          initialLocation: LatLng(
                            pet.location.latitude,
                            pet.location.longitude,
                          ),
                          isReadOnly: true,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                  ),
                  label: const Text('Ver localização no mapa'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
