// Auditoria da biblioteca de exercícios no Firestore REAL. SÓ LEITURA:
// nenhum documento é criado, alterado ou apagado.
//
// Uso (na pasta do projeto):
//   node tool/auditoria_exercicios.js <chave-da-conta-de-servico.json> [saida.json]
// A chave fica FORA do repositório (ex.: C:\dev\chaves). Sem a saída, imprime
// o resumo na tela.
'use strict';

const path = require('path');
const fs = require('fs');

const [keyPath, outPath] = process.argv.slice(2);
if (!keyPath) {
  console.error('Uso: node tool/auditoria_exercicios.js <chave.json> [saida.json]');
  process.exit(1);
}
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();

const norm = (s) =>
  String(s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\(.*?\)/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const empty = (v) => v == null || (typeof v === 'string' && !v.trim()) || (Array.isArray(v) && v.length === 0);

async function main() {
  const general = (await db.collection('exercises').get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const customSnap = await db.collectionGroup('custom_exercises').get();
  const owners = {};
  const custom = [];
  for (const d of customSnap.docs) {
    const ownerUid = d.ref.parent.parent.id;
    if (!(ownerUid in owners)) {
      const u = await db.doc(`users/${ownerUid}`).get();
      owners[ownerUid] = { name: u.get('name') || '', email: u.get('email') || '', role: u.get('role') || '' };
    }
    custom.push({ id: d.id, ownerUid, ...d.data() });
  }
  const muscleGroups = (await db.collection('muscle_groups').get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  const equipment = (await db.collection('equipment').get()).docs.map((d) => ({ id: d.id, ...d.data() }));

  const all = [...general.map((e) => ({ ...e, scope: 'geral' })), ...custom.map((e) => ({ ...e, scope: 'personal' }))];
  const ids = new Set(all.map((e) => e.id));

  // Duplicados: mesmo nome (normalizado) ou mesmo nome alternativo.
  const byName = {};
  for (const e of all) {
    for (const n of [e.name, e.alternateName]) {
      const k = norm(n);
      if (!k) continue;
      (byName[k] ||= new Set()).add(`${e.id} (${e.scope})`);
    }
  }
  const duplicates = Object.entries(byName)
    .filter(([, s]) => s.size > 1)
    .map(([name, s]) => ({ name, ids: [...s] }));

  const brokenRefs = [];
  for (const e of all) {
    for (const field of ['alternativeExerciseIds', 'variationExerciseIds']) {
      for (const ref of e[field] || []) {
        if (!ids.has(ref)) brokenRefs.push({ id: e.id, field, ref });
      }
    }
  }

  const fields = ['secondaryMuscles', 'instructions', 'commonMistakes', 'careNotes', 'executionNotes', 'description',
    'category', 'movementPattern', 'difficultyLevel', 'videoUrl', 'alternativeExerciseIds', 'searchTags'];
  const missing = {};
  for (const f of fields) missing[f] = all.filter((e) => empty(e[f])).map((e) => e.id);

  const count = (key) => {
    const c = {};
    for (const e of all) {
      const v = Array.isArray(e[key]) ? e[key] : [e[key] ?? ''];
      for (const x of v) c[x || '(vazio)'] = (c[x || '(vazio)'] || 0) + 1;
    }
    return c;
  };

  const report = {
    geradoEm: new Date().toISOString(),
    totais: {
      gerais: general.length,
      geraisArquivados: general.filter((e) => e.archived === true).length,
      personalizados: custom.length,
      porDono: Object.entries(owners).map(([uid, o]) => ({ uid, ...o, quantidade: custom.filter((c) => c.ownerUid === uid).length })),
    },
    taxonomia: {
      gruposMuscularesColecao: muscleGroups.map((g) => g.name),
      equipamentosColecao: equipment.map((g) => g.name),
      gruposUsados: count('muscleGroup'),
      musculosSecundariosUsados: count('secondaryMuscles'),
      equipamentosUsados: count('equipment'),
      categoriasUsadas: count('category'),
      padroesUsados: count('movementPattern'),
      dificuldadesUsadas: count('difficultyLevel'),
    },
    duplicados: duplicates,
    alternativasQuebradas: brokenRefs,
    camposVazios: missing,
    exercicios: all.map((e) => ({
      id: e.id, escopo: e.scope, nome: e.name, nomeAlternativo: e.alternateName || '', grupo: e.muscleGroup,
      secundarios: e.secondaryMuscles || [], equipamento: e.equipment, categoria: e.category || '',
      padrao: e.movementPattern || '', dificuldade: e.difficultyLevel || '', unilateral: e.isUnilateral === true,
      porTempo: e.tracksDuration === true, distancia: e.tracksDistance === true,
      temInstrucoes: !empty(e.instructions), temErros: !empty(e.commonMistakes), temCuidados: !empty(e.careNotes),
      temVideo: !empty(e.videoUrl), alternativas: e.alternativeExerciseIds || [], arquivado: e.archived === true,
    })),
  };

  if (outPath) {
    fs.writeFileSync(outPath, JSON.stringify(report, null, 2));
    console.log(`Relatório gravado em ${outPath}`);
  }
  console.log(JSON.stringify({ totais: report.totais, duplicados: duplicates.length, alternativasQuebradas: brokenRefs.length }, null, 2));
}

main().then(() => process.exit(0)).catch((e) => { console.error(e.message); process.exit(1); });
