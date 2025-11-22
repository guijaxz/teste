/// Eu criei este arquivo para centralizar a configuração e inicialização dos clientes da AWS.
/// Em vez de configurar o cliente do Rekognition ou do S3 em cada serviço que os utiliza,
/// eu faço isso uma única vez aqui.
/// O arquivo lê a região da AWS a partir das variáveis de ambiente e cria uma instância
/// dos clientes `RekognitionClient` e `S3Client`.
/// Depois, eu exporto essas instâncias para que possam ser importadas e utilizadas de forma consistente
/// em qualquer lugar do backend que precise interagir com a AWS.
const { RekognitionClient } = require("@aws-sdk/client-rekognition");
const { S3Client } = require("@aws-sdk/client-s3");

const region = process.env.AWS_REGION;


const rekognition = new RekognitionClient({ region });
const s3 = new S3Client({ region });

module.exports = { s3, rekognition };
