const { DetectLabelsCommand, IndexFacesCommand, SearchFacesByImageCommand } = require("@aws-sdk/client-rekognition");
const { rekognition } = require('../config/aws');
const admin = require('firebase-admin');
const { notifyUserOfMatch } = require('./notificationService');

const db = admin.firestore();

const COLLECTION_LOST_PETS = 'pets_perdidos';
const COLLECTION_FOUND_PETS = 'pets_encontrados';
const SIMILARITY_THRESHOLD = 70; // Limite de 70% de similaridade

/// Eu criei esta função para fazer uma validação inicial na imagem enviada pelo usuário.
/// Ela recebe o buffer da imagem.
/// Usando o serviço AWS Rekognition, eu verifico as labels (rótulos) presentes na imagem
/// para garantir que ela contém um animal (como 'Dog', 'Cat', 'Pet') com um grau de confiança aceitável.
/// Isso evita que o sistema processe imagens que não são de animais de estimação.
const validateImageIsPet = async (imageBuffer) => {
    console.log("Validando se a imagem contém um pet...");
    const detectLabelsParams = { Image: { Bytes: imageBuffer } };
    const labelsResponse = await rekognition.send(new DetectLabelsCommand(detectLabelsParams));

    // Log para mostrar a lista de labels retornada pela AWS
    //console.log("Labels detectadas pela AWS:", JSON.stringify(labelsResponse.Labels, null, 2));
    const isAnimal = labelsResponse.Labels.some(label => ['Animal', 'Dog', 'Cat', 'Pet'].includes(label.Name) && label.Confidence > 80);
    
    if (!isAnimal) {
        console.log("Validação falhou: a imagem não parece ser de um animal.");
        return false;
    }
    
    console.log("Validação bem-sucedida: a imagem parece ser de um animal.");
    return true;
};

/// Esta é a função principal de análise e busca que eu desenvolvi.
/// Ela recebe o objeto do pet e o buffer da imagem.
/// O processo que eu criei tem 4 etapas:
/// 1. Indexa a face do pet na coleção apropriada do AWS Rekognition ('pets_perdidos' ou 'pets_encontrados'),
///    associando a imagem ao ID do pet.
/// 2. Se a indexação for bem-sucedida, eu guardo o FaceId gerado pela AWS no documento do pet no Firestore.
/// 3. Em seguida, eu uso a mesma imagem para buscar por faces similares na coleção oposta (se o pet foi perdido,
///    procuro nos encontrados, e vice-versa).
/// 4. Se uma correspondência com similaridade acima do nosso limite (SIMILARITY_THRESHOLD) for encontrada,
///    eu chamo a função `notifyUserOfMatch` para enviar uma notificação ao dono do pet correspondente.
const analyzeAndSearchImage = async (pet, imageBuffer) => {
    console.log(`Iniciando análise para o pet: ${pet.id}`);

    const sourceCollectionId = pet.status === 'perdido' ? COLLECTION_LOST_PETS : COLLECTION_FOUND_PETS;
    const targetCollectionId = pet.status === 'perdido' ? COLLECTION_FOUND_PETS : COLLECTION_LOST_PETS;

    // 1. Indexar a face na coleção de origem
    const indexFacesParams = {
        CollectionId: sourceCollectionId,
        Image: { Bytes: imageBuffer },
        ExternalImageId: pet.id,
        MaxFaces: 1,
        QualityFilter: "AUTO",
        DetectionAttributes: ['DEFAULT']
    };
    const indexResult = await rekognition.send(new IndexFacesCommand(indexFacesParams));

    // Log detalhado da resposta da AWS
    console.log("Resultado completo do IndexFaces:", JSON.stringify(indexResult, null, 2));

    if (!indexResult.FaceRecords || indexResult.FaceRecords.length === 0) {
        console.log(`Nenhuma face detectada ou indexada para o pet ${pet.id}.`);
        if (indexResult.UnindexedFaces && indexResult.UnindexedFaces.length > 0) {
            console.log("Motivos para não indexação:", indexResult.UnindexedFaces.map(f => f.Reasons).flat());
        }
        return;
    }

    const faceId = indexResult.FaceRecords[0].Face.FaceId;

    console.log(`Face do pet ${pet.id} indexada com FaceId: ${faceId}`);

    // 2. Atualizar o pet no Firestore com o FaceId
    await db.collection('pets').doc(pet.id).update({ faceId: faceId });

    // 3. Buscar por faces similares na coleção de destino
    const searchFacesParams = {
        CollectionId: targetCollectionId,
        Image: { Bytes: imageBuffer },
        FaceMatchThreshold: SIMILARITY_THRESHOLD,
        MaxFaces: 1
    };
    const searchResult = await rekognition.send(new SearchFacesByImageCommand(searchFacesParams));

    // 4. Se encontrar correspondência, notificar o usuário
    if (searchResult.FaceMatches && searchResult.FaceMatches.length > 0) {
        const match = searchResult.FaceMatches[0];
        if (match.Similarity >= SIMILARITY_THRESHOLD) {
            const matchedPetId = match.Face.ExternalImageId;
            console.log(`Correspondência encontrada para o pet ${pet.id}! Pet correspondente: ${matchedPetId} com similaridade de ${match.Similarity}%`);
            await notifyUserOfMatch(matchedPetId, pet);
        }
    }
};

/// Eu criei esta função para extrair características visuais do pet a partir da imagem.
/// Ela recebe o buffer da imagem.
/// Utilizando o AWS Rekognition, eu detecto labels na imagem. Depois, eu filtro essas labels
/// para remover termos muito genéricos (como 'Animal', 'Pet', 'Cachorro') e manter apenas
/// características mais descritivas (como 'Golden Retriever', 'Beagle').
/// O resultado é uma lista de características que pode ajudar o usuário a descrever melhor o pet.
const getPetCharacteristics = async (imageBuffer) => {
    console.log("Extraindo características do pet...");
    try {
        const detectLabelsParams = {
            Image: { Bytes: imageBuffer },
            MinConfidence: 80 // Considera apenas labels com confiança acima de 80%
        };
        const labelsResponse = await rekognition.send(new DetectLabelsCommand(detectLabelsParams));

        // Lista de labels genéricas a serem ignoradas
        const ignoredLabels = [
            'Animal', 'Pet', 'Mammal', 'Canine', 'Feline', 'Dog', 'Cat',
            'Outdoors', 'Nature', 'Grass', 'Plant', 'Wildlife', 'Person', 'Boy', 'Child', 'Human', 'Woman', 'Adult', 'Female', 'Male', 'Kitten', 'Rat', 'Rodent'
        ];

        const characteristics = labelsResponse.Labels
            .filter(label => !ignoredLabels.includes(label.Name) && label.Confidence > 80)
            .map(label => label.Name);

        console.log("Características extraídas:", characteristics);
        return characteristics;
    } catch (error) {
        console.error("Erro ao extrair características da imagem:", error);
        return []; // Retorna um array vazio em caso de erro
    }
};

module.exports = { analyzeAndSearchImage, validateImageIsPet, getPetCharacteristics };