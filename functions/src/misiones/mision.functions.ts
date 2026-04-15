import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

// ============================================================================
// 🔔 TRIGGER 1: NUEVA SOLICITUD (Avisar a todos los Admins)
// ============================================================================
export const notificarNuevaMision = onDocumentCreated("misiones/{misionId}", async (event: any) => {
  const nuevaMision = event.data?.data();
  if (!nuevaMision) return;

  const db = admin.firestore();

  try {
    // Buscamos a todos los Admins (que ahora funcionan como jefes)
    const adminsSnapshot = await db.collection("usuarios")
      .where("rol", "==", "admin") // 🔥 Cambiado: Solo buscamos "admin"
      .get();

    const tokensAdmins: string[] = [];
    adminsSnapshot.forEach((doc: any) => {
      if (doc.data().fcm_token) tokensAdmins.push(doc.data().fcm_token);
    });

    if (tokensAdmins.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens: tokensAdmins,
        notification: {
          title: "📝 Nueva Solicitud de Salida",
          body: `${nuevaMision.nombre_trabajador} solicita ir a: ${nuevaMision.destino}`,
        },
        android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
      });
      console.log(`Notificación de nueva solicitud enviada a ${tokensAdmins.length} admins.`);
    }
  } catch (error) {
    console.error("Error enviando notificación de nueva misión:", error);
  }
});

// ============================================================================
// 🔔 TRIGGER 2: CAMBIOS DE ESTADO (Aprobaciones, rechazos y retornos)
// ============================================================================
export const notificarActualizacionMision = onDocumentUpdated("misiones/{misionId}", async (event: any) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();

  if (!before || !after) return;

  const db = admin.firestore();
  const trabajadorId = after.trabajador_id;

  try {
    // ==========================================================
    // 🚦 CASO A: EL ADMIN RECHAZA LA MISIÓN (Avisar al trabajador)
    // ==========================================================
    if (after.estado === "rechazado" && before.estado !== "rechazado") {
      const trabajadorDoc = await db.collection("usuarios").doc(trabajadorId).get();
      const fcmToken = trabajadorDoc.data()?.fcm_token;

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "❌ Solicitud Rechazada",
            body: `Motivo: ${after.motivo_rechazo || "Revisa la app para más detalles."}`,
          },
          android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
        });
      }
    }

    // ==========================================================
    // 🚦 CASO B: LA MISIÓN ES 100% APROBADA (Avisar al trabajador)
    // ==========================================================
    else if (after.estado === "aprobado" && before.estado !== "aprobado") {
      const trabajadorDoc = await db.collection("usuarios").doc(trabajadorId).get();
      const fcmToken = trabajadorDoc.data()?.fcm_token;

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "✅ ¡Misión Aprobada!",
            body: `Ya tienes luz verde para salir hacia: ${after.destino}`,
          },
          android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
        });
      }
    }

    // ==========================================================
    // 🚦 CASO C: PRIMERA FIRMA LISTA (Avisar a Trabajador Y al OTRO Admin)
    // ==========================================================
    else if (after.firmas?.length === 1 && (before.firmas?.length === 0 || !before.firmas)) {
      const idAdminQueFirmo = after.firmas[0].jefe_id; // Mantenemos el nombre de la variable, pero es un Admin
      const nombreAdminQueFirmo = after.firmas[0].nombre_jefe;

      // --- 1. Avisar al trabajador ---
      const trabajadorDoc = await db.collection("usuarios").doc(trabajadorId).get();
      const fcmTokenTrabajador = trabajadorDoc.data()?.fcm_token;

      if (fcmTokenTrabajador) {
        await admin.messaging().send({
          token: fcmTokenTrabajador,
          notification: {
            title: "✍️ Firma 1/2 Registrada",
            body: `${nombreAdminQueFirmo} aprobó tu salida. Esperando al segundo administrador...`,
          },
          android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
        });
      }

      // --- 2. Recordatorio para los OTROS Admins ---
      const adminsSnapshot = await db.collection("usuarios")
        .where("rol", "==", "admin") // 🔥 Cambiado
        .get();

      const tokensOtrosAdmins: string[] = [];
      adminsSnapshot.forEach((doc: any) => {
        // Excluimos al admin que acaba de firmar
        if (doc.id !== idAdminQueFirmo && doc.data().fcm_token) {
          tokensOtrosAdmins.push(doc.data().fcm_token);
        }
      });

      if (tokensOtrosAdmins.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: tokensOtrosAdmins,
          notification: {
            title: "⏳ Falta tu firma",
            body: `${nombreAdminQueFirmo} ya aprobó la salida de ${after.nombre_trabajador}. ¡Faltas tú!`,
          },
          android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
        });
      }
    }

    // ==========================================================
    // 🚦 CASO D: TRABAJADOR REGRESA A EMAP (Avisar a los Admins)
    // ==========================================================
    else if (after.estado === "completada" && before.estado !== "completada") {
      const adminsSnapshot = await db.collection("usuarios")
        .where("rol", "==", "admin") // 🔥 Cambiado
        .get();

      const tokensAdmins: string[] = [];
      adminsSnapshot.forEach((doc: any) => {
        if (doc.data().fcm_token) tokensAdmins.push(doc.data().fcm_token);
      });

      if (tokensAdmins.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: tokensAdmins,
          notification: {
            title: "🏠 Trabajador de regreso",
            body: `${after.nombre_trabajador} ha finalizado su misión y está de vuelta en la base.`,
          },
          android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
        });
      }
    }

  } catch (error) {
    console.error("Error enviando notificación de actualización:", error);
  }
});

