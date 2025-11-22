const sgMail = require('@sendgrid/mail');
const admin = require('firebase-admin');

sgMail.setApiKey(process.env.SENDGRID_API_KEY);
const db = admin.firestore();

/// Eu criei esta função interna para buscar todas as informações do dono de um pet.
/// Ela recebe o ID do pet.
/// Primeiro, eu busco o documento do pet na coleção 'pets' para encontrar o 'userId' do dono.
/// Depois, com o 'userId', eu busco o registro de autenticação do usuário (para pegar o e-mail)
/// e também o perfil dele na coleção 'users' (para pegar dados como nome completo e token de notificação).
/// Eu retorno um objeto com todas essas informações para serem usadas no envio de notificações.
const _getPetOwnerInfo = async (petId) => {
    const petRef = db.collection('pets').doc(petId);
    const petDoc = await petRef.get();

    if (!petDoc.exists) {
        console.error(`Pet com ID ${petId} não encontrado no Firestore.`);
        return null;
    }

    const petData = petDoc.data();
    const ownerId = petData.userId;

    try {
        const ownerRecord = await admin.auth().getUser(ownerId);
        const ownerProfileRef = db.collection('users').doc(ownerId);
        const ownerProfileDoc = await ownerProfileRef.get();

        if (!ownerRecord || !ownerRecord.email) {
            console.error(`Dono do pet com ID ${ownerId} não encontrado ou sem e-mail.`);
            return null;
        }

        return { ownerRecord, ownerProfileDoc, petData };
    } catch (error) {
        console.error(`Erro ao buscar dados do dono para o pet com ID ${petId}:`, error);
        return null;
    }
};

/// Esta é uma função auxiliar que eu implementei para centralizar o envio de e-mails.
/// Ela recebe o destinatário, o assunto e o conteúdo HTML do e-mail.
/// Eu monto o objeto da mensagem no formato que a API do SendGrid espera e realizo o envio.
/// Isso me ajuda a reutilizar a lógica de envio em várias partes do sistema.
const _sendEmail = async (to, subject, html) => {
    const msg = {
        to,
        from: process.env.SENDER_EMAIL,
        subject,
        html,
    };

    try {
        await sgMail.send(msg);
        console.log(`E-mail enviado para ${to}`);
    } catch (error) {
        console.error("Erro ao enviar e-mail com SendGrid:", error);
        throw error;
    }
};

/// Eu criei esta função para notificar o usuário por e-mail quando nosso sistema de IA encontra uma correspondência.
/// Ela recebe o e-mail do usuário e os dados do pet que foi encontrado (o "match").
/// Eu monto um template de e-mail amigável com os detalhes do pet e chamo a minha função auxiliar `_sendEmail` para fazer o envio.
const sendMatchEmail = async (userEmail, matchedPet) => {
    const subject = 'Boa notícia! Encontramos uma correspondência para o seu pet!';
    const html = `
        <h1>Correspondência Encontrada!</h1>
        <p>Olá,</p>
        <p>Temos ótimas notícias! Nosso sistema encontrou uma possível correspondência para o seu pet.</p>
        <p><strong>Detalhes do Pet Encontrado:</strong></p>
        <ul>
            <li><strong>Nome:</strong> ${matchedPet.name || 'Não informado'}</li>
            <li><strong>Descrição:</strong> ${matchedPet.description || 'Não informada'}</li>
        </ul>
        <p>Acesse o aplicativo para mais detalhes e para entrar em contato com a pessoa que o encontrou.</p>
        <br>
        <p>Atenciosamente,</p>
        <p>Equipe Encontre Seu Pet</p>
    `;
    await _sendEmail(userEmail, subject, html);
};

/// Eu implementei esta função para enviar uma notificação push quando a IA encontra uma correspondência.
/// Ela recebe o token FCM (Firebase Cloud Messaging) do dispositivo do usuário e os dados do pet correspondente.
/// Eu construo a mensagem da notificação, incluindo um título, corpo e dados adicionais (como o ID do pet e a tela a ser aberta no app),
/// e uso o SDK Admin do Firebase para enviá-la.
const sendPushNotification = async (fcmToken, matchedPet) => {
    const message = {
        notification: {
            title: 'Correspondência Encontrada!',
            body: `Uma possível correspondência para seu pet foi encontrada. Toque para ver os detalhes.`
        },
        data: { petId: String(matchedPet.id), screen: '/match-details' },
        token: fcmToken
    };

    try {
        await admin.messaging().send(message);
        console.log('Notificação push enviada com sucesso.');
    } catch (error) {
        if (error.code === 'messaging/registration-token-not-registered') {
            console.log(`Token FCM inválido detectado: ${fcmToken}. Removendo do Firestore.`);
            const usersRef = db.collection('users');
            const snapshot = await usersRef.where('fcmToken', '==', fcmToken).get();
            if (!snapshot.empty) {
                snapshot.forEach(doc => {
                    console.log(`Removendo token do usuário ${doc.id}`);
                    doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
                });
            }
        } else {
            console.error('Erro ao enviar notificação push:', error);
        }
    }
};

