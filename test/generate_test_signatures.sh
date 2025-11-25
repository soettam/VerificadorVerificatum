#!/bin/bash

# Script para generar datos de prueba con firmas RSA-2048 usando OpenSSL
# Esto crea un mini-dataset para probar la verificación de firmas

set -e

TEST_DIR="test/test_data_signatures"
mkdir -p "$TEST_DIR"

echo "================================================"
echo "Generando datos de prueba con firmas RSA-2048"
echo "================================================"
echo

# 1. Generar par de llaves RSA-2048
echo "1. Generando par de llaves RSA-2048..."
openssl genrsa -out "$TEST_DIR/private_key.pem" 2048 2>/dev/null
openssl rsa -in "$TEST_DIR/private_key.pem" -pubout -out "$TEST_DIR/public_key.pem" 2>/dev/null

# 2. Convertir llave pública a formato DER (X.509)
echo "2. Convirtiendo llave pública a formato DER..."
openssl rsa -pubin -in "$TEST_DIR/public_key.pem" -outform DER -out "$TEST_DIR/public_key.der" 2>/dev/null

# 3. Crear archivos de datos de prueba
echo "3. Creando archivos de datos de prueba..."
echo "Este es un archivo de prueba - PermutationCommitment01" > "$TEST_DIR/PermutationCommitment01.bt"
echo "Este es un archivo de prueba - PoSCommitment01" > "$TEST_DIR/PoSCommitment01.bt"
echo "Este es un archivo de prueba - PoSReply01" > "$TEST_DIR/PoSReply01.bt"

# 4. Firmar cada archivo con RSA-SHA256
echo "4. Firmando archivos con RSA-SHA256..."
for file in PermutationCommitment01.bt PoSCommitment01.bt PoSReply01.bt; do
    echo "   Firmando $file..."
    openssl dgst -sha256 -sign "$TEST_DIR/private_key.pem" \
        -out "$TEST_DIR/${file}.sig" \
        "$TEST_DIR/$file"
done

# 5. Convertir llave pública DER a hexadecimal
echo "5. Generando llave pública en formato hexadecimal..."
xxd -p "$TEST_DIR/public_key.der" | tr -d '\n' > "$TEST_DIR/public_key.hex"

# 6. Crear archivo de configuración con la llave
echo "6. Creando archivo de configuración..."
cat > "$TEST_DIR/protInfo.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<protocol>
    <version>3.1.0</version>
    <sid>TEST</sid>
    <name>Test Protocol</name>
    <nopart>2</nopart>
    <thres>1</thres>
    <pgroup>ECqPGroup(P-256)</pgroup>
    <keywidth>2048</keywidth>
    <vbitlen>256</vbitlen>
    <vbitlenro>256</vbitlenro>
    <ebitlen>256</ebitlen>
    <ebitlenro>256</ebitlenro>
    <prg>SHA-256</prg>
    <rohash>SHA-256</rohash>
</protocol>
EOF

# 7. Crear directorio de proofs
mkdir -p "$TEST_DIR/dir/nizkp/default/proofs"
echo "1" > "$TEST_DIR/dir/nizkp/default/proofs/activethreshold"
cp "$TEST_DIR/PermutationCommitment01.bt" "$TEST_DIR/dir/nizkp/default/proofs/"
cp "$TEST_DIR/PoSCommitment01.bt" "$TEST_DIR/dir/nizkp/default/proofs/"
cp "$TEST_DIR/PoSReply01.bt" "$TEST_DIR/dir/nizkp/default/proofs/"
cp "$TEST_DIR/PermutationCommitment01.bt.sig" "$TEST_DIR/dir/nizkp/default/proofs/"
cp "$TEST_DIR/PoSCommitment01.bt.sig" "$TEST_DIR/dir/nizkp/default/proofs/"
cp "$TEST_DIR/PoSReply01.bt.sig" "$TEST_DIR/dir/nizkp/default/proofs/"

# 8. Copiar llave pública DER a la ubicación esperada
cp "$TEST_DIR/public_key.der" "$TEST_DIR/publicKey"

# 9. Verificar manualmente las firmas con OpenSSL
echo
echo "7. Verificando firmas con OpenSSL (control)..."
all_valid=true
for file in PermutationCommitment01.bt PoSCommitment01.bt PoSReply01.bt; do
    if openssl dgst -sha256 -verify "$TEST_DIR/public_key.pem" \
        -signature "$TEST_DIR/${file}.sig" \
        "$TEST_DIR/$file" 2>/dev/null; then
        echo "   ✓ $file - firma válida"
    else
        echo "   ✗ $file - firma inválida"
        all_valid=false
    fi
done

echo
echo "================================================"
echo "Dataset de prueba generado en: $TEST_DIR"
echo "================================================"
echo
echo "Archivos generados:"
echo "  - private_key.pem         : Llave privada RSA-2048 (PEM)"
echo "  - public_key.pem          : Llave pública RSA-2048 (PEM)"
echo "  - public_key.der          : Llave pública RSA-2048 (DER)"
echo "  - public_key.hex          : Llave pública en hexadecimal"
echo "  - publicKey               : Llave pública DER (formato Verificatum)"
echo "  - protInfo.xml            : Configuración del protocolo"
echo "  - *.bt                    : Archivos de datos"
echo "  - *.bt.sig                : Firmas RSA-SHA256"
echo "  - dir/nizkp/default/proofs/ : Estructura de directorios"
echo
echo "Llave pública (hex):"
head -c 80 "$TEST_DIR/public_key.hex"
echo "..."
echo
echo "Uso en Julia:"
echo "  julia> include(\"test/test_signature_verifier_full.jl\")"
echo

if [ "$all_valid" = true ]; then
    echo "✓ Todas las firmas verificadas correctamente con OpenSSL"
    exit 0
else
    echo "✗ Error: Algunas firmas no son válidas"
    exit 1
fi
