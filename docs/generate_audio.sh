#!/bin/bash
# Script para leer y guardar el audio del RESUMEN_EJECUTIVO.md
# Genera archivo de audio con Google TTS del resumen ejecutivo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESUMEN_FILE="$SCRIPT_DIR/RESUMEN_EJECUTIVO.md"
AUDIO_FILE="$SCRIPT_DIR/RESUMEN_EJECUTIVO_AUDIO.mp3"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📚 Generador de Audio - Resumen Ejecutivo${NC}"
echo -e "${BLUE}==========================================${NC}"

# Verificar que existe el archivo de resumen
if [ ! -f "$RESUMEN_FILE" ]; then
    echo -e "${RED}❌ Error: No se encontró $RESUMEN_FILE${NC}"
    exit 1
fi

# Verificar que gtts-cli está disponible
if ! command -v gtts-cli >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: gtts-cli no está instalado${NC}"
    echo -e "${YELLOW}💡 Instala con: pipx install gtts${NC}"
    exit 1
fi

# Función para extraer solo el texto del markdown (sin formateo)
extract_text_from_markdown() {
    # Remover headers markdown (# ## ###)
    # Remover enlaces [texto](url)
    # Remover énfasis (**texto** *texto*)
    # Remover listas (- * +)
    # Remover código (`código` ```código```)
    # Mantener solo texto plano
    sed -e 's/^#\+\s*//' \
        -e 's/\*\*\([^*]*\)\*\*/\1/g' \
        -e 's/\*\([^*]*\)\*/\1/g' \
        -e 's/`\([^`]*\)`/\1/g' \
        -e 's/```[^`]*```//g' \
        -e 's/\[\([^]]*\)\]([^)]*)/ \1 /g' \
        -e 's/^[[:space:]]*[-*+][[:space:]]*//' \
        -e 's/^[[:space:]]*[0-9]\+\.[[:space:]]*//' \
        -e '/^[[:space:]]*$/d' \
        "$RESUMEN_FILE" | \
    # Remover líneas que son solo separadores o metadatos
    grep -v '^---*$' | \
    grep -v '^\*.*generado automáticamente' | \
    grep -v '^Resumen generado' | \
    # Agregar pausas después de títulos y secciones
    sed -e 's/:/: ./g' -e 's/\./. /g' | \
    # Limpiar espacios múltiples
    tr -s ' ' | \
    # Remover líneas muy cortas (probablemente metadatos)
    awk 'length($0) > 10'
}

echo -e "${YELLOW}📝 Procesando archivo markdown...${NC}"

# Extraer texto limpio
clean_text=$(extract_text_from_markdown)

if [ -z "$clean_text" ]; then
    echo -e "${RED}❌ Error: No se pudo extraer texto del archivo${NC}"
    exit 1
fi

echo -e "${YELLOW}🔊 Generando audio con Google TTS...${NC}"
echo -e "${BLUE}   Archivo de salida: $AUDIO_FILE${NC}"

# Generar audio con Google TTS
if echo "$clean_text" | gtts-cli --lang es --output "$AUDIO_FILE" -; then
    echo -e "${GREEN}✅ Audio generado exitosamente${NC}"
    
    # Mostrar información del archivo
    if command -v mediainfo >/dev/null 2>&1; then
        echo -e "\n${BLUE}📊 Información del archivo:${NC}"
        mediainfo "$AUDIO_FILE" | grep -E "(Duration|File size|Bit rate)"
    elif command -v ffprobe >/dev/null 2>&1; then
        echo -e "\n${BLUE}📊 Información del archivo:${NC}"
        ffprobe -v quiet -show_entries format=duration,size -of csv=p=0 "$AUDIO_FILE" 2>/dev/null | \
        awk -F, '{printf "Duration: %.1f segundos\nFile size: %.2f MB\n", $1, $2/1024/1024}'
    fi
    
    file_size=$(ls -lh "$AUDIO_FILE" | awk '{print $5}')
    echo -e "${GREEN}📁 Tamaño del archivo: $file_size${NC}"
    
    echo -e "\n${YELLOW}🎵 Opciones disponibles:${NC}"
    echo -e "${BLUE}1.${NC} Reproducir ahora: ${GREEN}mpv \"$AUDIO_FILE\"${NC}"
    echo -e "${BLUE}2.${NC} Reproducir en bucle: ${GREEN}mpv --loop \"$AUDIO_FILE\"${NC}"
    echo -e "${BLUE}3.${NC} Ver archivo: ${GREEN}ls -la \"$AUDIO_FILE\"${NC}"
    
    # Preguntar si quiere reproducir
    echo -e "\n${YELLOW}¿Reproducir el audio ahora? (y/N):${NC}"
    read -r -n 1 response
    echo
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🎵 Reproduciendo...${NC}"
        if command -v mpv >/dev/null 2>&1; then
            mpv "$AUDIO_FILE"
        elif command -v mplayer >/dev/null 2>&1; then
            mplayer "$AUDIO_FILE"
        elif command -v aplay >/dev/null 2>&1 && [[ "$AUDIO_FILE" == *.wav ]]; then
            aplay "$AUDIO_FILE"
        else
            echo -e "${RED}❌ No hay reproductor de audio disponible${NC}"
            echo -e "${YELLOW}💡 Instala: sudo apt install mpv${NC}"
        fi
    fi
    
else
    echo -e "${RED}❌ Error al generar el audio${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Proceso completado${NC}"