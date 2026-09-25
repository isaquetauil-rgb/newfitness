// Testes COMPORTAMENTAIS da etapa de Evolução Física — avaliações físicas
// (`physical_assessments`) e fotos de evolução (`body_photos`, no Firestore
// E no Storage). Rodam contra os emuladores de Firestore e Storage (nunca
// produção; projectId "demo-..."; dados 100% fictícios).
//
// Cenário: student1 vinculado a instructor1 e a nutri1; student2 sem vínculo;
// instructor2 não vinculado a ninguém.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  addDoc,
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');

const ROOT = path.join(__dirname, '..');
const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-newfitness-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(ROOT, 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/instructor1'), { name: 'Prof. João', role: 'instructor' });
    await setDoc(doc(db, 'users/instructor2'), { name: 'Prof. Outro', role: 'instructor' });
    await setDoc(doc(db, 'users/nutri1'), { name: 'Nutri', role: 'nutritionist' });
    await setDoc(doc(db, 'users/student1'), {
      name: 'Ana',
      role: 'student',
      instructorId: 'instructor1',
      nutritionistId: 'nutri1',
    });
    await setDoc(doc(db, 'users/student2'), {
      name: 'Bia',
      role: 'student',
      instructorId: null,
      nutritionistId: null,
    });
    // Avaliação lançada pelo instrutor, avaliação do próprio aluno e uma
    // avaliação ANTIGA (formato anterior, sem createdByUid).
    await setDoc(doc(db, 'users/student1/physical_assessments/byInstructor'), assessment({
      recordedBy: 'instructor',
      createdByUid: 'instructor1',
    }));
    await setDoc(doc(db, 'users/student1/physical_assessments/bySelf'), assessment());
    await setDoc(doc(db, 'users/student1/physical_assessments/legacy'), {
      userId: 'student1',
      date: 1700000000000,
      weightKg: 82,
      bodyFatPercent: null,
      measurementsCm: { waist: 90, arm: 35 },
      recordedBy: 'self',
      notes: null,
    });
    await setDoc(doc(db, 'users/student2/physical_assessments/other'), assessment({
      userId: 'student2',
      createdByUid: 'student2',
    }));
    await setDoc(doc(db, 'users/student1/body_photos/p1'), photo());
    await ctx.storage().ref('users/student1/body_photos/p1.jpg').put(jpeg(), {
      contentType: 'image/jpeg',
    });
  });
});

function assessment(overrides = {}) {
  return {
    userId: 'student1',
    date: 1720000000000,
    weightKg: 80,
    heightCm: 175,
    bodyFatPercent: 20,
    bodyFatMethod: 'bioimpedance',
    muscleMassKg: 35,
    measurementsCm: { waist: 90, rightArm: 36 },
    recordedBy: 'self',
    createdByUid: 'student1',
    createdByName: 'Ana',
    createdAt: 1720000000000,
    updatedAt: 1720000000000,
    notes: 'ok',
    ...overrides,
  };
}

function photo(overrides = {}) {
  return {
    userId: 'student1',
    date: 1720000000000,
    position: 'front',
    storagePath: 'users/student1/body_photos/p1.jpg',
    uploadedByUid: 'student1',
    createdAt: 1720000000000,
    note: 'início',
    ...overrides,
  };
}

function jpeg() {
  return new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
}

function ctx(uid) {
  if (uid === 'admin') {
    return testEnv.authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true });
  }
  if (uid === null) return testEnv.unauthenticatedContext();
  return testEnv.authenticatedContext(uid, { email: `${uid}@x.test` });
}
const db = (uid) => ctx(uid).firestore();
const storage = (uid) => ctx(uid).storage();
const A = (uid, id, owner = 'student1') => doc(db(uid), `users/${owner}/physical_assessments/${id}`);
const newA = (uid, owner = 'student1') => collection(db(uid), `users/${owner}/physical_assessments`);

