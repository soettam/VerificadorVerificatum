#!/bin/bash
# Script para leer secciones específicas del resumen ejecutivo
# Uso: ./read_section.sh [numero_seccion]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESUMEN_FILE="$SCRIPT_DIR/RESUMEN_EJECUTIVO.md"

# Colores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "$RESUMEN_FILE" ]; then
    echo "❌ Error: No se encontró $RESUMEN_FILE"
    exit 1
fi

# Función para mostrar menu
show_menu() {
    echo -e "${BLUE}🎯 Selector de Secciones - Resumen Ejecutivo${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo
    echo "📑 Secciones disponibles:"
    echo
    echo " 1. 🎯 Objetivo Principal"
    echo " 2. 🔑 Problema Identificado" 
    echo " 3. 💡 Solución Propuesta"
    echo " 4. 🔬 Metodología Técnica"
    echo " 5. 🏆 Caso de Estudio: Elección IACR 2018"
    echo " 6. 📊 Resultados y Logros"
    echo " 7. 🔮 Implicaciones y Trabajo Futuro"
    echo " 8. 🎯 Conclusión Estratégica"
    echo " 9. 📚 Relevancia para el Proyecto"
    echo " 0. 🎵 Todo el documento"
    echo
    echo -e "${YELLOW}Selecciona una sección (0-9):${NC}"
}

# Función para extraer sección específica
extract_section() {
    local section_num=$1
    local start_pattern=""
    local end_pattern=""
    
    case $section_num in
        1) start_pattern="## 🎯 Objetivo Principal"
           end_pattern="## 🔑 Problema Identificado" ;;
        2) start_pattern="## 🔑 Problema Identificado"
           end_pattern="## 💡 Solución Propuesta" ;;
        3) start_pattern="## 💡 Solución Propuesta"
           end_pattern="## 🔬 Metodología Técnica" ;;
        4) start_pattern="## 🔬 Metodología Técnica"
           end_pattern="## 🏆 Caso de Estudio" ;;
        5) start_pattern="## 🏆 Caso de Estudio"
           end_pattern="## 📊 Resultados y Logros" ;;
        6) start_pattern="## 📊 Resultados y Logros"
           end_pattern="## 🔮 Implicaciones y Trabajo Futuro" ;;
        7) start_pattern="## 🔮 Implicaciones y Trabajo Futuro"
           end_pattern="## 🎯 Conclusión Estratégica" ;;
        8) start_pattern="## 🎯 Conclusión Estratégica"
           end_pattern="## 📚 Relevancia para el Proyecto" ;;
        9) start_pattern="## 📚 Relevancia para el Proyecto"
           end_pattern="---" ;;
        0) cat "$RESUMEN_FILE" | sed -e 's/^#\+\s*//' -e 's/\*\*\([^*]*\)\*\*/\1/g' \
              -e 's/\*\([^*]*\)\*/\1/g' -e 's/`\([^`]*\)`/\1/g' \
              -e 's/\[\([^]]*\)\]([^)]*)/ \1 /g' -e 's/^[[:space:]]*[-*+][[:space:]]*//' \
              -e '/^[[:space:]]*$/d' | grep -v '^---*$' | awk 'length($0) > 5'
           return ;;
        *) echo "❌ Sección inválida"; return 1 ;;
    esac
    
    # Extraer la sección específica
    awk "/$start_pattern/,/$end_pattern/ { if (/$end_pattern/) exit; print }" "$RESUMEN_FILE" | \
    sed -e 's/^#\+\s*//' -e 's/\*\*\([^*]*\)\*\*/\1/g' \
        -e 's/\*\([^*]*\)\*/\1/g' -e 's/`\([^`]*\)`/\1/g' \
        -e 's/\[\([^]]*\)\]([^)]*)/ \1 /g' -e 's/^[[:space:]]*[-*+][[:space:]]*//' \
        -e '/^[[:space:]]*$/d' | grep -v '^---*$' | awk 'length($0) > 5'
}

# Función para leer con TTS
read_section() {
    local section_num=$1
    local section_text
    
    echo -e "${YELLOW}📝 Extrayendo sección...${NC}"
    section_text=$(extract_section "$section_num")
    
    if [ -z "$section_text" ]; then
        echo -e "❌ No se pudo extraer la sección $section_num"
        return 1
    fi
    
    echo -e "${YELLOW}🔊 Reproduciendo sección...${NC}"
    
    if command -v gtts-cli >/dev/null 2>&1; then
        temp_file="/tmp/section_${section_num}_$(date +%s).mp3"
        echo "$section_text" | gtts-cli --lang es --output "$temp_file" -
        mpv "$temp_file" 2>/dev/null
        rm "$temp_file"
    else
        echo -e "❌ gtts-cli no está disponible"
        echo -e "${YELLOW}💡 Instala con: pipx install gtts${NC}"
        return 1
    fi
}

# Script principal
if [ $# -eq 1 ]; then
    # Modo no interactivo
    read_section "$1"
else
    # Modo interactivo
    while true; do
        show_menu
        read -r choice
        echo
        
        case $choice in
            [0-9]) read_section "$choice"
                   echo
                   echo -e "${GREEN}¿Continuar? (y/N):${NC}"
                   read -r -n 1 continue_choice
                   echo
                   [[ ! "$continue_choice" =~ ^[Yy]$ ]] && break ;;
            q|Q) break ;;
            *) echo -e "❌ Opción inválida. Usa 0-9 o 'q' para salir." ;;
        esac
    done
fi

echo -e "${GREEN}🎉 ¡Hasta luego!${NC}"