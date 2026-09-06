/// E-mail do dono do app — único usuário com acesso ao painel de
/// administração. Verificado também no `firestore.rules`
/// (`request.auth.token.email`), que é a barreira de segurança real; a
/// checagem aqui só controla o que a UI mostra.
const ownerEmail = 'isaquetrabalho005@gmail.com';
