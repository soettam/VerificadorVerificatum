# Guía Detallada de Verificación Formal

Este documento describe paso a paso cómo reproducir la verificación formal descrita por *Verified Verifiers for Verifying Elections* y contrastarla con el verificador escrito en Julia.

---

## 0. Prerrequisitos

- **Sistema**: Linux o macOS con permisos para instalar paquetes.
- **Herramientas**: `git`, `opam`, `make`, `dune` (o `ocamlbuild`), `coq` (≥ 8.13), `coqprime`, `ocaml`, `yojson`, `cmdliner`, `julia` (para ShuffleProofs).
- **Repositorio**: ya se descargó el código fuente formal en `verification_workspace/`.

Se recomienda trabajar dentro de un `opam switch` dedicado:

```bash
opam switch create coq-8.16.1 ocaml-base-compiler.4.14.1
eval $(opam env)
opam install coq coqprime dune yojson cmdliner
```

---

## 1. Compilar los desarrollos de Coq

1. Ubicarse en el directorio de trabajo formal:
   ```bash
   cd verification_workspace
   ```
2. Ejecutar la compilación con el `Makefile` incluido:
   ```bash
   make 2>&1 | tee logs/$(date +"%Y%m%d-%H%M")-make.log
   ```
   Este comando compila todos los archivos `.v` (grupos, sigma-protocols, Helios, mixnet, etc.) y deja el registro en `logs/`.
3. Verificar que se generaron los artefactos (`.vo`, `.glob`). Ejemplo:
   ```bash
   ls *.vo
   ```

---

## 2. (Opcional) Regenerar el código extraído

Si se desea extraer nuevamente los módulos OCaml:

```bash
make extract_helios     # para ExtractionHelios.v
dependiendo del Makefile
make extract_mixnet     # para ExtractionMixnet.v
```

Los archivos extraídos se almacenan en `OCaml/`, `OCamlVerificatum/`, etc.

---

## 3. Construir los verificadores OCaml

1. Cambiar al proyecto OCaml correspondiente (por ejemplo, Helios):
   ```bash
   cd verification_workspace/OCaml
   ```
2. Compilar el ejecutable:
   ```bash
   dune build 2>&1 | tee ../logs/$(date +"%Y%m%d-%H%M")-dune.log
   ```
   - Si se usa `ocamlbuild`, reemplazar por `ocamlbuild main.native`.
3. Confirmar la ubicación del binario (normalmente `./_build/default/main.exe`).

Repetir estos pasos en `OCamlVerificatum/` u otros subproyectos si se requiere validar mixnets.

---

## 4. Preparar datasets

1. Colocar los archivos originales en `verification_workspace/datasets/raw/` (por ejemplo, JSON de Helios, BT de Verificatum).
2. Si es necesario un preprocesamiento (unificación de JSON, conversión a BT), crear los archivos derivados en `verification_workspace/datasets/prepared/`.
3. Registrar origen, fecha y hashes en `verification_workspace/datasets/README.md` y documentar los pasos en `verification_plan/NOTES.md`.

---

## 5. Ejecutar los verificadores formales

1. Desde el directorio del ejecutable, lanzar la verificación sobre los datasets preparados. Ejemplo para Helios:
   ```bash
   ./_build/default/main.exe \
     --input ../datasets/prepared/helios_iacr2018.json \
     2>&1 | tee ../logs/$(date +"%Y%m%d-%H%M")-helios-run.log
   ```
2. Para el mixnet Verificatum, reemplazar el comando según la CLI proporcionada (consultar el README del subproyecto) y usar los archivos `.bt` adecuados.
3. Revisar en los logs que todos los chequeos (A/B/C/D/F, etc.) sean aceptados.

---

## 6. Ejecutar el verificador Julia (ShuffleProofs)

1. En el repositorio principal (`ShuffleProofs.jl-main`), correr:
   ```bash
   julia --project=. JuliaBuild/chequeo_detallado.jl datasets/<dataset>
   ```
   - Ajustar la ruta del dataset a la carpeta correspondiente.
   - Registrar la salida en `verification_plan/NOTES.md` y, si se desea, guardar el log en `logs/`.
2. Confirmar que los chequeos reportados por Julia coinciden con los del verificador formal.

---

## 7. Comparar resultados y documentar

1. Comparar las salidas (chequeos A/B/C/D/F, `t₁…t₄`, etc.) del verificador formal con las de ShuffleProofs.
2. Si hay discrepancias, verificar:
   - Parseo de datos (JSON/BT).
   - Aplicación de Fiat–Shamir.
   - Implementación de las ecuaciones en Julia.
   - Sesgos de formato (p. ej., orden de commits).
3. Documentar conclusiones, versiones de software y cualquier ajuste en `verification_plan/NOTES.md`.

---

## 8. (Opcional) Validar mixnets adicionales

- Repetir los pasos 3–7 usando el proyecto `OCamlVerificatum/` o `OCamlCHVote/` con los datasets correspondientes.
- Comparar de nuevo con la implementación Julia (u otro lenguaje) para el mixnet específico.

---

## 9. Buenas prácticas y trazabilidad

- Registrar todos los comandos importantes en `verification_plan/NOTES.md` (versión de Coq, OCaml, fecha de ejecución, dataset).
- Guardar los logs de compilación/ejecución en `verification_workspace/logs/` con un nombre timestamp.
- Mantener el `Makefile`, scripts y readmes sincronizados con cualquier cambio que se realice.

---

> **Resultado esperado**: la ejecución del verificador extraído de Coq sobre los datasets públicos produce los mismos chequeos que la implementación Julia (ShuffleProofs). Con esto se refuerza la confianza en el verificador Julia usando un oráculo formalmente probado.

