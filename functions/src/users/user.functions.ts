/* eslint-disable max-len */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

/**
 * Función segura para crear usuarios
 * Solo puede ser ejecutada por usuarios con rol "admin"
 */
export const crearUsuario = onCall(async (request) => {
  // 1️⃣ Verificar autenticación
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes estar autenticado.");
  }

  // 2️⃣ Verificar que el solicitante sea admin
  const rolSolicitante = request.auth.token.rol;
  if (rolSolicitante !== "admin") {
    throw new HttpsError("permission-denied", "Solo un administrador puede realizar esta acción.");
  }

  const { email, password, nombre,ci , cargo, rolNuevo } = request.data;

  // 3️⃣ Validar campos obligatorios
  if (!email || !password || !nombre || !ci || !cargo || !rolNuevo) {
    throw new HttpsError("invalid-argument", "Faltan datos obligatorios.");
  }

  // 4️⃣ Validar que el rol sea uno permitido
  const rolesValidos = ["admin", "jefe", "trabajador"];
  if (!rolesValidos.includes(rolNuevo)) {
    throw new HttpsError("invalid-argument", "El rol especificado no es válido.");
  }

  try {
    // 5️⃣ Crear usuario en Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: nombre,
    });

    // 6️⃣ Asignar Custom Claim (rol seguro)
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      rol: rolNuevo,
    });

    // 7️⃣ Crear documento en Firestore
    await admin.firestore()
      .collection("usuarios")
      .doc(userRecord.uid)
      .set({
        nombre,
        ci,
        cargo,
        rol: rolNuevo,
        email, // útil para búsquedas y administración
        activo: true,
        creadoEn: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      uid: userRecord.uid,
      mensaje: "Usuario creado correctamente.",
    };
  } catch (error: any) {
    logger.error("Error en crearUsuario:", error);

    // Manejo específico de errores de Auth
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "El correo electrónico ya está registrado.");
    }
    if (error.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "La contraseña debe tener al menos 6 caracteres.");
    }

    throw new HttpsError("internal", "Error interno al procesar la solicitud.");
  }
});

/**
 * Función segura para editar un usuario existente
 * Solo puede ser ejecutada por usuarios con rol "admin"
 */
export const editarUsuario = onCall(async (request) => {
  // 1️⃣ Verificar autenticación y rol
  if (!request.auth || request.auth.token.rol !== "admin") {
    throw new HttpsError("permission-denied", "Solo un administrador puede realizar esta acción.");
  }

  const { uid, nombre, ci, cargo, rolNuevo } = request.data;

  // 2️⃣ Validar datos obligatorios
  if (!uid || !nombre || !ci || !cargo || !rolNuevo) {
    throw new HttpsError("invalid-argument", "Faltan datos obligatorios.");
  }

  const rolesValidos = ["admin", "jefe", "trabajador"];
  if (!rolesValidos.includes(rolNuevo)) {
    throw new HttpsError("invalid-argument", "El rol especificado no es válido.");
  }

  try {
    // 3️⃣ Actualizar datos en Firebase Auth (DisplayName)
    await admin.auth().updateUser(uid, {
      displayName: nombre,
    });

    // 4️⃣ Actualizar el Custom Claim
    await admin.auth().setCustomUserClaims(uid, {
      rol: rolNuevo,
    });

    // 5️⃣ Actualizar documento en Firestore
    await admin.firestore()
      .collection("usuarios")
      .doc(uid)
      .update({
        nombre,
        ci,
        cargo,
        rol: rolNuevo,
        actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { 
      success: true, 
      mensaje: "Usuario actualizado correctamente." 
    };
  } catch (error: any) {
    logger.error("Error en editarUsuario:", error);
    throw new HttpsError("internal", "Error interno al actualizar el usuario.");
  }
});

/**
 * Función para Dar de Baja o Activar a un usuario
 * Modifica tanto Firestore como el acceso real en Firebase Auth
 */
export const cambiarEstadoUsuario = onCall(async (request) => {
  // 1️⃣ Verificar autenticación y rol
  if (!request.auth || request.auth.token.rol !== "admin") {
    throw new HttpsError("permission-denied", "Solo un administrador puede realizar esta acción.");
  }

  const { uid, activo } = request.data;

  if (!uid || typeof activo !== "boolean") {
    throw new HttpsError("invalid-argument", "Datos inválidos para cambiar estado.");
  }

  // 2️⃣ Prevenir que un admin se desactive a sí mismo (Safety Check)
  if (uid === request.auth.uid) {
    throw new HttpsError("failed-precondition", "No puedes desactivar tu propia cuenta de administrador.");
  }

  try {
    // 3️⃣ Habilitar/Deshabilitar en Firebase Auth
    // Auth usa la propiedad "disabled", por lo que mandamos lo contrario de "activo"
    await admin.auth().updateUser(uid, {
      disabled: !activo, 
    });

    // 4️⃣ Actualizar el estado visual en Firestore
    await admin.firestore()
      .collection("usuarios")
      .doc(uid)
      .update({
        activo: activo,
        actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { 
      success: true, 
      mensaje: activo ? "Usuario activado." : "Usuario dado de baja." 
    };
  } catch (error: any) {
    logger.error("Error en cambiarEstadoUsuario:", error);
    throw new HttpsError("internal", "Error interno al cambiar el estado del usuario.");
  }
});
