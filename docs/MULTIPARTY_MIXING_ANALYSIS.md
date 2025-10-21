# Análisis: Soporte Multi-Party Mixing

## Estado Actual del Código

### ✅ Soporte Implementado

El código en `src/` tiene soporte **completo** para:

1. **Shuffling de una sola party** (`type = "shuffling"`)
   - Carga prueba completa (PoSCommitment01.bt, PoSReply01.bt)
   - Verifica con generadores únicos (ρ, h)
   - **FUNCIONA CORRECTAMENTE**

### ❌ Limitaciones Identificadas

El código tiene **soporte limitado** para:

1. **Mixing multi-party** (`type = "mixing"`)
   - Solo carga prueba de **party 01** (hardcoded)
   - Ignora pruebas de party 02, 03, ... N
   - **NO PUEDE VERIFICAR CORRECTAMENTE**

## Evidencia Técnica

### Código Problemático

**Archivo**: `src/serializer.jl`, líneas 270-290

```julia
function load_verificatum_proof(proofs::AbstractString, g::Group)
    # ⚠️ HARDCODED: Solo carga party 01
    PERMUTATION_COMMITMENT = "$proofs/PermutationCommitment01.bt"
    PoS_COMMITMENT = "$proofs/PoSCommitment01.bt"
    PoS_REPLY = "$proofs/PoSReply01.bt"
    
    # ... resto del código
    
    return VShuffleProof(μ, τ, σ)  # Solo party 01
end
```

### Estructura de Dataset Multi-Party

**Ejemplo**: `datasets/onpe100/` (mixing de 2 parties)

```
proofs/
  ├── PermutationCommitment01.bt  ← Party 1
  ├── PermutationCommitment02.bt  ← Party 2
  ├── PoSCommitment01.bt          ← Party 1
  ├── PoSCommitment02.bt          ← Party 2
  ├── PoSReply01.bt               ← Party 1
  ├── PoSReply02.bt               ← Party 2
  ├── activethreshold              → "2" (2 parties activas)
  └── ...
```

**Problema**: `load_verificatum_proof()` solo lee archivos `*01.bt`, ignora `*02.bt`

## Por Qué Falla la Verificación

### Problema de Generadores

En un mixing multi-party:

1. **Party 01** genera prueba con generadores `(ρ₁, h₁)`
2. **Party 02** genera prueba con generadores `(ρ₂, h₂)`
3. **vmnv -mix** extrae generadores **globales** `(ρ_global, h_global)`

**Resultado**: Los generadores extraídos por `vmnv` **NO coinciden** con los que usó party 01 para generar su prueba, causando que **todos los chequeos fallen**.

### Ecuación del Problema

Para verificar correctamente un mixing multi-party, necesitas:

```
Verificación correcta = 
  Verify(Proof₁, ρ₁, h₁) ∧ 
  Verify(Proof₂, ρ₂, h₂) ∧ 
  ... ∧
  Verify(ProofN, ρN, hN)
```

**Actual**: Solo hace `Verify(Proof₁, ρ_global, h_global)` → **FALLA**

## Soluciones Posibles

### Opción 1: Usar Verificador de Verificatum (RECOMENDADO)

```bash
# Verificación completa multi-party
vmnv -mix -v datasets/onpe100/protInfo.xml datasets/onpe100/dir/nizkp/default
```

**Pros**:
- ✅ Soportado oficialmente por Verificatum
- ✅ Maneja correctamente múltiples parties
- ✅ Genera generadores correctos para cada party
- ✅ No requiere cambios en el código

**Contras**:
- ❌ No genera salida estructurada JSON
- ❌ No integrado con el flujo actual

### Opción 2: Implementar Verificación Multi-Party

Modificar `src/serializer.jl` para:

1. **Leer `activethreshold`** para determinar número de parties
2. **Cargar pruebas de todas las parties** (01, 02, ..., N)
3. **Extraer generadores por party** usando `vmnv` con parámetros específicos
4. **Verificar cada prueba individualmente** con sus generadores
5. **Combinar resultados** (AND lógico de todas las verificaciones)

**Código sugerido**:

```julia
function load_verificatum_multiparty_proofs(proofs::AbstractString, g::Group)
    threshold_file = joinpath(dirname(proofs), "activethreshold")
    num_parties = parse(Int, strip(read(threshold_file, String)))
    
    proofs_list = []
    for i in 1:num_parties
        suffix = lpad(i, 2, '0')
        proof = load_single_party_proof(proofs, suffix, g)
        push!(proofs_list, proof)
    end
    
    return proofs_list
end

function verify_multiparty_mixing(dataset, vmnv_path)
    # 1. Cargar todas las pruebas
    proofs = load_verificatum_multiparty_proofs(...)
    
    # 2. Para cada party:
    for (i, proof) in enumerate(proofs)
        # Extraer generadores específicos de party i
        ρᵢ, hᵢ = extract_party_generators(dataset, i, vmnv_path)
        
        # Verificar prueba con generadores correctos
        result = verify_single_party(proof, ρᵢ, hᵢ)
        
        if !result
            return false  # Falló party i
        end
    end
    
    return true  # Todas las parties verificadas
end
```

**Esfuerzo estimado**: 8-12 horas de desarrollo + testing

**Pros**:
- ✅ Solución completa y correcta
- ✅ Integrado en el flujo actual
- ✅ Salida estructurada JSON

**Contras**:
- ❌ Requiere entender protocolo Verificatum en profundidad
- ❌ Necesita extraer generadores por party (no documentado)
- ❌ Alto riesgo de errores sutiles

### Opción 3: Validar y Rechazar Multi-Party (IMPLEMENTADO)

Detectar datasets multi-party y advertir al usuario:

```julia
# YA IMPLEMENTADO en portable_app.jl
if proof_type == "mixing"
    @warn """
    Dataset tipo 'mixing' (multi-party) detectado.
    Solo se verificará party 01.
    Use 'vmnv -mix -v' para verificación completa.
    """
end
```

**Pros**:
- ✅ Ya implementado
- ✅ Evita resultados incorrectos
- ✅ Guía al usuario a la solución correcta

**Contras**:
- ❌ No verifica el dataset completo
- ❌ Requiere herramienta externa

## Recomendación Final

**Para datasets multi-party como `onpe100`**:

1. **Uso inmediato**: Usar `vmnv -mix -v` directamente
2. **Desarrollo futuro**: Implementar Opción 2 si se requiere verificación integrada

**Para datasets single-party**:
- El código actual funciona perfectamente ✅

## Datasets de Prueba

### ✅ Funcionan correctamente (single-party)

- `datasets/onpesinprecomp/` → type: "shuffling", threshold: 1
- `datasets/onpedecrypt/` → type: "shuffling", threshold: 1 (si no tiene problemas de versión)

### ❌ NO funcionan (multi-party)

- `datasets/onpe100/` → type: "mixing", threshold: 2
- Cualquier dataset con `activethreshold > 1`

## Referencias

- **Código clave**: `src/serializer.jl:270-290` (`load_verificatum_proof`)
- **Detección**: `src/portable_app.jl:340-367` (auto-detección implementada)
- **Verificatum docs**: Protocolo de mixing multi-party no documentado públicamente

---

**Fecha**: 21 de octubre de 2025  
**Autor**: Análisis técnico de ShuffleProofs.jl  
**Estado**: Limitación identificada y documentada
