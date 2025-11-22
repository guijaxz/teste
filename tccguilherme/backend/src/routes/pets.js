const express = require('express');
const router = express.Router();
const multer = require('multer');
const admin = require('firebase-admin'); 
const { uploadImage } = require('../services/firebaseStorageService');
const { savePet, getPets, deletePet } = require('../services/firestoreService');
const { analyzeAndSearchImage, validateImageIsPet, getPetCharacteristics } = require('../services/rekognitionService'); 
const { notifyPetOwner } = require('../services/notificationService');
const { isLocationInAllowedArea } = require('../utils/location');
const authMiddleware = require('../middleware/authMiddleware');

const db = admin.firestore(); 

// Configura o multer para armazenar a imagem em memória
const upload = multer({ storage: multer.memoryStorage() });

/// Eu projetei esta rota para ser o ponto central de cadastro de pets, sejam eles perdidos ou encontrados.
/// O fluxo que implementei é o seguinte:
/// 1. A rota é protegida por autenticação e usa o `multer` para receber uma imagem em memória.
/// 2. Eu valido os dados recebidos: a imagem é obrigatória, o status também, e a localização (se fornecida)
///    deve estar dentro da nossa área de cobertura.
/// 3. Chamo a `validateImageIsPet` para usar a IA da AWS e garantir que a foto é mesmo de um animal.
///    Isso é uma etapa crucial de pré-validação.
/// 4. Se tudo estiver certo, eu faço o upload da imagem para o Firebase Storage com a `uploadImage`.
/// 5. Em paralelo, eu uso a `getPetCharacteristics` para extrair características da imagem.
/// 6. Salvo os dados do pet (incluindo a URL da imagem e as características) no Firestore usando `savePet`.
///    Isso me dá um ID para o pet.
/// 7. De forma assíncrona (para não fazer o usuário esperar), eu chamo a `analyzeAndSearchImage`, que vai
///    indexar a face do pet e procurar por correspondências.
/// 8. Imediatamente após salvar no Firestore, eu já retorno uma resposta de sucesso para o usuário.
router.post('/', authMiddleware, upload.single('image'), async (req, res) => {
    try {
        const userId = res.locals.user.uid;
        if (!req.file) {
            return res.status(400).json({ error: 'A imagem é obrigatória.' });
        }

        const { name, description, status, location } = req.body;
        if (!status) {
            return res.status(400).json({ error: 'O status (perdido/encontrado) é obrigatório.' });
        }

        const parsedLocation = location ? JSON.parse(location) : null;

        // Validar se a localização está na área permitida
        if (parsedLocation && !isLocationInAllowedArea(parsedLocation.latitude, parsedLocation.longitude)) {
            return res.status(400).json({ error: 'A localização está fora da área de cobertura inicial do serviço.' });
        }

        // 1. Validar se a imagem contém um animal ANTES de fazer upload ou salvar no Firestore
        const isAnimal = await validateImageIsPet(req.file.buffer);
        if (!isAnimal) {
            return res.status(400).json({ error: 'A imagem enviada não parece ser de um animal. Por favor, envie uma foto de um pet.' });
        }

        // Buscar o nome do usuário para adicionar aos dados do pet
        const userDoc = await db.collection('users').doc(userId).get();
        const ownerName = (userDoc.exists && (userDoc.data().fullName)) || 'Dono não identificado';

        // 2. Upload da imagem para o Firebase Storage
        const imageUrl = await uploadImage(req.file, userId);

        // Extrai características da imagem
        const characteristics = await getPetCharacteristics(req.file.buffer);

        // Prepara os dados do pet para salvar
        const petData = {
            userId,
            ownerName, // Nome do dono do post
            name,
            description,
            status, // "perdido" ou "encontrado"
            location: parsedLocation, // { latitude: XXX, longitude: YYY }
            imageUrl,
            faceId: null, // Será preenchido após a análise do Rekognition
            characteristics // Salva as características no banco
        };

        // 3. Salva os dados do pet no Firestore para obter um ID
        const savedPet = await savePet(petData);

        // 4. Inicia a análise de imagem de forma assíncrona (não bloqueia a resposta)
        analyzeAndSearchImage(savedPet, req.file.buffer).catch(console.error);

        // 5. Retorna a resposta para o usuário imediatamente
        res.status(201).json({ message: 'Registro do pet recebido e imagem validada. A imagem está sendo processada para busca de similaridade.', pet: savedPet });

    } catch (error) {
        console.error("Erro ao registrar pet:", error);
        res.status(500).json({ error: 'Erro interno ao registrar pet.' });
    }
});

