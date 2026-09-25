// Testes COMPORTAMENTAIS das Firestore Security Rules — rodam operações de
// verdade (leitura/escrita) como usuários diferentes contra o Firestore
// Emulator, e confirmam que cada uma é permitida ou negada corretamente.
// Isso é diferente de um teste que só olha o texto de `firestore.rules`
// (ver `test/unit/firestore_rules_test.dart`, no lado Flutter) — aqui a
// própria engine de regras do Firestore decide.
//
// NUNCA roda contra o Firestore de produção: `initializeTestEnvironment`
// aponta para o emulador local (ver host/port abaixo), com um projectId
// fake ("demo-..."). Todos os usuários/dados usados são fictícios.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, updateDoc, setDoc, deleteDoc } = require('firebase/firestore');

const RULES_PATH = path.join(__dirname, '..', 'firestore.rules');
const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-newfitness-rules-test',
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

/** Escreve dados de teste direto, ignorando as regras (é o "seed" do cenário). */
async function seed(setupFn) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setupFn(context.firestore());
  });
}

function asStudent(uid) {
  return testEnv.authenticatedContext(uid, { email: `${uid}@aluno.test` }).firestore();
}

function asInstructor(uid) {
  return testEnv.authenticatedContext(uid, { email: `${uid}@instrutor.test` }).firestore();
}

function asAdmin() {
  return testEnv.authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true }).firestore();
}

function asAnonymous() {
  return testEnv.unauthenticatedContext().firestore();
}

describe('Aluno — próprio perfil', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users/student1'), {
        name: 'Ana',
        email: 'ana@x.com',
        role: 'student',
        instructorId: null,
        nutritionistId: null,
        inviteCode: null,
        weightKg: 60,
      });
      await setDoc(doc(db, 'users/student2'), {
        name: 'Beto',
        email: 'beto@x.com',
        role: 'student',
        instructorId: null,
        nutritionistId: null,
        inviteCode: null,
      });
    });
  });

  test('1. aluno consegue ler o próprio perfil', async () => {
    await assertSucceeds(getDoc(doc(asStudent('student1'), 'users/student1')));
  });

  test('2. aluno consegue atualizar campos permitidos do próprio perfil', async () => {
    await assertSucceeds(
      updateDoc(doc(asStudent('student1'), 'users/student1'), { weightKg: 61.5, name: 'Ana Silva' }),
    );
  });

  test('3. aluno NÃO consegue alterar role', async () => {
    await assertFails(
      updateDoc(doc(asStudent('student1'), 'users/student1'), { role: 'instructor' }),
    );
  });

  test('4. aluno NÃO consegue alterar instructorId', async () => {
    await assertFails(
      updateDoc(doc(asStudent('student1'), 'users/student1'), { instructorId: 'instructor1' }),
    );
  });

  test('5. aluno NÃO consegue alterar nutritionistId', async () => {
    await assertFails(
      updateDoc(doc(asStudent('student1'), 'users/student1'), { nutritionistId: 'nutri1' }),
    );
  });

  test('6. aluno NÃO consegue alterar inviteCode', async () => {
    await assertFails(
      updateDoc(doc(asStudent('student1'), 'users/student1'), { inviteCode: 'FAKE01' }),
    );
  });

  test('7. aluno NÃO consegue ler o perfil de outro aluno', async () => {
    await assertFails(getDoc(doc(asStudent('student1'), 'users/student2')));
  });

  test('8. aluno NÃO consegue alterar dados de outro aluno', async () => {
    await assertFails(
      updateDoc(doc(asStudent('student1'), 'users/student2'), { name: 'Hackeado' }),
    );
  });
});

