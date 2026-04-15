import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";

// 1. Configuración Global de Firebase Functions
setGlobalOptions({
  maxInstances: 10,
  region: "southamerica-east1",
});

// 2. Inicializar Firebase Admin (SOLO UNA VEZ AQUÍ)
admin.initializeApp();

// 3. Exportar Módulos
// Exportamos todas las funciones del módulo de usuarios
export * from "./users/user.functions";
export * from "./misiones/mision.functions";