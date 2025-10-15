# Makefile para scripts de audio del Resumen Ejecutivo
# Uso: make [target]

.PHONY: audio read sections clean help install-deps

# Colores para output
BLUE=\033[0;34m
GREEN=\033[0;32m
YELLOW=\033[1;33m
NC=\033[0m # No Color

# Archivos
AUDIO_FILE=RESUMEN_EJECUTIVO_AUDIO.mp3
MARKDOWN_FILE=RESUMEN_EJECUTIVO.md

## 🎵 Generar archivo de audio completo
audio:
	@echo -e "$(BLUE)🎵 Generando audio del resumen ejecutivo...$(NC)"
	@./generate_audio.sh

## 🔊 Reproducir resumen ejecutivo
read:
	@echo -e "$(BLUE)🔊 Reproduciendo resumen ejecutivo...$(NC)"
	@./read_resume.sh

## 🎯 Leer por secciones (modo interactivo)
sections:
	@echo -e "$(BLUE)🎯 Modo de secciones interactivo...$(NC)"
	@./read_section.sh

## 🧹 Limpiar archivos de audio generados
clean:
	@echo -e "$(YELLOW)🧹 Limpiando archivos de audio...$(NC)"
	@rm -f $(AUDIO_FILE)
	@rm -f /tmp/tts_*.mp3
	@rm -f /tmp/section_*.mp3
	@echo -e "$(GREEN)✅ Limpieza completada$(NC)"

## 📦 Instalar dependencias requeridas
install-deps:
	@echo -e "$(BLUE)📦 Instalando dependencias...$(NC)"
	@command -v pipx >/dev/null || (echo "Instalando pipx..." && sudo apt install -y pipx)
	@command -v gtts-cli >/dev/null || (echo "Instalando Google TTS..." && pipx install gtts)
	@command -v mpv >/dev/null || (echo "Instalando MPV..." && sudo apt install -y mpv)
	@echo -e "$(GREEN)✅ Dependencias instaladas$(NC)"

## 📊 Información del archivo de audio
info:
	@if [ -f "$(AUDIO_FILE)" ]; then \
		echo -e "$(BLUE)📊 Información del archivo de audio:$(NC)"; \
		ls -lh $(AUDIO_FILE); \
		if command -v mediainfo >/dev/null 2>&1; then \
			mediainfo $(AUDIO_FILE) | grep -E "(Duration|File size|Bit rate)"; \
		elif command -v ffprobe >/dev/null 2>&1; then \
			ffprobe -v quiet -show_entries format=duration -of csv=p=0 $(AUDIO_FILE) 2>/dev/null | awk '{printf "Duración: %.1f segundos\n", $$1}'; \
		fi; \
	else \
		echo -e "$(YELLOW)⚠️  No existe $(AUDIO_FILE). Ejecuta 'make audio' primero.$(NC)"; \
	fi

## ❓ Mostrar esta ayuda
help:
	@echo -e "$(BLUE)🎵 Audio Scripts - Resumen Ejecutivo$(NC)"
	@echo -e "$(BLUE)====================================$(NC)"
	@echo
	@echo -e "$(GREEN)Comandos disponibles:$(NC)"
	@echo
	@awk 'BEGIN {FS = ":.*##"}; /^[a-zA-Z_-]+:.*##/ { printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo
	@echo -e "$(GREEN)Ejemplos:$(NC)"
	@echo -e "  make audio          # Genera el audio completo"
	@echo -e "  make read           # Reproduce el audio"
	@echo -e "  make sections       # Lector interactivo por secciones"
	@echo -e "  make install-deps   # Instala dependencias"
	@echo -e "  make clean          # Limpia archivos temporales"
	@echo

# Target por defecto
.DEFAULT_GOAL := help