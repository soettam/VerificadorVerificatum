# Índice
------

- [Chequeos del verificador](#chequeos-del-verificador)
- [Correspondencia con la documnetacion de Verificatum: A, B, C, D, F](#correspondencia-con-la-documnetacion-de-verificatum-a-b-c-d-f)
    - [Chequeo A (compromiso ponderado por el desafío)](#chequeo-a-compromiso-ponderado-por-el-desaf%C3%ADo)
    - [Chequeo B (cadena intermedia)](#chequeo-b-cadena-intermedia)
    - [Chequeo C (producto acumulado)](#chequeo-c-producto-acumulado)
    - [Chequeo D (último eslabón)](#chequeo-d-%C3%BAltimo-eslab%C3%B3n)
    - [Chequeo F (reencriptado en bloque)](#chequeo-f-reencriptado-en-bloque)
- [Archivos usados para la verificación](#archivos-usados-para-la-verificaci%C3%B3n)
- [Extraer rho y bases con vmnv](#extraer-rho-y-bases-con-vmnv)
- [Construcción portable (PackageCompiler)](#construcci%C3%B3n-portable-packagecompiler)
- [Para ejecutar prueba](#para-ejecutar-prueba)
- [Instalación local y dependencias](#instalaci%C3%B3n-local-y-dependencias)
- [Performance y referencias](#performance-y-referencias)
- [Referencias](#referencias)

# Chequeos del verificador

t₁ – Producto total constante: Confirma que, después de barajar, la multiplicación de todos los compromisos sigue dando el mismo resultado de antes. En una elección, significa que no apareció ni desapareció ningún voto durante el shuffle.

t₂ – Punta de la cadena: Verifica que el último compromiso de la cadena coincide con lo que debería salir al aplicar la permutación. Evita que se “manipule” el final de la fila de votos.

t₃ – Peso según el desafío: Comprueba que la permutación responde correctamente al desafío aleatorio generado en la prueba de conocimiento cero. El mix-net demuestra que realmente usó la permutación correcta que prometió usar.

t₄ – Reencriptado honesto: Garantiza que los votos barajados son los mismos que antes, sólo que re–encriptados con nueva aleatoriedad. Así se preserva el anonimato sin cambiar el contenido del voto.

𝐭̂ – Consistencia paso a paso: Revisa cada enlace de la cadena de compromisos para asegurarse de que todo el barajado es coherente. Evita trampas localizadas entre dos votos consecutivos.

Chequeos con las ecuaciones publicadas por Verificatum (A, B, C, D, F)
(vmnv-3.1.0.pdf)

A – Compromiso global: Un gran resumen que prueba que la permutación y las respuestas encajan. Da confianza de que el mix-net no trucó la permutación que comprometió.

B – Cadena intermedia: Similar a 𝐭̂, vigila cada eslabón del shuffle para que ninguna parte de la permutación sea falsa.

C – Producto acumulado: Comprueba otra vez que el producto de los compromisos no cambió, igual que t₁.

D – Último eslabón: Chequea que la salida final concuerda con la base pública del sistema. Evita que se falsifique el resultado final del shuffle.

F – Reencriptado en bloque: Revisa que el conjunto de votos reencriptados corresponde exactamente a los originales con nueva aleatoriedad. Asegura que nadie metió votos nuevos o adulteró los reales.

# Correspondencia con la documnetacion de Verificatum: A, B, C, D, F

Los cinco chequeos que en el código llamamos A, B, C, D y F están descritos explícitamente en la documentación de Verificatum (vmnv-3.1.0.pdf):

## Chequeo A (compromiso ponderado por el desafío)

Se define al final del Paso 3 del Algorithm 19 (Proof of a Shuffle), Sección 8.3, pág.16: allí se calcula:

 $$A = \prod_{i=0}^{N-1} u_i^{e_i}$$

 y en el Paso 5 se comprueba 

 $$A = \prod_{i=0}^{N-1} u_i^{e_i}$$

## Chequeo B (cadena intermedia)

En el mismo Paso 5 (Algoritmo 19, pág. 16) aparecen las igualdades 

$$(B_i)^v \cdot B_i' = g^{k_{B,i}} \cdot \text{pred}^{k_{E,i}},$$

con el caso base usando (h_0) y los demás índices usando (B_{i-1}). Esa es la cadena que revaluamos para este chequeo.

## Chequeo C (producto acumulado)

Se introduce justo antes en el Paso 5 (Algoritmo 19, pág.16) como: 

$$C = \prod_{i=0}^{N-1} u_i$$

y se exige 

$$C^v \cdot C' = g^{k_C}.$$ 

## Chequeo D (último eslabón)

En el mismo bloque del Paso 5 (pág. 16) se forma:

$$(D = B_{N-1} \cdot h_0^{\prod e_i})$$ 

y se verifica 

$$D^v \cdot D' = g^{k_D}$$

## Chequeo F (reencriptado en bloque) 

También en el Paso 5 (pág.16) se establece:

$$F = \prod_{i=0}^{N-1} w_i^{e_i}$$ 

y se comprueba 

$$(F^v \cdot F' = \text{Enc}{pk}(1, -k_F) \cdot \prod_i (w_i')^{k{E,i}}).$$

# Archivos usados para la verificación

- protInfo.xml:es el descriptor del protocolo (parámetros del grupo, auxsid, etc.). Se carga en load_verificatum_simulator para reconstruir el verificador (src/serializer.jl:294).
- dir/nizkp/default/Ciphertexts.bt: lista los ciphertexts originales del mix.
- dir/nizkp/default/ShuffledCiphertexts.bt: contiene los ciphertexts tras el shuffle.
- dir/nizkp/default/proofs/PermutationCommitment01.bt: compromiso de la permutación que Verificatum publica.
- dir/nizkp/default/proofs/PoSCommitment01.bt: compromisos intermedios de la prueba de shuffle.
- dir/nizkp/default/proofs/PoSReply01.bt: respuestas de la prueba (los “s” y “k” que acompañan al desafío).

# Extraer rho y bases con vmnv

Comandos de ejemplo para generar `der.rho` y `bas.h` desde `protInfo.xml` y el directorio nizkp:

Cuando se usa "vmn -mix o -decrypt" el archivo dir/nizkp/<auxsid>/type es "mixing" , usar para extraer rho y bases:

```bash
/usr/local/bin/vmnv -mix -t der.rho,bas.h \ 
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```
Cuando se usa "vmn -shuffle" el archivo dir/nizkp/<auxsid>/type es "shuffling" usar para extraer rho y bases:

```bash
/usr/local/bin/vmnv -shuffle -t der.rho,bas.h \ 
    /ruta/a/protInfo.xml /ruta/a/dir/nizkp/default
```

# Construcción portable (PackageCompiler)

El proyecto incluye un script que empaqueta la aplicación con PackageCompiler. Ejecutalo desde la raíz del repositorio con Julia instalado:

```bash
julia JuliaBuild/build_portable_app.jl
```

Para distribuir en varias plataformas ejecutar el script en cada sistema operativo; PackageCompiler no realiza cross-compilation.

## Para ejecutar prueba
Ejemplo de uso del binario empaquetado:

```bash
./dist/VerificadorShuffleProofs/bin/verificador ./datasets/onpesinprecomp -mix
```

## Versión de Julia para empaquetado

El empaquetado portable fue probado y el Manifest fue resuelto con Julia 1.11.7.
Para evitar problemas de incompatibilidad con `PackageCompiler` y los artefactos `jll`,
recomendamos usar esa versión al construir el ejecutable. Si usas `juliaup` puedes
instalar y seleccionar esa versión con:

```bash
juliaup add 1.11.7
juliaup default 1.11.7
```

Después de fijar la versión, ejecuta el script de empaquetado:

```bash
julia --project=. JuliaBuild/build_portable_app.jl
```

## Instalación local y dependencias

Para trabajar sobre el repositorio y garantizar que PackageCompiler incluya todo:

```bash
julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'
```

Si durante el empaquetado aparece el error "Package JSON not found", instale la dependencia en el proyecto:

```bash
julia -e 'using Pkg; Pkg.activate("."); Pkg.add("JSON");'
```

Se recomiendo añadir permanentemente las dependencias necesarias a `Project.toml` para reproducibilidad.

## Performance y referencias

Perfiles y benchmarks están en `test/benchmarks/`. Recomendaciones:

- Use OpenSSLGroups para aceleración en curvas elípticas.
- Asegure suficiente RAM para grandes cantidades de ciphertexts (p. ej. 16 GB para 1M de entradas en algunos tests).

Notas importantes:

- Salida por plataforma: en Linux los artefactos quedan en `dist/VerificadorShuffleProofs`; en Windows en `distwindows/VerificadorShuffleProofs`. El ejecutable está en `bin/verificador` (`verificador.exe` en Windows).
- Recompilaciones rápidas: el script puede reutilizar builds previos de forma incremental. Para un rebuild limpio pase `--clean` o exporte `SHUFFLEPROOFS_CLEAN=1` antes de ejecutar.
- Recursos opcionales: si existen `mixnet/verificatum-vmn-3.1.0` o `test/validation_sample` en el repo, se copian a `resources/` y el ejecutable los puede usar.
- Aviso "No se encontró mixnet/...": indica que no se empaquetó Verificatum; el ejecutable intentará usar `vmnv` instalado en el sistema si no hay recursos incluidos.

# Sobre el verificador

El verificador está implementado en Julia, un lenguaje de programación de alto rendimiento que utiliza el compilador LLVM para generar código nativo.
Esto le permite alcanzar una velocidad comparable a la de C/C++, manteniendo al mismo tiempo una sintaxis moderna, expresiva y más cercana a lenguajes como Python o MATLAB.

Julia combina lo mejor de dos mundos: la interactividad del REPL (útil para depuración o auditorías manuales) y la eficiencia de compilación estática.
Además, su ecosistema científico facilita el manejo de estructuras algebraicas, curvas elípticas y pruebas criptográficas.

Referencia del proyecto original
El código fuente del verificador se basa en el proyecto ShuffleProofs.jl, desarrollado en el marco de PeaceFounder, disponible en el siguiente enlace:

https://github.com/PeaceFounder/ShuffleProofs.jl

Este proyecto implementa protocolos de verificación para mixnets verificados públicamente, permitiendo auditar matemáticamente las permutaciones y reencriptaciones sin revelar el vínculo entre votantes y votos, garantizando así anonimato verificable.

# Referencias:

- Wikström — Verificatum Mix-Net papers
- Haenni et al. — Pseudocode for Verifiable Re-Encryption Mix-Nets
- https://verificatum.org
- El proyecto original se encuentra en https://github.com/PeaceFounder/ShuffleProofs.jl 



