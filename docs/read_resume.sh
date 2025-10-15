#!/bin/bash
# Script simple para leer el resumen ejecutivo
# Uso: ./read_resume.sh

cd "$(dirname "$0")"

echo "🔊 Leyendo Resumen Ejecutivo..."

if [ -f "RESUMEN_EJECUTIVO_AUDIO.mp3" ]; then
    echo "📁 Reproduciendo audio existente..."
    mpv RESUMEN_EJECUTIVO_AUDIO.mp3 2>/dev/null || echo "❌ Error: Instala mpv para reproducir audio"
else
    echo "🎵 Generando y reproduciendo audio..."
    ./generate_audio.sh
fi