/// Eu criei esta rota para listar os pets cadastrados.
/// Ela é pública e pode ser filtrada de duas maneiras, através de query-parameters na URL:
/// - `status`: para ver apenas pets 'perdidos' ou 'encontrados'.
/// - `characteristics`: para filtrar por características visuais.
/// Eu pego esses filtros e os passo para a função `getPets` do `firestoreService`,
/// que se encarrega de construir a consulta no banco de dados e retornar a lista de pets correspondente.
router.get('/', async (req, res) => {
    try {
        const { status, characteristics } = req.query; // Captura status e características da URL
        const pets = await getPets(status, characteristics); // Chama o serviço Firestore com os filtros
        res.status(200).json(pets);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/// Eu implementei esta rota para permitir que um usuário delete um de seus posts de pet.
/// A rota exige autenticação e recebe o ID do pet como parâmetro na URL.
/// Eu pego o ID do pet e o ID do usuário (que vem do `authMiddleware`) e passo para a função `deletePet`.
/// A `deletePet` no `firestoreService` contém a lógica de segurança crucial: ela verifica se o `userId`
/// no documento do pet é o mesmo do usuário que está fazendo a requisição. Ela também apaga a imagem
/// do Storage antes de apagar o registro no Firestore.
router.delete('/:id', authMiddleware, async (req, res) => {
    try {
        const petId = req.params.id;
        const userId = res.locals.user.uid; // ID do usuário autenticado

        await deletePet(petId, userId);

        res.status(200).json({ message: 'Post deletado com sucesso.' });
    } catch (error) {
        // Distingue entre erro de permissão e outros erros
        if (error.message.includes('Permissão negada')) {
            return res.status(403).json({ error: error.message });
        }
        if (error.message.includes('não encontrado')) {
            return res.status(404).json({ error: error.message });
        }
        res.status(500).json({ error: error.message });
    }
});

/// Eu criei esta rota para facilitar a comunicação entre os usuários.
/// Ela é acionada quando um usuário clica em botões como "É o meu pet!" ou "Eu encontrei este pet" no app.
/// A rota é autenticada e recebe o ID do pet que está sendo visualizado e uma mensagem no corpo da requisição.
/// Eu busco o perfil do usuário que está enviando a notificação para pegar seu nome completo,
/// e então chamo a `notifyPetOwner` do `notificationService`, que envia um e-mail e uma notificação push
/// para o dono do pet, informando sobre a interação.
router.post('/:id/notify', authMiddleware, async (req, res) => {
    try {
        const petId = req.params.id;
        const authenticatedUser = res.locals.user; // Usuário do middleware
        const { message } = req.body;

        // Busca o perfil completo do notificador para obter o nome
        const notifierDoc = await db.collection('users').doc(authenticatedUser.uid).get();
        const notifierUser = {
            email: authenticatedUser.email,
            fullName: notifierDoc.exists ? notifierDoc.data().fullName : 'Um usuário anônimo'
        };

        await notifyPetOwner(petId, notifierUser, message);

        res.status(200).json({ message: 'Notificação enviada com sucesso.' });
    } catch (error) {
        console.error("Erro ao enviar notificação manual:", error);
        if (error.message.includes('não encontrado')) {
            return res.status(404).json({ error: error.message });
        }
        res.status(500).json({ error: 'Erro interno ao enviar notificação.' });
    }
});

/// Eu desenvolvi esta rota para implementar a funcionalidade de "filtrar por imagem".
/// O usuário envia uma foto de um pet que ele viu, e o sistema o ajuda a encontrar posts similares.
/// O fluxo é simples:
/// 1. Recebo a imagem via `multer`.
/// 2. Faço a validação com `validateImageIsPet` para garantir que é um animal.
/// 3. Uso a `getPetCharacteristics` para extrair uma lista de características da imagem.
/// 4. Retorno essa lista de características para o frontend. O app então usa essas
///    características para chamar a rota GET / e filtrar os resultados.
router.post('/filter-by-image', upload.single('image'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'A imagem é obrigatória.' });
        }

        // 1. Validar se a imagem contém um animal
        const isAnimal = await validateImageIsPet(req.file.buffer);
        if (!isAnimal) {
            return res.status(400).json({ error: 'A imagem enviada não parece ser de um animal.' });
        }

        // 2. Extrair características
        const characteristics = await getPetCharacteristics(req.file.buffer);

        // 3. Retornar características
        res.status(200).json({ characteristics });

    } catch (error) {
        console.error("Erro ao filtrar por imagem:", error);
        res.status(500).json({ error: 'Erro interno ao processar a imagem.' });
    }
});

module.exports = router;