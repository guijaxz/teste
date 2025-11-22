const BALNEARIO_CAMBORIU_COORDS = {
    latitude: -26.9905,
    longitude: -48.6347
};

const MAX_DISTANCE_KM = 20; // Raio de 20km a partir do centro

// Função para calcular a distância entre duas coordenadas em KM (Fórmula de Haversine)
/// Eu criei esta função para calcular a distância em quilômetros entre dois pontos geográficos.
/// Ela recebe a latitude e longitude de um ponto de origem (lat1, lon1) e de um ponto de destino (lat2, lon2).
/// A partir desses dados, eu aplico a fórmula de Haversine para obter a distância em linha reta entre os pontos,
/// considerando a curvatura da Terra.
function getDistanceInKm(lat1, lon1, lat2, lon2) {
    const R = 6371; // Raio da Terra em km
    const dLat = deg2rad(lat2 - lat1);
    const dLon = deg2rad(lon2 - lon1);
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const d = R * c; // Distância em km
    return d;
}

/// Esta é uma função auxiliar que eu implementei para converter um valor de graus para radianos.
/// Ela recebe um valor em graus (deg).
/// A conversão é necessária para que os cálculos trigonométricos na fórmula de Haversine funcionem corretamente.
function deg2rad(deg) {
    return deg * (Math.PI / 180);
}

/// Eu desenvolvi esta função para verificar se uma localização está dentro da área de cobertura do nosso serviço.
/// Ela recebe a latitude e longitude do ponto a ser verificado.
/// Utilizando a função getDistanceInKm, eu calculo a distância desse ponto até o centro definido em BALNEARIO_CAMBORIU_COORDS.
/// Se a distância for menor ou igual ao raio máximo (MAX_DISTANCE_KM), a função retorna verdadeiro, indicando que o local é permitido.
/// Caso a localização não seja fornecida, eu retorno 'true' para não bloquear funcionalidades que não dependem de geolocalização.
function isLocationInAllowedArea(latitude, longitude) {
    if (!latitude || !longitude) {
        return true; // Se não houver localização, não aplicamos a regra
    }
    const distance = getDistanceInKm(
        BALNEARIO_CAMBORIU_COORDS.latitude,
        BALNEARIO_CAMBORIU_COORDS.longitude,
        latitude,
        longitude
    );
    return distance <= MAX_DISTANCE_KM;
}

module.exports = { isLocationInAllowedArea };
