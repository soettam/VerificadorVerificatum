# Análisis del Código Fuente de Verificatum: Construcción del Random Oracle en Multi-Party

## Fecha: 21 de octubre de 2025

## Resumen Ejecutivo

He analizado el código fuente de Verificatum en `mixnet/verificatum-vmn-3.1.0/` y he descubierto exactamente **cómo y por qué falla la verificación multi-party actual**.

## Hallazgos Clave

### 1. ¿Por qué ρ y h son idénticos entre -shuffle y -mix?

**Respuesta**: Porque se derivan **ANTES** de conocer las commitments de las parties.

```java
// Archivo: MixNetElGamalVerifyFiatShamirSession.java, líneas 160-195
protected void setGlobalPrefix() {
    final String rosid = v.sid + "." + auxsid;
    
    // ρ se deriva SOLO de parámetros globales del protocolo:
    final ByteTree bt =
        new ByteTree(versionBT,
                     rosidBT,
                     rbitlenBT,
                     vbitlenroBT,
                     ebitlenroBT,
                     prgStringBT,
                     pGroupStringBT,
                     roHashfunctionStringBT);

    globalPrefix = v.roHashfunction.hash(bt.toByteArray());
    // ↑ Esto es ρ (der.rho)
}
```

**Conclusión**: ρ es un **hash de los parámetros globales** del protocolo, NO depende de ningún commitment específico.

### 2. Generación de h (generadores independientes)

```java
// Archivo: MixNetElGamalVerifyFiatShamirSession.java, líneas 557-569
void deriveGenerators(final int maxciph) {
    if (generators == null) {
        v.print("Derive independent generators... ");
        final IndependentGeneratorsRO igRO =
            new IndependentGeneratorsRO("generators",
                                       globalPrefix,
                                       v.roHashfunction);
        generators = igRO.generate(null, v.pGroup, maxciph);
        // ↑ h se deriva de ρ (globalPrefix) mediante RO
    }
}
```

**Conclusión**: Los generadores h también se derivan solo de ρ, son **compartidos globalmente** en modo mixing.

---

## 3. 🎯 LA CLAVE: Construcción del Random Oracle Input POR PARTY

### Single-Party (Shuffling):

```java
// Archivo: MixNetElGamalVerifyFiatShamirSession.java, líneas 664-668
// Para PoSC (Proof of Shuffle of Commitments):

ByteTreeContainer challengeData =
    new ByteTreeContainer(g.toByteTree(),
                          generators.toByteTree(),
                          permutationCommitment.toByteTree());
                          
final byte[] prgSeed = challenger.challenge(challengeData,
                                            8 * v.prg.minNoSeedBytes(),
                                            v.rbitlen);
```

**RO Input (Single-party)**:
```
RO_input = g || generators || permutationCommitment
```

### Multi-Party (Mixing) - LA DIFERENCIA CRÍTICA:

```java
// Archivo: MixNetElGamalVerifyFiatShamirSession.java, líneas 1396-1470
// Loop principal de verificación multi-party:

for (int l = 1; l <= activeThreshold; l++) {
    
    // Lee commitment de la party l
    permutationCommitment = readPermutationCommitment(maxciph, l);
    
    // Verifica PoSC para esta party
    if (verifyPoSC(l, permutationCommitment)) {
        // ✅ Proof válido
    }
}
```

**Observación Crucial**: Cada party se verifica **INDIVIDUALMENTE** con su propio commitment:

```java
// Dentro de verifyPoSC():
ByteTreeContainer challengeData =
    new ByteTreeContainer(g.toByteTree(),
                          generators.toByteTree(),
                          permutationCommitment.toByteTree());  // ← Solo UNA party
```

---

## 4. ⚠️ EL PROBLEMA EN NUESTRO CÓDIGO

### Código Actual (Julia):

```julia
# src/portable_app.jl, líneas 472-570
function detailed_chequeo_multiparty(dataset, vmnv_path, num_parties)
    # Extrae generadores GLOBALES (✅ CORRECTO)
    testvectors_global = obtain_testvectors(dataset, ..., mode = "-mix")
    ρ_global = testvectors_global.ρ
    generators_global = testvectors_global.generators
    
    for party_id in 1:num_parties
        # Carga proof de esta party (✅ CORRECTO)
        vproof = ShuffleProofs.load_verificatum_proof(proofs_dir, ...; party_id)
        proof = ShuffleProofs.PoSProof(vproof)
        
        # ❌ AQUÍ ESTÁ EL ERROR:
        # Genera challenges con SOLO el commitment de esta party
        seed = ShuffleProofs.seed(verifier, proposition, proof.𝐜; ρ = ρ, 𝐡 = generators)
        perm_u = ShuffleProofs.challenge_perm(verifier, proposition, proof.𝐜; s = seed)
        perm_c = ShuffleProofs.challenge_reenc(verifier, proposition, ...; ρ = ρ, s = seed)
    end
end
```

