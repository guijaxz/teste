// server.js

/// Este é o arquivo principal que inicia todo o meu backend.
/// O que eu faço aqui, passo a passo:
/// 1. Carrego as variáveis de ambiente do arquivo .env com `dotenv`. Isso é importante para manter
///    as chaves de API e outras configurações seguras e fora do código.
/// 2. Inicializo o Express, que é o framework que eu escolhi para construir a API.
/// 3. Configuro o Firebase Admin SDK, passando as credenciais do `firebase-credentials.json` e o nome
///    do bucket do Storage. Isso permite que o backend interaja com os serviços do Firebase.
/// 4. Adiciono o middleware `express.json()` para que a API consiga interpretar o corpo das requisições
///    que vêm em formato JSON.
/// 5. Importo e registro as rotas de 'pets' e 'users', associando-as aos seus respectivos caminhos base
///    ('/api/pets' e '/api/users').
/// 6. Crio uma rota raiz ('/') apenas para verificar se o servidor está online.
/// 7. Inicio o servidor para que ele comece a "ouvir" as requisições na porta definida.
require('dotenv').config();
const express = require('express');
const admin = require('firebase-admin');
const app = express();
const port = 3000;


const serviceAccount = require('./firebase-credentials.json');


app.use(express.json());

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET
});

const petRoutes = require('./src/routes/pets');
const userRoutes = require('./src/routes/users');

app.use('/api/pets', petRoutes);
app.use('/api/users', userRoutes);

app.get('/', (req, res) => {
  res.send('Backend do Encontre Seu Pet está no ar!');
});

app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});