describe('Avaliações físicas — aluno', () => {
  test('E1. aluno cria a própria avaliação (origem self, autor = ele)', async () => {
    await assertSucceeds(addDoc(newA('student1'), assessment()));
  });

  test('E1b. aluno cria avaliação só com algumas medidas (campos opcionais)', async () => {
    await assertSucceeds(
      addDoc(newA('student1'), {
        userId: 'student1',
        date: 1720000000000,
        measurementsCm: { neck: 38 },
        recordedBy: 'self',
        createdByUid: 'student1',
      }),
    );
  });

  test('E2. aluno NÃO cria avaliação fingindo ser do instrutor', async () => {
    await assertFails(addDoc(newA('student1'), assessment({ recordedBy: 'instructor' })));
    await assertFails(
      addDoc(newA('student1'), assessment({ recordedBy: 'instructor', createdByUid: 'instructor1' })),
    );
  });

  test('E3. aluno NÃO grava autor diferente de si mesmo', async () => {
    await assertFails(addDoc(newA('student1'), assessment({ createdByUid: 'student2' })));
  });

  test('E4. aluno NÃO cria avaliação no histórico de outro aluno', async () => {
    await assertFails(
      addDoc(newA('student1', 'student2'), assessment({ userId: 'student2' })),
    );
  });

  test('E5. aluno lê as próprias avaliações, mas NÃO as de outro aluno', async () => {
    await assertSucceeds(getDocs(newA('student1')));
    await assertFails(getDoc(A('student1', 'other', 'student2')));
    await assertFails(getDocs(newA('student1', 'student2')));
  });

  test('E6. aluno NÃO edita nem apaga avaliação lançada pelo instrutor', async () => {
    await assertFails(updateDoc(A('student1', 'byInstructor'), { weightKg: 60 }));
    await assertFails(deleteDoc(A('student1', 'byInstructor')));
  });

  test('E7. aluno edita a própria avaliação, mas NÃO muda autor, origem nem criação', async () => {
    await assertSucceeds(updateDoc(A('student1', 'bySelf'), { weightKg: 79, updatedAt: 1720000001000 }));
    await assertFails(updateDoc(A('student1', 'bySelf'), { createdByUid: 'instructor1' }));
    await assertFails(updateDoc(A('student1', 'bySelf'), { recordedBy: 'instructor' }));
    await assertFails(updateDoc(A('student1', 'bySelf'), { createdAt: 1 }));
    await assertFails(updateDoc(A('student1', 'bySelf'), { userId: 'student2' }));
  });

  test('E8. campo fora da lista e valores inválidos são recusados', async () => {
    await assertFails(addDoc(newA('student1'), assessment({ verifiedByDoctor: true })));
    await assertFails(addDoc(newA('student1'), assessment({ weightKg: '80' })));
    await assertFails(addDoc(newA('student1'), assessment({ bodyFatPercent: 150 })));
    await assertFails(addDoc(newA('student1'), assessment({ weightKg: -5 })));
    await assertFails(addDoc(newA('student1'), assessment({ measurementsCm: 'x' })));
  });

  test('E9. avaliação ANTIGA (sem createdByUid) continua editável/apagável pelo aluno', async () => {
    await assertSucceeds(getDoc(A('student1', 'legacy')));
    await assertSucceeds(updateDoc(A('student1', 'legacy'), { weightKg: 81 }));
    await assertSucceeds(deleteDoc(A('student1', 'legacy')));
  });

  test('E10. aluno apaga a própria avaliação', async () => {
    await assertSucceeds(deleteDoc(A('student1', 'bySelf')));
  });
});

describe('Avaliações físicas — instrutor, nutricionista, admin, anônimo', () => {
  test('E11. instrutor vinculado lê e lança avaliação (origem instructor, autor = ele)', async () => {
    await assertSucceeds(getDocs(newA('instructor1')));
    await assertSucceeds(
      addDoc(newA('instructor1'), assessment({ recordedBy: 'instructor', createdByUid: 'instructor1' })),
    );
  });

  test('E12. instrutor vinculado NÃO lança como se fosse o aluno', async () => {
    await assertFails(addDoc(newA('instructor1'), assessment({ recordedBy: 'self', createdByUid: 'instructor1' })));
    await assertFails(addDoc(newA('instructor1'), assessment({ recordedBy: 'instructor', createdByUid: 'student1' })));
  });

  test('E13. instrutor edita/apaga só o que ele lançou', async () => {
    await assertSucceeds(updateDoc(A('instructor1', 'byInstructor'), { weightKg: 78 }));
    await assertFails(updateDoc(A('instructor1', 'bySelf'), { weightKg: 78 }));
    await assertFails(deleteDoc(A('instructor1', 'bySelf')));
    await assertFails(updateDoc(A('instructor1', 'legacy'), { weightKg: 78 }));
    await assertSucceeds(deleteDoc(A('instructor1', 'byInstructor')));
  });

  test('E14. instrutor NÃO vinculado não lê nem lança avaliação', async () => {
    await assertFails(getDoc(A('instructor2', 'bySelf')));
    await assertFails(getDocs(newA('instructor2')));
    await assertFails(
      addDoc(newA('instructor2'), assessment({ recordedBy: 'instructor', createdByUid: 'instructor2' })),
    );
    await assertFails(getDoc(A('instructor1', 'other', 'student2')));
  });

  test('E15. instrutor que perde o vínculo perde o acesso (inclusive ao que lançou)', async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await updateDoc(doc(c.firestore(), 'users/student1'), { instructorId: 'instructor2' });
    });
    await assertFails(getDoc(A('instructor1', 'byInstructor')));
    await assertFails(updateDoc(A('instructor1', 'byInstructor'), { weightKg: 70 }));
  });

  test('E16. nutricionista vinculada lê, mas NÃO lança avaliação', async () => {
    await assertSucceeds(getDoc(A('nutri1', 'bySelf')));
    await assertFails(
      addDoc(newA('nutri1'), assessment({ recordedBy: 'instructor', createdByUid: 'nutri1' })),
    );
  });

  test('E17. admin lê e apaga avaliações (moderação)', async () => {
    await assertSucceeds(getDoc(A('admin', 'bySelf')));
    await assertSucceeds(deleteDoc(A('admin', 'bySelf')));
  });

  test('E18. anônimo não acessa avaliações', async () => {
    await assertFails(getDoc(A(null, 'bySelf')));
    await assertFails(addDoc(newA(null), assessment()));
  });
});

