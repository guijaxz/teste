const admin = require('firebase-admin');

/// Eu criei este middleware para proteger as rotas que exigem autenticação.
/// Ele funciona como um porteiro para as rotas da API.
/// O que ele faz:
/// 1. Pega o cabeçalho 'Authorization' da requisição.
/// 2. Verifica se o cabeçalho existe e se está no formato correto ('Bearer <token>').
/// 3. Extrai o token JWT.
/// 4. Usa o SDK Admin do Firebase (`verifyIdToken`) para checar se o token é válido e não expirou.
/// 5. Se o token for válido, eu extraio os dados do usuário (como o UID) e os anexo ao objeto `res.locals`.
///    Dessa forma, a rota que for chamada em seguida já terá acesso às informações do usuário autenticado.
/// 6. Se o token for inválido por qualquer motivo, eu bloqueio a requisição e retorno um erro 401 (Não autorizado).
const authMiddleware = async (req, res, next) => {
    const { authorization } = req.headers;

    if (!authorization || !authorization.startsWith('Bearer ')) {
        return res.status(401).send({ message: 'Token não fornecido ou em formato inválido.' });
    }

    const split = authorization.split('Bearer ');
    if (split.length !== 2) {
        return res.status(401).send({ message: 'Token malformado.' });
    }

    const token = split[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        res.locals.user = decodedToken;
        return next();
    } catch (err) {
        console.error(`${err.code} -  ${err.message}`);
        return res.status(401).send({ message: 'Não autorizado' });
    }
};

module.exports = authMiddleware;
