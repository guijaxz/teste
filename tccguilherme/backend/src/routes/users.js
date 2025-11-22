const express = require('express');
const router = express.Router();
const { createUserProfile, updateUserProfile } = require('../services/firestoreService');
const admin = require('firebase-admin'); 
const authMiddleware = require('../middleware/authMiddleware');

/// Eu defini esta rota para criar o perfil de um usuário no nosso banco de dados Firestore.
/// Ela é chamada logo após o usuário se registrar no Firebase Auth pelo app.
/// A rota é protegida pelo `authMiddleware`, então eu sei que sempre terei um usuário autenticado.
/// Eu pego o ID do usuário (que o middleware adicionou) e os dados do perfil (nome, e-mail, telefone) que vêm no corpo da requisição.
/// Com esses dados, eu chamo a função `createUserProfile` do `firestoreService` para salvar as informações.
router.post('/profile', authMiddleware, async (req, res) => {
    try {
        const userId = res.locals.user.uid;
        const { fullName, email, phone } = req.body; // Recebe nome, email e telefone do corpo da requisição

        if (!fullName || !email) {
            return res.status(400).json({ error: 'Nome completo e e-mail são obrigatórios.' });
        }

        const userData = {
            fullName,
            email,
            phone,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        await createUserProfile(userId, userData);
        res.status(201).json({ message: 'Perfil de usuário criado com sucesso.' });
    } catch (error) {
        console.error("Erro ao criar perfil de usuário:", error);
        res.status(500).json({ error: 'Erro interno ao criar perfil de usuário.' });
    }
});

/// Eu criei esta rota para permitir que um usuário já logado atualize suas informações de perfil.
/// Assim como a rota de criação, ela é protegida pelo `authMiddleware`.
/// Ela recebe os campos que podem ser atualizados (nome, telefone, token FCM) no corpo da requisição.
/// Eu construo um objeto `userData` apenas com os campos que foram realmente enviados na requisição,
/// para não sobrescrever dados existentes com valores nulos.
/// Em seguida, eu chamo a função `updateUserProfile` do `firestoreService` para aplicar as atualizações.
router.put('/profile', authMiddleware, async (req, res) => {
    try {
        const userId = res.locals.user.uid;
        const { fullName, phone, fcmToken } = req.body; // Campos que podem ser atualizados

        const userData = {};
        if (fullName) userData.fullName = fullName;
        if (phone) userData.phone = phone;
        if (fcmToken) userData.fcmToken = fcmToken;

        if (Object.keys(userData).length === 0) {
            return res.status(400).json({ error: 'Nenhum dado para atualizar foi fornecido.' });
        }

        await updateUserProfile(userId, userData);
        res.status(200).json({ message: 'Perfil atualizado com sucesso.' });
    } catch (error) {
        console.error("Erro ao atualizar perfil de usuário:", error);
        res.status(500).json({ error: 'Erro interno ao atualizar perfil de usuário.' });
    }
});

module.exports = router;