describe('Aluno — workouts e progress_records', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users/student1'), { name: 'Ana', email: 'a@x.com', role: 'student' });
      await setDoc(doc(db, 'users/student2'), { name: 'Beto', email: 'b@x.com', role: 'student' });
      await setDoc(doc(db, 'users/student1/workouts/w1'), { userId: 'student1', name: 'Treino A' });
      await setDoc(doc(db, 'users/student2/workouts/w1'), { userId: 'student2', name: 'Treino B' });
      await setDoc(doc(db, 'users/student1/progress_records/bench_press'), {
        exerciseName: 'Supino reto',
        bestLoadKg: 60,
      });
      await setDoc(doc(db, 'users/student2/progress_records/bench_press'), {
        exerciseName: 'Supino reto',
        bestLoadKg: 40,
      });
    });
  });

  test('9. aluno consegue ler os próprios workouts', async () => {
    await assertSucceeds(getDoc(doc(asStudent('student1'), 'users/student1/workouts/w1')));
  });

  test('10. aluno NÃO consegue ler workouts de outro aluno', async () => {
    await assertFails(getDoc(doc(asStudent('student1'), 'users/student2/workouts/w1')));
  });

  test('11. aluno consegue ler o próprio progress_records', async () => {
    await assertSucceeds(
      getDoc(doc(asStudent('student1'), 'users/student1/progress_records/bench_press')),
    );
  });

  test('12. aluno NÃO consegue ler progress_records de outro aluno', async () => {
    await assertFails(
      getDoc(doc(asStudent('student1'), 'users/student2/progress_records/bench_press')),
    );
  });
});

describe('Instrutor — escopo de acesso aos alunos', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users/instructor1'), {
        name: 'Prof. João',
        email: 'joao@x.com',
        role: 'instructor',
        inviteCode: 'ABC123',
      });
      // student1 está vinculado a instructor1; student3 não está vinculado a ninguém.
      await setDoc(doc(db, 'users/student1'), {
        name: 'Ana',
        email: 'a@x.com',
        role: 'student',
        instructorId: 'instructor1',
      });
      await setDoc(doc(db, 'users/student3'), {
        name: 'Carla',
        email: 'c@x.com',
        role: 'student',
        instructorId: null,
      });
      await setDoc(doc(db, 'users/student1/workouts/w1'), { userId: 'student1', name: 'Treino A' });
      await setDoc(doc(db, 'users/student1/physical_assessments/a1'), { userId: 'student1', weightKg: 70 });
      await setDoc(doc(db, 'users/student1/body_photos/p1'), { userId: 'student1', url: 'x' });
    });
  });

  test('13. instrutor consegue acessar os alunos vinculados a ele', async () => {
    await assertSucceeds(getDoc(doc(asInstructor('instructor1'), 'users/student1')));
    await assertSucceeds(getDoc(doc(asInstructor('instructor1'), 'users/student1/workouts/w1')));
  });

  test('14. instrutor NÃO consegue acessar aluno que não está vinculado a ele', async () => {
    await assertFails(getDoc(doc(asInstructor('instructor1'), 'users/student3')));
  });

  test(
    '15. instrutor acessa exatamente o que a arquitetura permite — treinos e ' +
      'avaliação física e fotos de evolução do aluno vinculado (fotos liberadas ao ' +
      'instrutor na etapa de Evolução Física — ver evolution.test.js)',
    async () => {
      await assertSucceeds(
        setDoc(doc(asInstructor('instructor1'), 'users/student1/training_plans/plan1'), {
          studentUid: 'student1',
          instructorUid: 'instructor1',
          title: 'Plano A',
          workouts: [],
        }),
      );
      await assertSucceeds(
        getDoc(doc(asInstructor('instructor1'), 'users/student1/physical_assessments/a1')),
      );
      await assertSucceeds(getDoc(doc(asInstructor('instructor1'), 'users/student1/body_photos/p1')));
    },
  );

  test('16. instrutor NÃO consegue alterar role de um usuário', async () => {
    await assertFails(
      updateDoc(doc(asInstructor('instructor1'), 'users/student1'), { role: 'instructor' }),
    );
  });

  test('17. instrutor NÃO consegue criar um vínculo arbitrário com um aluno', async () => {
    await assertFails(
      updateDoc(doc(asInstructor('instructor1'), 'users/student3'), { instructorId: 'instructor1' }),
    );
  });

  test('18. instrutor NÃO consegue alterar instructorId de um aluno diretamente', async () => {
    await assertFails(
      updateDoc(doc(asInstructor('instructor1'), 'users/student1'), { instructorId: 'outro-instrutor' }),
    );
  });

  test('28. o vínculo continua concedendo acesso numa sessão nova (novo contexto/login)', async () => {
    // Simula "logar de novo": um contexto autenticado totalmente novo para o
    // mesmo instrutor, sem reaproveitar nada da sessão anterior — o que
    // importa é o campo `instructorId` já persistido no Firestore, não
    // nenhum estado local de sessão.
    const freshSessionDb = testEnv
      .authenticatedContext('instructor1', { email: 'joao@x.com' })
      .firestore();
    await assertSucceeds(getDoc(doc(freshSessionDb, 'users/student1')));
    await assertSucceeds(getDoc(doc(freshSessionDb, 'users/student1/workouts/w1')));
  });
});

