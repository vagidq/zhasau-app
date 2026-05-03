const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

initializeApp();

/**
 * Callable: только авторизованный пользователь, отправка на свой fcmToken из users/{uid}.
 * Данные: { title?: string, body?: string }
 */
exports.sendPushToSelf = onCall({region: "us-central1"}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Нужна авторизация Firebase");
  }
  const uid = request.auth.uid;
  const title =
      typeof request.data?.title === "string" && request.data.title.trim().length > 0
        ? request.data.title.trim().slice(0, 120)
        : "Zhasau";
  const body =
      typeof request.data?.body === "string" && request.data.body.trim().length > 0
        ? request.data.body.trim().slice(0, 500)
        : "Тестовое уведомление";

  const snap = await getFirestore().doc(`users/${uid}`).get();
  const token = snap.get("fcmToken");
  if (!token || typeof token !== "string") {
    throw new HttpsError(
        "failed-precondition",
        "Нет сохранённого FCM-токена. Откройте приложение после входа.",
    );
  }

  try {
    await getMessaging().send({
      token,
      notification: {title, body},
    });
  } catch (e) {
    throw new HttpsError(
        "internal",
        e?.message || "Ошибка отправки FCM",
    );
  }
  return {ok: true};
});
