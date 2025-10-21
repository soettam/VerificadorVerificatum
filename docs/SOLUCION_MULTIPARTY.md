# 🎯 SOLUCIÓN AL PROBLEMA MULTI-PARTY

## Fecha: 21 de octubre de 2025

## 🔍 ROOT CAUSE IDENTIFICADO

El problema **NO** está en el Random Oracle input ni en los generadores. El problema es que **usamos los mismos ciphertexts (𝐞, 𝐞′) para todas las parties**.

### Estructura de datos en Multi-Party Mixing:

```
Party 1:
  Input:  Ciphertexts.bt (originales)
  Output: Ciphertexts01.bt (shuffled por party 1)
  
Party 2:
  Input:  Ciphertexts01.bt (salida de party 1)
  Output: Ciphertexts02.bt (shuffled por party 2)
  
Party N:
  Input:  CiphertextsN-1.bt
  Output: ShuffledCiphertexts.bt (salida final)
```

### El Bug en Nuestro Código:

```julia
# src/portable_app.jl, línea 564
# ❌ INCORRECTO: Usa MISMOS ciphertexts para todas las parties
sim = ShuffleProofs.load_verificatum_simulator(dataset)
base_proposition = sim.proposition  # Contiene Ciphertexts.bt y ShuffledCiphertexts.bt

for party_id in 1:num_parties
    # Cada party usa base_proposition.𝐞 y base_proposition.𝐞′
    # ↑ ESTO ESTÁ MAL: cada party tiene input/output diferentes
    seed = ShuffleProofs.seed(verifier, base_proposition, proof.𝐜; ρ = ρ, 𝐡 = generators)
end
```

### Verificación del Bug:

El `seed` se calcula como:
```julia
# src/verifier.jl, línea 113
tree = Tree((g, 𝐡, 𝐮, pk_tree, 𝔀, 𝔀′))
#                               ↑    ↑
#                         Input    Output
```

Si **todas las parties usan los mismos 𝔀 y 𝔀′**, entonces:
- **Mismo input en el RO** → **Mismo seed** → **Mismos challenges** → **Verificación falla**

---

## ✅ SOLUCIÓN

### Opción 1: Cargar Ciphertexts por Party (RECOMENDADO)

Modificar `detailed_chequeo_multiparty` para cargar los ciphertexts correctos por party:

```julia
function detailed_chequeo_multiparty(dataset::AbstractString, vmnv_path, num_parties::Int)
    
    # Extraer generadores GLOBALES (correcto)
    sim = ShuffleProofs.load_verificatum_simulator(dataset)
    base_g = sim.proposition.g
    base_pk = sim.proposition.pk
    verifier = sim.verifier
    
    testvectors_global = obtain_testvectors(dataset, typeof(base_g), vmnv_path; mode = "-mix")
    ρ_global = testvectors_global.ρ
    generators_global = testvectors_global.generators
    
    parties_results = []
    all_valid = true
    
    for party_id in 1:num_parties
        @info "Procesando party $party_id de $num_parties..."
        
        try
            # 1. Cargar proof de esta party
            proofs_dir = joinpath(dataset, "dir", "nizkp", "default", "proofs")
            vproof = ShuffleProofs.load_verificatum_proof(proofs_dir, base_g; party_id)
            proof = ShuffleProofs.PoSProof(vproof)
            
            # 2. ✅ NUEVO: Cargar ciphertexts específicos de esta party
            input_ciphertexts = load_party_input_ciphertexts(dataset, base_g, party_id, num_parties)
            output_ciphertexts = load_party_output_ciphertexts(dataset, base_g, party_id, num_parties)
            
            # 3. Crear proposition específica para esta party
            party_proposition = Shuffle(base_g, base_pk, input_ciphertexts, output_ciphertexts)
            
            # 4. Generar challenges con la proposition específica
            seed = ShuffleProofs.seed(verifier, party_proposition, proof.𝐜; ρ = ρ_global, 𝐡 = generators_global)
            perm_u = ShuffleProofs.challenge_perm(verifier, party_proposition, proof.𝐜; s = seed)
            perm_c = ShuffleProofs.challenge_reenc(verifier, party_proposition, proof.𝐜, proof.𝐜̂, proof.t; ρ = ρ_global, s = seed)
            
            chg = ShuffleProofs.PoSChallenge(generators_global, perm_u, perm_c)
            
            # 5. Computar verificaciones
            shuffle_checks = compute_shuffle_checks(party_proposition, proof, chg)
            verifier_checks = compute_verifier_checks(party_proposition, proof, chg, generators_global)
            
            # ... resto del código de verificación
            
        catch e
            @error "Error procesando party $party_id: $e"
            all_valid = false
        end
    end
    
    return Dict(
        "dataset" => dataset,
        "multiparty" => true,
        "num_parties" => num_parties,
        "all_valid" => all_valid,
        "parties" => parties_results,
        "definitions" => variable_definitions()
    )
end
```

### Funciones Auxiliares Necesarias:

