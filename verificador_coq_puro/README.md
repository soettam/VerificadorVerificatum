# Verificador Formal Coq - Sistema de Verificación Criptográfica

Sistema de verificación formal que utiliza módulos matemáticos extraídos de pruebas Coq/Rocq para validar protocolos criptográficos de shuffling.

## Características

- **Verificación Formal**: Utiliza código matemático extraído directamente de pruebas formales Coq
- **Interfaz de Línea de Comandos**: Acepta parámetros para dataset y archivo de salida
- **Informe Matemático**: Genera documentos Markdown con ecuaciones LaTeX
- **Sin Iconos**: Salida limpia enfocada en contenido matemático formal
- **Análisis Completo**: Procesa archivos Verificatum (.bt) y ejecuta 5 verificaciones criptográficas

## Instalación

```bash
# Clonar repositorio (si aplica)
cd verificador_coq_puro

# Hacer ejecutable
chmod +x verificador_formal.py
```

## Uso

### Sintaxis Básica

```bash
python3 verificador_formal.py --dataset <ruta_dataset> --output <archivo.md>
```

### Ejemplos

```bash
# Verificación básica
python3 verificador_formal.py --dataset ../datasets/onpedecrypt --output informe.md

# Usando formas cortas de parámetros
./verificador_formal.py -d ../datasets/onpesinprecomp -o verificacion.md

# Con información detallada
./verificador_formal.py -d ../datasets/onpedecrypt -o informe.md --verbose
```

### Parámetros

| Parámetro | Forma Corta | Descripción | Requerido |
|-----------|-------------|-------------|-----------|
| `--dataset` | `-d` | Ruta al dataset Verificatum (directorio con archivos .bt) | Sí |
| `--output` | `-o` | Archivo de salida para el informe (.md) | Sí |
| `--verbose` | `-v` | Mostrar información detallada durante ejecución | No |

## Estructura del Dataset

El sistema espera un dataset de Verificatum con la siguiente estructura:

```
dataset/
├── dir/
│   └── nizkp/
│       └── default/
│           ├── Ciphertexts.bt
│           ├── ShuffledCiphertexts.bt
│           ├── PermutationCommitment01.bt
│           ├── PoSCommitment01.bt
│           ├── PoSReply01.bt
│           └── ... (otros archivos .bt)
```

## Informe Generado

El informe matemático incluye:

### 1. Marco Matemático
- Notación formal con LaTeX
- Definiciones de grupos cíclicos
- Propiedades de seguridad

### 2. Análisis de Módulos Coq
- Lista de módulos extraídos
- Tamaño y complejidad de cada módulo
- Estado de verificación formal

### 3. Verificaciones Ejecutadas
Para cada una de las 5 verificaciones:
- **Ecuación matemática** en formato LaTeX
- **Proposición formal** verificada
- **Módulo Coq** utilizado
- **Complejidad computacional**
- **Garantías de seguridad**
- **Resultado** de la verificación

### 4. Resultados Finales
- Tabla cuantitativa de resultados
- Análisis de archivos procesados
- Conclusión formal
- Garantías del sistema

## Verificaciones Implementadas

| ID | Descripción | Ecuación LaTeX | Módulo Coq |
|----|-------------|----------------|-------------|
| A | Compromiso batch de permutación | $A^{\\nu} \\cdot A' = g^{k_A} \\cdot \\prod_{i=1}^{n} h_i^{k_{E,i}}$ | `ShuffleArg` |
| B | Cadena de compromisos coherente | $B_i^{\\nu} \\cdot B'_i = g^{k_{B,i}} \\cdot \\text{pred}^{k_{E,i}}$ | `Support` |
| C | Producto total permutación | $C^{\\nu} \\cdot C' = g^{k_C}$ | `Coq_prodarg` |
| D | Enlace último compromiso | $D^{\\nu} \\cdot D' = g^{k_D}$ | `ShuffleArg` |
| F | Batch ciphertexts reencriptados | $F^{\\nu} \\cdot F' = \\text{Enc}(pk,g)(-k_F) \\cdot \\prod_{i=1}^{n} w'_i^{k_{E,i}}$ | `Enc` |

## Dependencias

- Python 3.7+
- Acceso a módulos Coq extraídos en: `/home/soettamusb/ShuffleProofs.jl-main/verification_workspace/BayerGroth/lib.ml`

## Arquitectura

```
verificador_formal.py
├── VerificadorCoqFormal (clase principal)
│   ├── cargar_datos_verificatum()      # Procesa archivos .bt
│   ├── analizar_modulos_coq()          # Analiza código extraído
│   ├── ejecutar_verificacion_coq()     # Ejecuta 5 verificaciones
│   └── generar_informe_matematico()    # Genera Markdown con LaTeX
```

## Salida de Ejemplo

```
Iniciando verificación formal...
Dataset: ../datasets/onpedecrypt
Informe: informe_matematico.md
Cargando datos de Verificatum...
Archivos BT encontrados: 13
Analizando módulos Coq extraídos...
Ejecutando verificación Coq formal...
Ejecutando chequeo A...
Ejecutando chequeo B...
Ejecutando chequeo C...
Ejecutando chequeo D...
Ejecutando chequeo F...
Verificación completada.
Informe generado: informe_matematico.md
Resultado: 5/5 verificaciones exitosas
```

## Garantías Formales

El sistema proporciona:

1. **Corrección Matemática**: Cada verificación está respaldada por pruebas formales Coq
2. **Verificación Estructural**: Validación automática de módulos extraídos
3. **Trazabilidad**: Enlace directo entre código fuente formal y ejecución
4. **Reproducibilidad**: Resultados determinísticos basados en matemáticas formales

## Casos de Uso

- **Auditoría Criptográfica**: Verificación formal de implementaciones de shuffling
- **Investigación Académica**: Análisis de protocolos con garantías matemáticas
- **Sistemas Críticos**: Validación de componentes criptográficos para elecciones
- **Desarrollo Formal**: Integración de verificación formal en pipelines de desarrollo

---

*Desarrollado con el Sistema de Verificación Formal Coq/Rocq*