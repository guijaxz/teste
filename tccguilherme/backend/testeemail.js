/// Eu criei este script simples para testar o envio de e-mails através do SendGrid.
/// Ele não faz parte da aplicação principal, é apenas uma ferramenta de desenvolvimento e depuração.
/// O que ele faz:
/// 1. Carrega as variáveis de ambiente, principalmente a API Key do SendGrid.
/// 2. Configura o cliente do SendGrid.
/// 3. Monta uma mensagem de e-mail de teste, com um destinatário, remetente, assunto e corpo definidos diretamente no código.
/// 4. Tenta enviar o e-mail.
/// Eu uso este script para verificar rapidamente se a API Key está correta, se o domínio de envio está
/// autenticado e se os e-mails estão chegando ao destino.
// Carrega as variáveis do arquivo .env
require('dotenv').config();

// Importa a biblioteca do SendGrid
const sgMail = require('@sendgrid/mail');


sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Função assíncrona para enviar o e-mail
const sendTestEmail = async () => {
  // Monta o objeto do e-mail
  const msg = {
    to: 'leonardo.amaral@escalasoft.com.br', 
    
   
    from: 'no-reply@encontre-seu-pet.app.br', 

    subject: 'Teste com Domínio Personalizado - Encontre Seu Pet',
    text: 'Este e-mail foi enviado usando o domínio encontre-seu-pet.app.br!',
    html: '<strong>Este e-mail foi enviado usando o domínio <code>encontre-seu-pet.net.br</code>!</strong>',
  };

  try {
    await sgMail.send(msg);
    console.log('E-mail de teste com domínio personalizado enviado com sucesso!');
  } catch (error) {
    console.error('Erro ao enviar o e-mail:', error);
    if (error.response) {
      console.error(error.response.body);
    }
  }
};

// Chama a função para executar o teste
sendTestEmail();