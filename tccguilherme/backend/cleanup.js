const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { deleteImage } = require('./src/services/firebaseStorageService');
admin.initializeApp();

/// Eu criei esta Cloud Function como um serviço de limpeza automática para o banco de dados.
/// É uma tarefa agendada (cron job) que eu configurei para rodar todo dia à 1 da manhã.
/// O objetivo dela é manter a base de dados relevante e organizada.
/// O que ela faz:
/// 1. Busca por todos os posts de pets com status 'encontrado' que foram criados há mais de 30 dias.
///    A ideia é que, se um pet encontrado não foi reclamado em 30 dias, o post pode ser removido.
/// 2. Para cada post antigo que ela encontra, ela primeiro tenta deletar a imagem associada do Firebase Storage
///    para não deixar arquivos órfãos.
/// 3. Depois, ela deleta o registro do post no Firestore.
/// 4. Eu uso uma operação em lote (`batch`) para deletar todos os documentos de uma vez, o que é mais eficiente.
exports.scheduledCleanup = functions.pubsub.schedule('every day 01:00')
    .timeZone('America/Sao_Paulo')
    .onRun(async (context) => {

    const db = admin.firestore();

    // Calcula a data de 30 dias atrás
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Converte para o formato de timestamp do Firestore
    const timestamp = admin.firestore.Timestamp.fromDate(thirtyDaysAgo);

    // Query para encontrar posts de "encontrados" mais antigos que 30 dias
    const oldPostsQuery = db.collection('pets')
        .where('status', '==', 'encontrado')
        .where('createdAt', '<', timestamp);

    const snapshot = await oldPostsQuery.get();

    if (snapshot.empty) {
        console.log('Nenhum post antigo de "encontrado" para deletar.');
        return null;
    }

    // Deleta os posts encontrados
    const batch = db.batch();
    for (const doc of snapshot.docs) {
        console.log(`Agendando para deletar o post: ${doc.id}`);
        const petData = doc.data();
        if (petData.imageUrl) {
            try {
                await deleteImage(petData.imageUrl);
                console.log(`Imagem ${petData.imageUrl} deletada do Storage.`);
            } catch (error) {
                console.error(`Erro ao deletar imagem ${petData.imageUrl} do Storage:`, error);
                // Continua mesmo que a imagem não possa ser deletada
            }
        }
        batch.delete(doc.ref);
    }

    await batch.commit();

    console.log(`Deleção em lote concluída. ${snapshot.size} posts foram deletados.`);
    return null;
});