describe('Administrador', () => {
  test('19. admin consegue criar, editar e excluir muscle_groups', async () => {
    const db = asAdmin();
    await assertSucceeds(setDoc(doc(db, 'muscle_groups/peito'), { name: 'Peito' }));
    await assertSucceeds(updateDoc(doc(db, 'muscle_groups/peito'), { name: 'Peitoral' }));
    await assertSucceeds(deleteDoc(doc(db, 'muscle_groups/peito')));
  });

  test('19b. aluno NÃO consegue gravar em muscle_groups', async () => {
    await seed(async (db) => setDoc(doc(db, 'users/student1'), { role: 'student' }));
    await assertFails(setDoc(doc(asStudent('student1'), 'muscle_groups/peito'), { name: 'Peito' }));
  });

  test('20. admin consegue criar, editar e excluir equipment', async () => {
    const db = asAdmin();
    await assertSucceeds(setDoc(doc(db, 'equipment/barra'), { name: 'Barra' }));
    await assertSucceeds(updateDoc(doc(db, 'equipment/barra'), { name: 'Barra olímpica' }));
    await assertSucceeds(deleteDoc(doc(db, 'equipment/barra')));
  });

  test('21. admin gerencia exercícios da biblioteca global', async () => {
    const db = asAdmin();
    await assertSucceeds(
      setDoc(doc(db, 'exercises/bench_press'), { name: 'Supino reto', muscleGroup: 'Peito' }),
    );
    await assertSucceeds(deleteDoc(doc(db, 'exercises/bench_press')));
  });

  test('21b. instrutor NÃO consegue gravar na biblioteca global de exercícios', async () => {
    await seed(async (db) => setDoc(doc(db, 'users/instructor1'), { role: 'instructor' }));
    await assertFails(
      setDoc(doc(asInstructor('instructor1'), 'exercises/bench_press'), { name: 'Supino reto' }),
    );
  });

  test(
    '22. admin lê qualquer perfil; mudar papel é só pela Cloud Function setUserRole ' +
      '(gravar `role` direto é negado até para o admin — ver demotion.test.js)',
    async () => {
      await seed(async (db) =>
        setDoc(doc(db, 'users/student1'), { name: 'Ana', role: 'student', instructorId: null }),
      );
      const db = asAdmin();
      await assertSucceeds(getDoc(doc(db, 'users/student1')));
      await assertFails(updateDoc(doc(db, 'users/student1'), { role: 'instructor' }));
      await assertSucceeds(updateDoc(doc(db, 'users/student1'), { name: 'Ana Maria' }));
    },
  );
});

describe('Acesso não autenticado', () => {
  test('usuário anônimo não lê nada em users/', async () => {
    await seed(async (db) => setDoc(doc(db, 'users/student1'), { role: 'student' }));
    await assertFails(getDoc(doc(asAnonymous(), 'users/student1')));
  });
});
