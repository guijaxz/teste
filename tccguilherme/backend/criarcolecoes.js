/// Eu criei este script como uma ferramenta de configuração inicial para o nosso sistema de reconhecimento de imagens.
/// Ele não faz parte da aplicação principal que roda no servidor, mas é um passo importante para o setup do ambiente.
/// O que ele faz:
/// 1. Conecta-se ao serviço AWS Rekognition.
/// 2. Chama a função `createRekognitionCollection` duas vezes para criar as duas coleções de faces
///    que eu preciso: 'pets_perdidos' e 'pets_encontrados'.
/// Essas coleções são como "pastas" na nuvem da AWS onde eu armazeno as faces dos pets para poder compará-las depois.
/// Eu rodo este script uma única vez para preparar o ambiente da AWS. Se a coleção já existir, ele apenas avisa e não dá erro.
require('dotenv').config();

const { RekognitionClient, CreateCollectionCommand } = require("@aws-sdk/client-rekognition");


const rekognitionClient = new RekognitionClient({});

// Função para criar uma coleção
const createRekognitionCollection = async (collectionName) => {
  try {
    const params = {
      CollectionId: collectionName,
    };
    const command = new CreateCollectionCommand(params);
    const response = await rekognitionClient.send(command);
    console.log(`Coleção '${collectionName}' criada com sucesso!`);
    console.log("Resposta:", response);
  } catch (error) {
    if (error.name === 'ResourceAlreadyExistsException') {
      console.warn(`Atenção: A coleção '${collectionName}' já existe.`);
    } else {
      console.error(`Erro ao criar a coleção '${collectionName}':`, error);
    }
  }
};


const setupCollections = async () => {
  
  await createRekognitionCollection("pets_perdidos");
  await createRekognitionCollection("pets_encontrados");
};

setupCollections();