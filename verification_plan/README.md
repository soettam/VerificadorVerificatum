# Plan de Verificación Formal

Este directorio recopila los materiales necesarios para reproducir el flujo de trabajo descrito en el artículo *Verified Verifiers for Verifying Elections* y aplicarlo al verificador de ShuffleProofs.

## Flujo General

1. **Preparar el entorno Coq**
   - Instalar Coq (>= 8.13) y las bibliotecas necesarias (`CoqPrime`, `mathcomp` si se requiere, etc.).
   - Clonar o vincular el código formal de los autores (ver Apéndice A del paper) y adaptar el `Makefile` a tu entorno.

2. **Definir las estructuras algebraicas básicas**
   - Replicar/ajustar las definiciones de grupos abelianos, campos y espacios vectoriales (`Definition 5.1` / `5.2`).
   - Asegurarse de que ElGamal y los compromisos de permutación usan esas estructuras dentro de Coq.

3. **Formalizar y probar los sigma-protocols**
   - Implementar la `Record form` y `Definition 5.4` para las propiedades (completitud, special soundness, HVZK).
   - Construir los combinadores (`andSigmaProtocol`, `parSigmaProtocol`, `disSigmaProtocol`) y probar los teoremas 5.6–5.10.

4. **Instanciar el esquema de Helios / ShuffleProofs**
   - Definir los parámetros concretos de ElGamal (usando `CoqPrime` para los primos).
   - Formalizar las propiedades `HeliosCorrectEncrApproval`, `HeliosCorrectDecrList` y demostrar el teorema análogo a `HeliosCorrectResultApproval`.

5. **Extraer el verificador**
   - Usar `coq_extract` para obtener los módulos OCaml (`ApprovalSigma`, `DecryptionSigma`, etc.).
   - Compilar el binario (por ejemplo, con `dune` u `ocamlbuild`) y preparar un pequeño CLI que consuma las pruebas públicas.

6. **Validar datasets reales**
   - Descargar los datos de la elección (o el mixnet de Verificatum) y convertirlos a JSON/BT según el front-end.
   - Ejecutar el verificador extraído y documentar resultados, tiempos y requisitos.

7. **Extensión a mixnets (opcional)**
   - Aplicar la Sección 7 del paper: importar la formalización del mixnet de Wikström/Terelius, probar `Theorem 7.8` y extraer el verificador asociado.

8. **Documentar supuestos externos**
   - Lista de precondiciones no cubiertas por Coq (generación de parámetros, implementación de Fiat–Shamir, ausencia de duplicados, etc.).
   - Definir cómo se comprobarán (auditorías externas, scripts auxiliares, validaciones manuales).

## Próximos Pasos

- Crear subdirectorios (`coq/`, `ocaml/`, `datasets/`) conforme se vayan incorporando artefactos.
- Registrar comandos y scripts utilizados en `NOTES.md` para trazabilidad.
- Coordinar con el equipo de verificación para revisar el `README` y los supuestos antes de iniciar las pruebas formales.