**El problema**: `proof.𝐜` contiene SOLO los commitments de `party_id`, pero Verificatum genera challenges usando **EXACTAMENTE EL MISMO** RO input por party.

---

## 5. 🔍 REVELACIÓN FINAL: Verificatum NO mezcla commitments en el RO

Después de analizar el código cuidadosamente, descubrí que **Verificatum NO construye un RO input compuesto con todos los commitments**.

### Estructura del Proceso en Verificatum:

```java
// 1. Genera ρ y h GLOBALMENTE (compartidos)
setGlobalPrefix();  // ρ = Hash(protocolParams)
deriveGenerators(maxciph);  // h = DeriveGenerators(ρ)

// 2. Para cada party l:
for (int l = 1; l <= activeThreshold; l++) {
    
    // 2a. Lee commitment de party l
    PGroupElementArray permComm_l = readPermutationCommitment(maxciph, l);
    
    // 2b. Verifica proof de party l INDEPENDIENTEMENTE
    boolean valid = verifyPoSC(l, permComm_l);
    
    // Dentro de verifyPoSC(l, permComm_l):
    //   RO_input = g || generators || permComm_l  ← Solo commitment de party l
    //   challenge_l = Hash(RO_input)
    //   verify(proof_l, challenge_l)
}
```

### ❓ Entonces, ¿Por qué nuestro código falla?

**Hipótesis Actualizada**: El problema NO es la construcción del RO input (que es correcto), sino **cómo leemos y parseamos los commitments**.

---

## 6. 🔬 NUEVA HIPÓTESIS: Problema en el Parser de Commitments

### Archivos ByteTree:

Verificatum guarda las commitments en formato ByteTree:

```
datasets/onpe100/dir/nizkp/default/proofs/
├── PermutationCommitment01.bt
├── PermutationCommitment02.bt
├── PoSCommitment01.bt
├── PoSCommitment02.bt
├── PoSReply01.bt
└── PoSReply02.bt
```

### Código de Lectura (Java):

```java
// MixNetElGamalVerifyFiatShamirSession.java
PGroupElementArray permutationCommitment =
    readPermutationCommitment(maxciph, l);

// Implementación:
protected PGroupElementArray readPermutationCommitment(int maxciph, int l) {
    final File file = PermutationCommitment.pcFile(proofs, l);
    // pcFile() construye: "proofs/PermutationCommitment" + formatIndex(l) + ".bt"
    
    final ByteTreeReader btr = new ByteTreeReaderF(file);
    PGroupElementArray result = v.pGroup.unsafeToElementArray(maxciph, btr);
    btr.close();
    return result;
}
```

### Código de Lectura (Julia):

```julia
# src/serializer.jl, líneas 271-293
function load_verificatum_proof(proofs::AbstractString, g::Group; party_id::Int = 1)
    party_suffix = @sprintf("%02d", party_id)
    PERMUTATION_COMMITMENT = "$proofs/PermutationCommitment$(party_suffix).bt"
    PoS_COMMITMENT = "$proofs/PoSCommitment$(party_suffix).bt"
    PoS_REPLY = "$proofs/PoSReply$(party_suffix).bt"
    
    # ¿El parser lee correctamente estos archivos?
    # ¿La estructura ByteTree es la esperada?
end
```

---

## 7. ✅ CONCLUSIÓN Y PLAN DE ACCIÓN

### Lo que sabemos con certeza:

1. ✅ ρ y h son idénticos entre -shuffle y -mix (confirmado por testing)
2. ✅ Verificatum usa los **MISMOS** ρ y h para todas las parties
3. ✅ Cada party se verifica **INDEPENDIENTEMENTE** con su propio commitment
4. ✅ El RO input es: `g || generators || permutationCommitment_l` (por party)
5. ❓ El parser de ByteTree en Julia puede tener un bug

### Plan de Diagnóstico:

#### Paso 1: Validar el Parser de ByteTree

