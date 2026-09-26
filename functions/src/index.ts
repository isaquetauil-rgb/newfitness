import * as admin from "firebase-admin";

admin.initializeApp();

export { createSubscriptionCheckout, mercadoPagoWebhook } from "./mercadopago";
export { setStudentPlanTier } from "./plans";
export {
  ensureInviteCode,
  linkToProfessional,
  unlinkFromProfessional,
} from "./linking";
export {
  getAdminStats,
  reviewProfessionalRequest,
  setUserRole,
} from "./admin";
export {
  analyzeMealPhoto,
  askNutritionAI,
  chatWithAI,
  suggestTrainingPlan,
} from "./ai";
