const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

const bucket = admin.storage().bucket();

/// Eu criei esta função para lidar com o upload de imagens para o Firebase Storage.
/// Ela recebe o arquivo que vem da requisição (via multer).
/// Eu gero um nome de arquivo único usando uuidv4 para evitar conflitos.
/// A função cria um stream de escrita para o Firebase Storage e, quando o upload termina,
/// eu torno o arquivo publicamente acessível e retorno a URL pública para que possa ser salva
/// no Firestore e usada no frontend.
const uploadImage = async (file) => {
    const fileName = `${uuidv4()}-${file.originalname}`;
    const fileUpload = bucket.file(fileName);

    const blobStream = fileUpload.createWriteStream({
        metadata: {
            contentType: file.mimetype
        }
    });

    return new Promise((resolve, reject) => {
        blobStream.on('error', (error) => {
            console.error("Erro no upload do stream:", error);
            reject('Something is wrong! Unable to upload at the moment.');
        });

        blobStream.on('finish', async () => {
            try {
                // Torna o arquivo público
                await fileUpload.makePublic();
                
                const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
                resolve(publicUrl);
            } catch (error) {
                console.error("Erro ao tornar o arquivo público:", error);
                reject('Failed to make image public.');
            }
        });

        blobStream.end(file.buffer);
    });
};

/// Eu implementei esta função para apagar uma imagem do Firebase Storage.
/// Ela é chamada, por exemplo, quando um post de pet é deletado.
/// Ela recebe a URL pública da imagem que está armazenada no nosso banco de dados.
/// A partir dessa URL, eu extraio o nome do arquivo e uso o SDK do Firebase para
/// encontrar e deletar o arquivo correspondente no bucket do Storage.
const deleteImage = async (publicUrl) => {
    try {
        // Extrai o nome do arquivo da URL.
        const bucketName = bucket.name;
        const prefix = `https://storage.googleapis.com/${bucketName}/`;
        const fileName = publicUrl.startsWith(prefix) ? publicUrl.substring(prefix.length) : null;

        if (!fileName) {
            throw new Error('URL da imagem inválida.');
        }

        const file = bucket.file(fileName);
        await file.delete();
        console.log(`Imagem ${fileName} deletada com sucesso.`);
    } catch (error) {
        console.error("Erro ao deletar a imagem:", error);
        throw new Error('Falha ao deletar a imagem.');
    }
};

module.exports = { uploadImage, deleteImage };
