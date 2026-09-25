import * as admin from "firebase-admin";

/**
 * Acumula gravações e faz commit em lotes de no máximo [maxOps] operações
 * (o Firestore aceita até 500 por batch). As operações são confirmadas NA
 * ORDEM em que foram enfileiradas — quem chama pode contar com isso (ex:
 * zerar o vínculo do aluno antes de mexer no resto).
 *
 * Não é atômico entre lotes: quem usa precisa ser idempotente (poder rodar
 * de novo e terminar o que ficou pela metade).
 */
export class ChunkedWriter {
  private batch: admin.firestore.WriteBatch;
  private ops = 0;

  constructor(
    private readonly db: admin.firestore.Firestore,
    private readonly maxOps = 400
  ) {
    this.batch = db.batch();
  }

  async set(
    ref: admin.firestore.DocumentReference,
    data: admin.firestore.DocumentData,
    options: admin.firestore.SetOptions = {}
  ): Promise<void> {
    this.batch.set(ref, data, options);
    await this.bump();
  }

  async update(
    ref: admin.firestore.DocumentReference,
    data: admin.firestore.UpdateData<admin.firestore.DocumentData>
  ): Promise<void> {
    this.batch.update(ref, data);
    await this.bump();
  }

  /** Confirma o que ainda estiver pendente. */
  async flush(): Promise<void> {
    if (this.ops === 0) return;
    await this.batch.commit();
    this.batch = this.db.batch();
    this.ops = 0;
  }

  private async bump(): Promise<void> {
    this.ops++;
    if (this.ops >= this.maxOps) await this.flush();
  }
}