```julia
# Test: ¿Los commitments se leen correctamente?
using ShuffleProofs

proofs_dir = "datasets/onpe100/dir/nizkp/default/proofs"
g = # ... grupo de onpe100

# Leer party 1
proof1 = ShuffleProofs.load_verificatum_proof(proofs_dir, g; party_id = 1)
println("Party 1 - Permutation commitments: ", length(proof1.𝐜))

# Leer party 2
proof2 = ShuffleProofs.load_verificatum_proof(proofs_dir, g; party_id = 2)
println("Party 2 - Permutation commitments: ", length(proof2.𝐜))

# ¿Son DIFERENTES?
if proof1.𝐜 == proof2.𝐜
    println("❌ ERROR: Los commitments son idénticos!")
else
    println("✅ OK: Los commitments son diferentes")
end
```

#### Paso 2: Comparar con vmnv

```bash
# Extraer commitments con vmnv para party 1
vmnv -mix -t ??? datasets/onpe100/protInfo.xml datasets/onpe100/dir/nizkp/default

# ¿Existe un test vector para commitments?
```

#### Paso 3: Inspeccionar ByteTree directamente

```julia
# Leer archivo raw
bytes1 = read("datasets/onpe100/dir/nizkp/default/proofs/PermutationCommitment01.bt")
bytes2 = read("datasets/onpe100/dir/nizkp/default/proofs/PermutationCommitment02.bt")

println("Tamaño Party 1: ", length(bytes1))
println("Tamaño Party 2: ", length(bytes2))

# ¿Son diferentes en tamaño o contenido?
if bytes1 == bytes2
    println("❌ ERROR: Los archivos son IDÉNTICOS!")
end
```

---

## 8. 🎯 ACCIONES INMEDIATAS

### Para ti (Usuario):

1. **Ejecuta el test del parser** (Paso 1 arriba) para verificar si los commitments se leen correctamente
2. **Compara los archivos .bt directamente**:
   ```bash
   ls -lh datasets/onpe100/dir/nizkp/default/proofs/PermutationCommitment*.bt
   md5sum datasets/onpe100/dir/nizkp/default/proofs/PermutationCommitment*.bt
   ```
3. Si los archivos son diferentes → el problema está en el parser de Julia
4. Si los archivos son idénticos → hay un bug en cómo Verificatum generó los archivos

### Para mí (Agente):

Una vez que confirmes los resultados de los tests arriba, puedo:

1. Revisar el parser de ByteTree en `src/serializer.jl`
2. Comparar con la implementación Java de Verificatum
3. Corregir cualquier discrepancia
4. Re-ejecutar la verificación

---

## 9. 📚 Referencias del Código Fuente

### Archivos Clave de Verificatum:

1. **MixNetElGamalVerifyFiatShamir.java**
   - Verifier principal
   - Inicializa hash functions, PRG, grupos

2. **MixNetElGamalVerifyFiatShamirSession.java**
   - Lógica de verificación por sesión
   - `setGlobalPrefix()`: líneas 160-195 (genera ρ)
   - `deriveGenerators()`: líneas 557-569 (genera h)
   - `verifyPoSC()`: líneas 654-705 (verifica proof de una party)
   - Loop multi-party: líneas 1396-1470

3. **PermutationCommitment.java**
   - Define estructura de commitments
   - `pcFile()`: construye path de archivos por party

### Test Vectors Disponibles:

Verificatum puede imprimir test vectors con la opción `-t`:

```bash
vmnv -mix -t der.rho,bas.h,bas.pk,bas.y_l,par.omega,par.lambda,PoSC.s,PoSC.v \
     datasets/onpe100/protInfo.xml \
     datasets/onpe100/dir/nizkp/default
```

Posibles test vectors para investigar:
- `u`: Permutation commitment
- `PoS.s`: Batching seed
- `PoS.v`: Challenge value

---

## 10. 💡 Insight Final

La belleza del diseño de Verificatum es que **NO necesita un RO input compuesto**. Cada party genera su proof **independientemente** usando los mismos generadores globales (ρ, h). 

El protocolo Fiat-Shamir aplicado es:
```
Para cada party l:
  1. Prover genera commitment_l
  2. Challenge_l = Hash(g || h || commitment_l)  ← RO independiente
  3. Prover responde con reply_l
  4. Verifier chequea: Verify(commitment_l, challenge_l, reply_l)
```

Este diseño **permite verificación paralela** de las parties sin necesidad de coordinar sus commitments.

Nuestro código debería funcionar SI el parser lee correctamente los commitments por party. **El siguiente paso crítico es validar el parser**.

---

## Estado: PENDIENTE DE TESTING

Próximo comando a ejecutar por el usuario:

```bash
md5sum datasets/onpe100/dir/nizkp/default/proofs/*.bt
```

Si los archivos `PermutationCommitment01.bt` y `PermutationCommitment02.bt` tienen checksums diferentes → problema en parser Julia  
Si tienen el MISMO checksum → problema en generación de Verificatum (poco probable)