// ============================================================================
// 🔔 TRIGGER 3: MISIÓN ELIMINADA/CANCELADA (Avisar a Admins)
// ============================================================================
// Si el trabajador se arrepiente y borra la solicitud antes de salir
export const notificarMisionCancelada = onDocumentDeleted("misiones/{misionId}", async (event: any) => {
  const misionBorrarda = event.data?.data();
  if (!misionBorrarda) return;

  // Si ya estaba completada o rechazada y la borran por limpieza, no avisamos
  if (misionBorrarda.estado === "completada" || misionBorrarda.estado === "rechazado") return;

  const db = admin.firestore();

  try {
    const adminsSnapshot = await db.collection("usuarios")
      .where("rol", "==", "admin")
      .get();

    const tokensAdmins: string[] = [];
    adminsSnapshot.forEach((doc: any) => {
      if (doc.data().fcm_token) tokensAdmins.push(doc.data().fcm_token);
    });

    if (tokensAdmins.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens: tokensAdmins,
        notification: {
          title: "🚫 Solicitud Cancelada",
          body: `${misionBorrarda.nombre_trabajador} ha cancelado su solicitud hacia ${misionBorrarda.destino}.`,
        },
        android: { notification: { sound: "notificacion", channelId: "canal_emap_misiones" } }
      });
    }
  } catch (error) {
    console.error("Error enviando notificación de cancelación:", error);
  }
});

// ==========================================================
// 🧹 BARRENDERO NOCTURNO: Cierra misiones zombies a medianoche
// ==========================================================
export const cerrarMisionesZombies = onSchedule("59 23 * * *", async (event: any) => {
  const db = admin.firestore();
  
  try {
    const snapshot = await db.collection("misiones")
      .where("estado", "==", "en_mision")
      .get();

    if (snapshot.empty) {
      console.log("Todo limpio. No hay misiones zombies hoy.");
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        estado: "completada",
        nota_sistema: "Cierre forzado a medianoche por el sistema." 
      });
    });

    await batch.commit();
    console.log(`🧹 Misiones zombies cerradas: ${snapshot.size}`);

  } catch (error) {
    console.error("Error limpiando misiones zombies:", error);
  }
});
