# Registro de pruebas del compilado portable

**Compilado probado:** `distwindows/VerificadorShuffleProofs`
**Fecha:** 2026-01-09
**Comando base:** `distwindows/VerificadorShuffleProofs/bin/verificador <ruta_dataset>`

## Ejecuciones secuenciales

1. [x] **datasets/default_session**  
   - Resultado: ❌ Todas las verificaciones (t₁…t₄, A–F) retornaron `false`, por lo que el dataset se considera inválido.  
   - Observaciones: Ejecutó en modo single-party; el reporte detalló múltiples discrepancias entre lhs/rhs.  
   - Artefacto generado: `chequeo_detallado_result_default_session_default_20260109_151234.json`.

2. [x] **datasets/onpe100**  
   - Resultado: ✅ Multi-party (2 parties) con ambas parties válidas.  
   - Observaciones: Todos los chequeos pasaron; se emitió resumen "TODAS VÁLIDAS".  
   - Artefacto generado: `chequeo_detallado_result_onpe100_default_20260109_151333.json`.

3. [x] **datasets/onpe50**  
   - Resultado: ❌ Error.  
   - Observaciones: `SystemError: .../dir/nizkp/default/Ciphertexts.bt` no existe; dataset incompleto para la prueba.  
   - Artefacto generado: ninguno.

4. [x] **datasets/onpeconprecomp**  
   - Resultado: ❌ Error.  
   - Observaciones: Falta `dir/nizkp/default/proofs/PoSCommitment01.bt`; no se pudo cargar la prueba de la party 01.  
   - Artefacto generado: ninguno.

5. [x] **datasets/onpedecrypt**  
   - Resultado: ✅ Todos los chequeos de nivel shuffle y Verificatum pasaron.  
   - Observaciones: Ejecutado con modo `-mix`; se generó reporte completo con parámetros para 30 desafíos.  
   - Artefacto generado: `chequeo_detallado_result_onpedecrypt_default_20260109_151424.json`.

6. [x] **datasets/onpeprueba**  
   - Resultado: ❌ Error.  
   - Observaciones: Falta `dir/nizkp/default/Ciphertexts.bt`; la simulación se detuvo al intentar abrirlo.  
   - Artefacto generado: ninguno.

7. [x] **datasets/onpesinprecomp**  
   - Resultado: ✅ Single-party válido; todas las comprobaciones se reportaron como `true`.  
   - Observaciones: Se verificaron 10 desafíos y se registró el vector `u`.  
   - Artefacto generado: `chequeo_detallado_result_onpesinprecomp_default_20260109_151455.json`.

8. [x] **datasets/test_party1**  
   - Resultado: ✅ Single-party válido; coincide con onpesinprecomp y reutiliza los mismos parámetros de generadores.  
   - Observaciones: Todos los chequeos (t₁…t₄, t̂, A–F) salieron `true`.  
   - Artefacto generado: `chequeo_detallado_result_test_party1_default_20260109_151514.json`.

## Reruns con auxsid específico y firmas

1. [x] **datasets/onpe50 -mix onpe501**  
   - Verificador: ✅ Ambas parties válidas con VMNV `-mix onpe501`. Artefacto: `chequeo_detallado_result_onpe50_onpe501_20260109_154808.json`.  
   - Firmas: 79 archivos procesados → 19 válidos, 0 inválidos, 60 con **WARN** por archivos de datos faltantes (Pedersen/ElGamal para parties 02 y 03).  
   - Observaciones: Se documentaron los warnings; no se detectaron firmas inválidas.

2. [x] **datasets/onpeprueba -mix onpeprueba**  
   - Verificador: ✅ Single-party válido, artefacto `chequeo_detallado_result_onpeprueba_20260109_154849.json`.  
   - Firmas: 15/15 válidas sin warnings.  
   - Observaciones: Primera rerun exitosa tras indicar el auxsid correcto.

3. [x] **datasets/onpedecrypt -mix onpeprueba**  
   - Verificador: ✅ Resultado positivo para la sesión `onpeprueba`; archivo `chequeo_detallado_result_onpedecrypt_onpeprueba_20260109_155336.json`.  
   - Firmas: 15/15 válidas.  
   - Observaciones: Coincide con las parties del dataset onpeprueba.

4. [ ] **datasets/onpeconprecomp -shuffle**  
   - Verificador: ❌ Sigue faltando `dir/nizkp/default/proofs/PoSCommitment01.bt`; ejecución aborta antes de la verificación.  
   - Firmas: 15/15 válidas.  
   - Observaciones: Requiere recuperar el archivo PoSCommitment para completar la prueba.

5. [x] **datasets/default_session -shuffle**  
   - Verificador: ❌ Continúa inválido (todos los chequeos `false`). Reporte: `chequeo_detallado_result_default_session_default_20260109_155436.json`.  
   - Firmas: 37/37 válidas.  
   - Observaciones: Dataset sirve como ejemplo negativo; mantener para contrastar logs.

6. [x] **datasets/onpe100 -mix**  
   - Verificador: ✅ Multi-party (2/2) válido con artefacto `chequeo_detallado_result_onpe100_default_20260109_155543.json`.  
   - Firmas: 43 archivos detectados → 17 válidos, 0 inválidos, 26 **WARN** por archivos de datos faltantes para parties 2 y 3 (Pedersen/DistrElGamal/Shuffler/Shutdown).  
   - Observaciones: Confirmar si los bullboards faltantes deben copiarse para limpiar los warnings.

7. [x] **datasets/onpesinprecomp -shuffle**  
   - Verificador: ✅ Single-party válido; nuevo artefacto `chequeo_detallado_result_onpesinprecomp_default_20260109_155620.json`.  
   - Firmas: 33/33 válidas.  
   - Observaciones: Vuelve a confirmar consistencia del dataset base tras rerun completo.
