# Verificador ShuffleProofs Portable

## Descripción
Este verificador valida pruebas de shuffle (barajado verificable) generadas por Verificatum.
Soporta tanto datasets single-party como multi-party en modos `-shuffle` y `-mix`.

## Requisitos
- **Verificatum (`vmnv`)**: Necesario para extraer `der.rho` y bases independientes.
  - En Linux/macOS: instalar desde https://www.verificatum.org
  - En Windows: usar WSL con Verificatum instalado (ver instrucciones abajo)

## Uso en Ubuntu/Linux

### Verificar dataset single-party (modo shuffle)
```bash
./bin/verificador ./datasets/onpesinprecomp -shuffle
```

### Verificar dataset multi-party (modo mix)
```bash
./bin/verificador ./datasets/onpe100 -mix
```

### Verificar con dataset de muestra incluido
Si se empaquetaron datasets de ejemplo en `resources/validation_sample/`:
```bash
./bin/verificador ./resources/validation_sample/onpe3 -shuffle
```

### Salida
Los resultados se guardan en `chequeo_detallado_result.json` en el directorio actual.

## Uso en Windows

### Requisito previo: WSL con Verificatum
1. Instalar WSL 2 desde PowerShell como Administrador:
   ```powershell
   wsl --install
   ```
2. Reiniciar el equipo si es necesario.
3. Instalar Verificatum dentro de WSL siguiendo las instrucciones en https://www.verificatum.org

### Verificar dataset desde Windows
El verificador detecta automáticamente WSL y ejecuta `vmnv` a través de él:

```powershell
.\bin\verificador.exe .\datasets\onpe100 -mix
```

Otro ejemplo con rutas absolutas:
```powershell
.\bin\verificador.exe C:\Users\usuario\datasets\onpesinprecomp -shuffle
```

El verificador convierte automáticamente las rutas de Windows a formato WSL.

### Ver log detallado de extracción
Si la extracción de `der.rho` falla, el verificador guarda el volcado crudo de `vmnv` en:
```
<dataset>/dir/nizkp/tmp_logs/vmnv_raw_output_global.log
```

## Contenido del paquete
- `bin/verificador` (o `verificador.exe` en Windows): ejecutable principal
- `resources/verificatum-vmn-3.1.0/`: binarios de Verificatum (si se empaquetaron)
- `resources/validation_sample/`: datasets de muestra (si existen)

## Solución de problemas

### Error: "No se encontró vmnv"
- Asegúrate de tener Verificatum instalado y `vmnv` en el PATH.
- En Windows, verifica que WSL esté instalado y Verificatum configurado dentro de WSL.
- Como alternativa, copia el directorio `verificatum-vmn-3.1.0` a `resources/`.

### Error: "No se pudo extraer der.rho"
- Verifica que el dataset tenga la estructura correcta (`protInfo.xml` y `dir/nizkp/default`).
- Revisa el log crudo en `<dataset>/dir/nizkp/tmp_logs/vmnv_raw_output_global.log`.
- Asegúrate de usar el modo correcto (`-shuffle` para shuffling, `-mix` para mixing).

## Más información
- Documentación completa: https://github.com/soettam/VerificadorVerificatum
- Verificatum: https://www.verificatum.org