```julia
function load_party_input_ciphertexts(dataset::AbstractString, g::Group, party_id::Int, num_parties::Int)
    """
    Carga los ciphertexts de INPUT para una party específica.
    
    Party 1: usa Ciphertexts.bt (originales)
    Party 2+: usa CiphertextsN-1.bt (salida de la party anterior)
    """
    NIZKP = joinpath(dataset, "dir", "nizkp", "default")
    G = typeof(g)
    
    if party_id == 1
        # Primera party usa los ciphertexts originales
        CIPHERTEXTS = joinpath(NIZKP, "Ciphertexts.bt")
    else
        # Parties subsecuentes usan la salida de la party anterior
        CIPHERTEXTS = joinpath(NIZKP, "proofs", @sprintf("Ciphertexts%02d.bt", party_id - 1))
    end
    
    L_tree = decode(read(CIPHERTEXTS))
    N = width_elgamal_vec(G, L_tree)
    return convert(Vector{ElGamalRow{G, N}}, L_tree)
end

function load_party_output_ciphertexts(dataset::AbstractString, g::Group, party_id::Int, num_parties::Int)
    """
    Carga los ciphertexts de OUTPUT para una party específica.
    
    Party 1 a N-1: usa CiphertextsN.bt
    Party N (última): usa ShuffledCiphertexts.bt
    """
    NIZKP = joinpath(dataset, "dir", "nizkp", "default")
    G = typeof(g)
    
    if party_id == num_parties
        # Última party produce ShuffledCiphertexts.bt
        SHUFFLED_CIPHERTEXTS = joinpath(NIZKP, "ShuffledCiphertexts.bt")
    else
        # Parties intermedias producen CiphertextsN.bt
        SHUFFLED_CIPHERTEXTS = joinpath(NIZKP, "proofs", @sprintf("Ciphertexts%02d.bt", party_id))
    end
    
    L′_tree = decode(read(SHUFFLED_CIPHERTEXTS))
    N = width_elgamal_vec(G, L′_tree)
    return convert(Vector{ElGamalRow{G, N}}, L′_tree)
end
```

---

## 📊 VERIFICACIÓN DE LA SOLUCIÓN

Una vez implementadas las funciones arriba, el flujo será:

### Party 1:
```
Input:  Ciphertexts.bt (100 ciphertexts originales)
Output: Ciphertexts01.bt (100 ciphertexts shuffled)
Proof:  PermutationCommitment01.bt, PoSCommitment01.bt, PoSReply01.bt

seed_1 = Hash(g || generators || commitment_1 || pk || Ciphertexts.bt || Ciphertexts01.bt)
challenge_1 = DeriveChallenge(seed_1)
verify_1 = Check(proof_1, challenge_1)  ← Debería ser TRUE ✅
```

### Party 2:
```
Input:  Ciphertexts01.bt (salida de party 1)
Output: Ciphertexts02.bt (shuffled por party 2)
Proof:  PermutationCommitment02.bt, PoSCommitment02.bt, PoSReply02.bt

seed_2 = Hash(g || generators || commitment_2 || pk || Ciphertexts01.bt || Ciphertexts02.bt)
challenge_2 = DeriveChallenge(seed_2)
verify_2 = Check(proof_2, challenge_2)  ← Debería ser TRUE ✅
```

---

## 🎯 PLAN DE IMPLEMENTACIÓN

### Paso 1: Añadir funciones auxiliares en serializer.jl

Agregar las dos funciones de carga de ciphertexts por party al final de `src/serializer.jl`.

### Paso 2: Modificar detailed_chequeo_multiparty

Actualizar la función en `src/portable_app.jl` para usar las propositions específicas por party.

### Paso 3: Testing

```bash
# Debería pasar ahora
julia ./JuliaBuild/chequeo_detallado.jl datasets/onpe100
```

Resultado esperado:
```
Party 1: ✅ VÁLIDA
Party 2: ✅ VÁLIDA
Resultado final: ✅ TODAS VÁLIDAS
```

---

## 🔬 INSIGHTS FINALES

### Por qué los generadores (ρ, h) son iguales:

✅ **CORRECTO**: ρ y h se derivan **ANTES** de las parties empezar. Son parámetros **globales** del protocolo.

### Por qué cada party se verifica independientemente:

✅ **CORRECTO**: Cada party genera su proof de forma **independiente** usando:
- Mismos generadores globales (ρ, h)
- Su propio commitment
- Sus propios ciphertexts (input/output)

### Lo que estaba mal:

❌ **INCORRECTO**: Estábamos usando los **mismos** input/output ciphertexts para todas las parties, lo que producía:
- Mismo seed para todas
- Mismos challenges para todas
- Verificación falla porque los proofs fueron generados con otros challenges

---

## ✨ CONCLUSIÓN

El protocolo de Verificatum es **elegante y simple**:

1. Genera parámetros globales (ρ, h) una vez
2. Cada party genera su proof independientemente
3. Cada party se verifica independientemente con sus propios input/output

Nuestro error fue **no respetar la independencia de input/output por party**.

Con la solución propuesta, el verificador multi-party debería funcionar perfectamente.

---

## 📝 PRÓXIMOS PASOS

1. Implementar `load_party_input_ciphertexts()`
2. Implementar `load_party_output_ciphertexts()`
3. Modificar `detailed_chequeo_multiparty()` para usar propositions por party
4. Testing con `onpe100`
5. Validar contra `vmnv -mix -v`

**Estimación de tiempo**: 30-45 minutos de implementación + testing.

