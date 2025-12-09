/// Eu criei este modelo para representar uma localização geográfica simples.
/// Ele armazena apenas a latitude e a longitude de um ponto.
class PetLocation {
  final double latitude;
  final double longitude;

  PetLocation({required this.latitude, required this.longitude});

  /// Este é um construtor factory que eu uso para criar uma instância de `PetLocation`
  /// a partir de um mapa (JSON) vindo da API.
  factory PetLocation.fromJson(Map<String, dynamic> json) {
    return PetLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// Este é o meu modelo de dados principal para um pet.
/// Ele contém todos os campos que definem um pet no sistema, como ID, nome,
/// status (perdido/encontrado), URL da imagem, localização, etc.
class Pet {
  final String id;
  final String userId;
  final String? name;
  final String? description;
  final String imageUrl;
  final String status;
  final PetLocation location;
  final DateTime createdAt;
  final String? ownerName;
  final String? animalType;
  final String? size;
  final List<String> colors;

  Pet({
    required this.id,
    required this.userId,
    this.name,
    this.description,
    required this.imageUrl,
    required this.status,
    required this.location,
    required this.createdAt,
    this.ownerName,
    this.animalType,
    this.size,
    required this.colors,
  });

  /// Este construtor factory converte os dados JSON da minha API em um objeto `Pet`.
  /// Eu adicionei uma lógica específica para o campo `createdAt`, pois o Firestore
  /// retorna um objeto de timestamp complexo, e eu preciso convertê-lo para um
  /// objeto `DateTime` que o Dart entende.
  factory Pet.fromJson(Map<String, dynamic> json) {
    // Tratamento para o timestamp do Firestore que pode vir como um objeto
    dynamic createdAtData = json['createdAt'];
    DateTime createdAt;
    if (createdAtData['_seconds'] != null) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAtData['_seconds'] * 1000,
      );
    } else if (createdAtData is String) {
      createdAt = DateTime.parse(createdAtData);
    } else {
      createdAt = DateTime.now(); // Fallback
    }

    return Pet(
      id: json['id'],
      userId: json['userId'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      status: json['status'],
      location: PetLocation.fromJson(json['location']),
      createdAt: createdAt,
      ownerName: json['ownerName'],
      animalType: json['animalType'],
      size: json['size'],
      colors: json['colors'] != null ? List<String>.from(json['colors']) : [],
    );
  }
}
