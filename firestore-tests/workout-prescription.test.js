// Não-regressão (#14): um treino com `prescription` (cópia do exercício do
// plano) e `source` (origem do plano) continua sendo aceito e protegido
// pelas regras EXISTENTES de `workouts` — nenhuma regra foi alterada.
'use strict';

const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

let testEnv;
let dbs;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-newfitness-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  dbs = new Map();
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const seedDb = c.firestore();
    await setDoc(doc(seedDb, 'users/aluno'), { role: 'student', instructorId: 'prof' });
    await setDoc(doc(seedDb, 'users/prof'), { role: 'instructor' });
    await setDoc(doc(seedDb, 'users/outroProf'), { role: 'instructor' });
    await setDoc(doc(seedDb, 'users/outroAluno'), { role: 'student', instructorId: null });
  });
});

const db = (uid) => {
  if (!dbs.has(uid)) dbs.set(uid, testEnv.authenticatedContext(uid, { email: `${uid}@x.test` }).firestore());
  return dbs.get(uid);
};

// Formato exato gravado pelo app (Workout.toMap / LoggedExercise.toMap).
const workoutWithPrescription = {
  userId: 'aluno',
  date: 1720000000000,
  name: 'Hipertrofia · Treino A',
  durationSeconds: 1800,
  source: { planId: 'plan1', planTitle: 'Hipertrofia', subWorkoutLabel: 'Treino A' },
  exercises: [
    {
      exerciseId: 'supino_inclinado',
      exerciseName: 'Supino inclinado',
      sets: [
        { reps: 10, weightKg: 30, completed: true },
        { reps: 8, weightKg: 32, completed: true },
      ],
      replacedExerciseId: 'supino_reto',
      replacedExerciseName: 'Supino reto',
      prescription: {
        exerciseId: 'supino_reto',
        exerciseName: 'Supino reto',
        targetSets: 4,
        targetReps: '10',
        targetWeightsKg: '30',
        restSeconds: 90,
        notes: 'Controlar a descida',
        replacedExerciseId: null,
        replacedExerciseName: null,
      },
    },
  ],
};

test('treino com prescription/source: aluno grava e lê; instrutor vinculado lê; não vinculados não', async () => {
  const path = 'users/aluno/workouts/w1';
  await assertSucceeds(setDoc(doc(db('aluno'), path), workoutWithPrescription));
  await assertSucceeds(getDoc(doc(db('aluno'), path)));
  await assertSucceeds(getDoc(doc(db('prof'), path)));
  await assertFails(getDoc(doc(db('outroProf'), path)));
  await assertFails(getDoc(doc(db('outroAluno'), path)));
  // e ninguém além do dono grava treino dele (inalterado)
  await assertFails(setDoc(doc(db('prof'), 'users/aluno/workouts/w2'), workoutWithPrescription));
});
