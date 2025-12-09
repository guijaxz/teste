const admin = require('firebase-admin');
const { deleteImage } = require('./firebaseStorageService');

const db = admin.firestore();

/// Eu criei esta função para salvar os dados do perfil de um usuário no Firestore.
/// Ela é chamada quando um novo usuário se registra ou atualiza suas informações.
/// Ela recebe o ID do usuário (que vem do Firebase Auth) e um objeto com os dados do perfil (como nome, e-mail, etc.).
/// Eu uso `set` com `merge: true` para que ela possa tanto criar um novo documento de perfil quanto
/// atualizar um existente sem sobrescrever campos que não foram passados.
const createUserProfile = async (userId, userData) => {
    try {
        await db.collection('users').doc(userId).set(userData, { merge: true });
        console.log(`Perfil criado/atualizado para o usuário: ${userId}`);
    } catch (error) {
        console.error("Erro ao criar perfil de usuário no Firestore: ", error);
        throw new Error('Erro ao salvar os dados do usuário.');
    }
};

/// Eu implementei esta função para lidar com atualizações no perfil do usuário.
/// Ela recebe o ID do usuário e um objeto contendo apenas os campos que precisam ser atualizados.
/// Diferente da `createUserProfile`, eu uso o método `update` aqui, que falhará se o documento
/// do usuário não existir. É ideal para quando o usuário já está logado e modifica seus dados.
const updateUserProfile = async (userId, userData) => {
    try {
        await db.collection('users').doc(userId).update(userData);
        console.log(`Perfil atualizado para o usuário: ${userId}`);
    } catch (error) {
        console.error("Erro ao atualizar perfil de usuário no Firestore: ", error);
        throw new Error('Erro ao atualizar os dados do usuário.');
    }
};

/// Eu desenvolvi esta função para salvar um novo pet no banco de dados.
/// Ela recebe um objeto com todos os dados do pet (nome, descrição, status, etc.).
/// Antes de salvar, eu garanto que o campo de localização, se vier como uma string JSON,
/// seja convertido de volta para um objeto, que é como o Firestore armazena GeoPoints.
/// Eu adiciono o pet à coleção 'pets' e também incluo um timestamp de quando ele foi criado.
/// Ao final, retorno o objeto do pet salvo junto com o ID gerado pelo Firestore.
const savePet = async (petData) => {
    try {
        const dataToSave = { ...petData };

        // Garante que a localização seja salva como um objeto de mapa, não como string
        if (dataToSave.location && typeof dataToSave.location === 'string') {
            dataToSave.location = JSON.parse(dataToSave.location);
        }

        const docRef = await db.collection('pets').add({
            ...dataToSave,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log('Documento escrito com ID: ', docRef.id);
        // Retorna o ID junto com os dados
        return { id: docRef.id, ...dataToSave };
    } catch (error) {
        console.error("Erro ao salvar no Firestore: ", error);
        throw new Error('Erro ao salvar os dados do pet.');
    }
};

/// Eu criei esta função para buscar uma lista de pets no Firestore.
/// Ela pode receber dois parâmetros de filtro: 'status' (para filtrar entre 'perdido' e 'encontrado')
/// e 'characteristics' (uma string de características separadas por vírgula).
/// Eu construo a consulta (query) dinamicamente: começo ordenando por data de criação,
/// depois adiciono o filtro de status se ele for fornecido, e por fim o filtro de características
/// (usando 'array-contains-any').
/// A função retorna uma lista com os pets que correspondem aos filtros.
const getPets = async (status, characteristics, animalType, size, colors) => {
    try {
        let query = db.collection('pets').orderBy('createdAt', 'desc');

        if (status) {
            query = query.where('status', '==', status);
        }

        if (animalType) {
            query = query.where('animalType', '==', animalType);
        }

        if (size) {
            query = query.where('size', '==', size);
        }

        // Filtro por características
        if (characteristics) {
            const characteristicsArray = characteristics.split(',');
            if (characteristicsArray.length > 0) {
                query = query.where('characteristics', 'array-contains-any', characteristicsArray);
            }
        }

        // Filtro por cores
        if (colors) {
            const colorsArray = colors.split(',');
            if (colorsArray.length > 0) {
                query = query.where('colors', 'array-contains-any', colorsArray);
            }
        }

        const snapshot = await query.get();
        
        if (snapshot.empty) {
            return [];
        }
        const pets = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return pets;
    } catch (error) {
        console.error("Erro ao buscar pets no Firestore: ", error);
        throw new Error('Erro ao buscar os dados dos pets.');
    }
};

/// Eu implementei esta função para permitir que um usuário delete sua própria publicação de pet.
/// Ela recebe o ID do pet a ser deletado e o ID do usuário que está fazendo a requisição.
/// Primeiro, eu faço uma verificação de segurança para garantir que o usuário que está tentando deletar
/// é o mesmo que criou o post. Se não for, eu lanço um erro de permissão.
/// Se a verificação passar, eu chamo a função `deleteImage` do `firebaseStorageService` para remover a foto do pet do Storage.
/// Só depois de apagar a imagem, eu apago o documento do pet no Firestore.
const deletePet = async (petId, userId) => {
    const petRef = db.collection('pets').doc(petId);
    const doc = await petRef.get();

    if (!doc.exists) {
        throw new Error('Post não encontrado.');
    }

    const petData = doc.data();

    if (petData.userId !== userId) {
        throw new Error('Permissão negada. Você não é o dono deste post.');
    }

    // Deleta a imagem do Firebase Storage antes de deletar o documento
    if (petData.imageUrl) {
        await deleteImage(petData.imageUrl);
    }

    

    await petRef.delete();
    return { id: petId };
};

module.exports = { 
    createUserProfile, 
    updateUserProfile, 
    savePet, 
    getPets, 
    deletePet 
};