/// Eu criei esta função para lidar com as notificações de interações manuais entre usuários.
/// Ela é chamada quando um usuário clica em "É meu" ou "Encontrei ele" no perfil de um pet.
/// Ela recebe o ID do pet, as informações do usuário que está notificando e uma mensagem customizada.
/// Eu uso a `_getPetOwnerInfo` para buscar os dados do dono do pet e então envio um e-mail e uma notificação push
/// para ele, informando sobre a interação.
const notifyPetOwner = async (petId, notifierUser, customMessage) => {
    const ownerInfo = await _getPetOwnerInfo(petId);

    if (!ownerInfo) {
        return;
    }

    const { ownerRecord, ownerProfileDoc, petData } = ownerInfo;
    const ownerName = ownerProfileDoc.exists ? (ownerProfileDoc.data().fullName || ownerRecord.displayName) : 'Dono(a) do Pet';

    // Envia e-mail para o dono do pet
    const subject = 'Alguém interagiu com a publicação do seu pet!';
    const html = `
        <h1>Notificação sobre seu Pet</h1>
        <p>Olá, ${ownerName},</p>
        <p>O usuário <strong>${notifierUser.fullName}</strong> (${notifierUser.email}) ${customMessage}.</p>
        <p><strong>Detalhes do Pet:</strong></p>
        <ul>
            <li><strong>Nome:</strong> ${petData.name || 'Não informado'}</li>
            <li><strong>Descrição:</strong> ${petData.description || 'Não informada'}</li>
        </ul>
        <p>Acesse o aplicativo para ver mais detalhes.</p>
        <br>
        <p>Atenciosamente,</p>
        <p>Equipe Encontre Seu Pet</p>
    `;
    await _sendEmail(ownerRecord.email, subject, html);

    // Envia notificação push se o token estiver disponível
    if (ownerProfileDoc.exists && ownerProfileDoc.data().fcmToken) {
        await sendOwnerInteractionPushNotification(ownerProfileDoc.data().fcmToken, petData, notifierUser, customMessage);
    }
};

/// Esta função orquestra o processo de notificação quando a IA encontra uma correspondência.
/// Ela é chamada pelo `rekognitionService` após uma busca bem-sucedida.
/// Ela recebe o ID do pet que teve correspondência e os dados do novo pet que foi cadastrado.
/// Eu uso a `_getPetOwnerInfo` para obter os dados do dono do pet correspondente e, em seguida,
/// chamo as funções `sendMatchEmail` e `sendPushNotification` para notificá-lo em ambas as plataformas.
const notifyUserOfMatch = async (matchedPetId, newPet) => {
    const ownerInfo = await _getPetOwnerInfo(matchedPetId);

    if (!ownerInfo) {
        return;
    }

    const { ownerRecord, ownerProfileDoc } = ownerInfo;

    // Envia e-mail e push para o dono do pet que deu match
    await sendMatchEmail(ownerRecord.email, newPet);

    if (ownerProfileDoc.exists && ownerProfileDoc.data().fcmToken) {
        await sendPushNotification(ownerProfileDoc.data().fcmToken, newPet);
    }
};


/// Eu criei esta função especificamente para enviar a notificação push de interação entre usuários.
/// Ela recebe o token FCM do dono do pet, os dados do pet e do usuário que interagiu, e a mensagem da interação.
/// Eu formato a notificação de forma a deixar claro para o dono do pet quem interagiu com sua publicação
/// e o que essa pessoa fez, e então realizo o envio via Firebase Cloud Messaging.
const sendOwnerInteractionPushNotification = async (fcmToken, petData, notifierUser, customMessage) => {
    const message = {
        notification: {
            title: 'Interação no seu Pet!',
            body: `O usuário ${notifierUser.fullName} ${customMessage}. Toque para mais detalhes.`
        },
        data: { petId: String(petData.id), screen: '/pet-details' }, 
        token: fcmToken
    };

    try {
        await admin.messaging().send(message);
        console.log('Notificação push de interação enviada com sucesso.');
    } catch (error) {
        if (error.code === 'messaging/registration-token-not-registered') {
            console.log(`Token FCM inválido detectado: ${fcmToken}. Removendo do Firestore.`);
            const usersRef = db.collection('users');
            const snapshot = await usersRef.where('fcmToken', '==', fcmToken).get();
            if (!snapshot.empty) {
                snapshot.forEach(doc => {
                    console.log(`Removendo token do usuário ${doc.id}`);
                    doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
                });
            }
        } else {
            console.error('Erro ao enviar notificação push de interação:', error);
        }
    }
};

module.exports = { sendMatchEmail, sendPushNotification, notifyPetOwner, notifyUserOfMatch, sendOwnerInteractionPushNotification };