describe('Fotos de evolução — Firestore', () => {
  const P = (uid, id, owner = 'student1') => doc(db(uid), `users/${owner}/body_photos/${id}`);
  const newP = (uid, owner = 'student1') => collection(db(uid), `users/${owner}/body_photos`);

  test('F1. aluno registra foto com data, posição e observação', async () => {
    await assertSucceeds(addDoc(newP('student1'), photo({ position: 'back' })));
    // posição nova (extensível) também é aceita
    await assertSucceeds(addDoc(newP('student1'), photo({ position: 'front_relaxed' })));
  });

  test('F2. aluno NÃO aponta a foto para o arquivo de outro aluno nem grava campo extra', async () => {
    await assertFails(
      addDoc(newP('student1'), photo({ storagePath: 'users/student2/body_photos/x.jpg' })),
    );
    await assertFails(addDoc(newP('student1'), photo({ uploadedByUid: 'instructor1' })));
    await assertFails(addDoc(newP('student1'), photo({ imageUrl: 'https://public.example/x.jpg' })));
  });

  test('F3. aluno NÃO lê nem cria fotos de outro aluno', async () => {
    await assertFails(getDoc(P('student2', 'p1')));
    await assertFails(
      addDoc(newP('student2', 'student1'), photo({ uploadedByUid: 'student2' })),
    );
  });

  test('F4. instrutor vinculado e nutricionista vinculada LEEM; não vinculado não', async () => {
    await assertSucceeds(getDoc(P('instructor1', 'p1')));
    await assertSucceeds(getDoc(P('nutri1', 'p1')));
    await assertFails(getDoc(P('instructor2', 'p1')));
  });

  test('F5. instrutor NÃO cria, edita nem apaga fotos do aluno', async () => {
    await assertFails(addDoc(newP('instructor1'), photo({ uploadedByUid: 'instructor1' })));
    await assertFails(updateDoc(P('instructor1', 'p1'), { note: 'x' }));
    await assertFails(deleteDoc(P('instructor1', 'p1')));
  });

  test('F6. registro de foto é imutável; dono apaga', async () => {
    await assertFails(updateDoc(P('student1', 'p1'), { position: 'back' }));
    await assertSucceeds(deleteDoc(P('student1', 'p1')));
  });

  test('F7. admin não lê foto corporal; anônimo também não', async () => {
    await assertFails(getDoc(P('admin', 'p1')));
    await assertFails(getDoc(P(null, 'p1')));
  });
});

describe('Fotos de evolução — Storage', () => {
  const file = (uid, owner = 'student1', name = 'p1.jpg') =>
    storage(uid).ref(`users/${owner}/body_photos/${name}`);

  test('S1. aluno envia imagem para a própria pasta e lê de volta', async () => {
    await assertSucceeds(file('student1', 'student1', 'new.jpg').put(jpeg(), { contentType: 'image/jpeg' }));
    await assertSucceeds(file('student1').getMetadata());
  });

  test('S2. aluno NÃO envia arquivo que não é imagem, nem acima de 10 MB', async () => {
    await assertFails(
      file('student1', 'student1', 'x.pdf').put(new Uint8Array([1, 2, 3]), { contentType: 'application/pdf' }),
    );
    await assertFails(
      file('student1', 'student1', 'big.jpg').put(new Uint8Array(10 * 1024 * 1024 + 1), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('S3. aluno NÃO lê nem envia na pasta de outro aluno', async () => {
    await assertFails(file('student2').getMetadata());
    await assertFails(file('student2', 'student1', 'intruso.jpg').put(jpeg(), { contentType: 'image/jpeg' }));
  });

  test('S4. instrutor/nutricionista vinculados leem; instrutor não vinculado não', async () => {
    await assertSucceeds(file('instructor1').getMetadata());
    await assertSucceeds(file('nutri1').getMetadata());
    await assertFails(file('instructor2').getMetadata());
  });

  test('S5. instrutor vinculado NÃO envia nem apaga fotos do aluno', async () => {
    await assertFails(file('instructor1', 'student1', 'i.jpg').put(jpeg(), { contentType: 'image/jpeg' }));
    await assertFails(file('instructor1').delete());
  });

  test('S6. dono apaga; admin e anônimo não leem', async () => {
    await assertFails(file('admin').getMetadata());
    await assertFails(file(null).getMetadata());
    await assertSucceeds(file('student1').delete());
  });
});
