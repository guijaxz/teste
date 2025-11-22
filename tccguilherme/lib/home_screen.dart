import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tccguilherme/api_client.dart';
import 'package:tccguilherme/models/pet.dart';
import 'package:tccguilherme/map_screen.dart';
import 'package:tccguilherme/widgets/full_screen_image_screen.dart';

/// Eu projetei esta tela para ser a área "Meus Pets" do usuário.
/// Ela busca e exibe apenas os animais que o usuário logado registrou,
/// permitindo que ele alterne a visualização entre os pets que ele
/// encontrou e os que ele perdeu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isFoundSelected = true;
  Future<List<Pet>>? _userPetsFuture;

  @override
  void initState() {
    super.initState();
    // Inicia a busca de pets assim que a tela é construída
    _loadPetsForCurrentUser();
  }

  /// Carrega os pets para o usuário atual, disparando a busca e atualizando a UI.
  void _loadPetsForCurrentUser() {
    setState(() {
      _userPetsFuture = _fetchAndFilterUserPets();
    });
  }

  /// Este método busca os pets na API e os filtra para o usuário atual.
  /// Eu faço uma requisição para a API buscando todos os pets com um status
  /// ('perdido' ou 'encontrado'). Depois que recebo a lista, eu a filtro
  /// aqui no app para mostrar apenas os pets cujo `userId` corresponde ao
  /// do usuário que está logado no Firebase.
  Future<List<Pet>> _fetchAndFilterUserPets() async {
    // 1. Obter o ID do usuário logado
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      // Se não houver usuário, retorna uma lista vazia.
      return [];
    }

    // 2. Determinar o status com base na seleção da UI
    final status = _isFoundSelected ? 'encontrado' : 'perdido';

    // 3. Montar a URL para a requisição
    final url = Uri.parse('${getBaseUrl()}/api/pets?status=$status');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // 4. Decodificar a resposta JSON
        final List<dynamic> allPetsJson = json.decode(response.body);
        final List<Pet> allPets = allPetsJson
            .map((json) => Pet.fromJson(json))
            .toList();

        // 5. Filtrar a lista para manter apenas os pets do usuário atual
        final userPets = allPets.where((pet) => pet.userId == userId).toList();

        return userPets;
      } else {
        // Se a resposta não for OK, lança um erro.
        throw Exception('Falha ao carregar os pets do servidor.');
      }
    } catch (e) {
      // Em caso de erro de conexão ou outro, relança a exceção.
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Este método lida com a exclusão de um registro de pet.
  /// Primeiro, eu mostro um diálogo de confirmação para evitar exclusões acidentais.
  /// Se o usuário confirmar, eu monto uma requisição `DELETE` autenticada para a
  /// minha API, passando o ID do pet. Após a exclusão, eu recarrego a lista
  /// para que a UI seja atualizada.
  Future<void> _deletePet(String petId) async {
    // Mostra um diálogo de confirmação
    final bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
          'Você tem certeza que deseja excluir este registro?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    // Se o usuário não confirmou, não faz nada
    if (confirmed == null || !confirmed) {
      return;
    }

    try {
      // Obter token de autenticação
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado.');
      final token = await user.getIdToken();

      // Montar a URL e fazer a requisição DELETE
      final url = Uri.parse('${getBaseUrl()}/api/pets/$petId');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // Recarrega a lista de pets para refletir a exclusão
        _loadPetsForCurrentUser();
      } else {
        final responseBody = json.decode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Erro desconhecido ao excluir.';
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- SELETOR SUPERIOR (Encontrados / Perdidos) ---
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _buildFilterChip(true, 'Meus pets encontrados'),
                  _buildFilterChip(false, 'Meus pets perdidos'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // --- CONTEÚDO DA TELA (LISTA DE PETS) ---
            Expanded(
              child: FutureBuilder<List<Pet>>(
                future: _userPetsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        _isFoundSelected
                            ? 'Nenhum pet encontrado por você.'
                            : 'Nenhum pet perdido por você.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    );
                  } else {
                    // Se temos dados, construímos a lista
                    final pets = snapshot.data!;
                    return ListView.builder(
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
    );
  }

  /// Constrói um chip de filtro (botão) para o seletor superior.
  Widget _buildFilterChip(bool isSelectedFlag, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isFoundSelected != isSelectedFlag) {
            setState(() {
              _isFoundSelected = isSelectedFlag;
            });
            _loadPetsForCurrentUser(); // Recarrega os dados com o novo filtro
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _isFoundSelected == isSelectedFlag
                ? Colors.black
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isFoundSelected == isSelectedFlag
                  ? Colors.white
                  : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Eu criei este método para construir o widget de card para cada pet.
  /// Ele recebe um objeto `Pet` e retorna um `Card` estilizado com a imagem,
  /// nome, descrição e botões. Isso mantém o código do `ListView.builder`
  /// mais limpo e organizado.
  Widget _buildPetCard(Pet pet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do pet clicável
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
          // Conteúdo do card (informações)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            ),
                          ),
                          Flexible(
                            child: Text(
                              pet.name ?? 'Sem nome',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pet.status == 'perdido')
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deletePet(pet.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Descrição:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      'Data de inclusão: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(pet.createdAt),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                  icon: const Icon(Icons.location_on_outlined),
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
