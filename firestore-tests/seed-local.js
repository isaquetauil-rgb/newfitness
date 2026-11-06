// Cria contas e dados FICTÍCIOS no Firebase Emulator local, para testar o app
// sem o projeto real. Recusa rodar sem os emuladores. Ver README.md.
'use strict';

process.env.GCLOUD_PROJECT = 'newfitnessappbr';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: 'newfitnessappbr' });

const PASSWORD = 'teste-local-123';
const ACCOUNTS = [
  { uid: 'local-admin', email: 'isaquetrabalho005@gmail.com', name: 'Admin Local', role: 'student' },
  { uid: 'local-personal', email: 'personal@teste.local', name: 'Personal Teste', role: 'instructor' },
  { uid: 'local-aluno', email: 'aluno@teste.local', name: 'Aluno Teste', role: 'student' },
];

async function main() {
  for (const a of ACCOUNTS) {
    await admin.auth().createUser({
      uid: a.uid, email: a.email, password: PASSWORD, displayName: a.name, emailVerified: true,
    });
    await admin.firestore().doc(`users/${a.uid}`).set({
      uid: a.uid, name: a.name, email: a.email, role: a.role, createdAt: Date.now(),
    });
    console.log(`${a.role.padEnd(10)} ${a.email}`);
  }
  console.log(`senha das contas locais: ${PASSWORD}`);
}

main().catch((err) => { console.error(err); process.exit(1); });
