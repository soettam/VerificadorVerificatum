# 🔊 Audio Scripts - Resumen Ejecutivo

Scripts para generar y reproducir audio del documento "Verified Verifiers for Verifying Elections".

## 📁 Archivos

### `generate_audio.sh` - Generador completo de audio
Script principal que convierte el RESUMEN_EJECUTIVO.md a audio MP3 usando Google TTS.

**Características:**
- ✅ Procesa markdown y extrae texto limpio
- 🎵 Genera audio de alta calidad con Google TTS 
- 📊 Muestra información del archivo generado
- 🔊 Opción de reproducir inmediatamente
- 🎨 Interface colorizada con emojis

**Uso:**
```bash
./generate_audio.sh
```

### `read_resume.sh` - Reproductor rápido
Script simple para reproducir el audio del resumen.

**Uso:**
```bash
./read_resume.sh
```

### `read_section.sh` - Lector por secciones
Script interactivo para leer secciones específicas del documento.

**Características:**
- 🎯 Menu interactivo con 9 secciones
- 🔊 Lectura individual de cada sección
- ⚡ Modo no-interactivo con parámetros
- 🎨 Interface colorizada

**Uso:**
```bash
# Modo interactivo (menu)
./read_section.sh

# Leer sección específica
./read_section.sh 1    # Objetivo Principal
./read_section.sh 5    # Caso de Estudio
./read_section.sh 0    # Todo el documento
```

## � Guía de Uso

### Método 1: Usando Makefile (Recomendado)
```bash
# Ver ayuda completa
make help

# Generar audio completo
make audio

# Reproducir resumen
make read

# Lector interactivo por secciones
make sections

# Instalar dependencias
make install-deps

# Limpiar archivos temporales
make clean

# Ver información del archivo de audio
make info
```

### Método 2: Scripts Directos
```bash
# Generar audio completo
./generate_audio.sh

# Reproducir resumen
./read_resume.sh

# Lector interactivo por secciones
./read_section.sh

# Leer sección específica directamente
./read_section.sh 3  # Lee la sección 3 (Marco Metodológico)
```

## �🛠️ Requisitos

### Instalación automática:
Los scripts verifican dependencias y muestran comandos de instalación si faltan.

### Requisitos manuales:
```bash
# Google TTS (obligatorio)
pipx install gtts

# Reproductor de audio (recomendado)
sudo apt install mpv

# Opcional: información de archivos multimedia
sudo apt install mediainfo
```

## 🎯 Flujo de trabajo

1. **Primera vez:** Ejecutar `generate_audio.sh` para crear el MP3
2. **Reproducciones posteriores:** Usar `read_resume.sh` para reproducir rápido
3. **Regenerar:** Ejecutar `generate_audio.sh` nuevamente si se actualiza el markdown

## 📊 Salida esperada

- **Archivo:** `RESUMEN_EJECUTIVO_AUDIO.mp3`
- **Duración:** ~15-20 minutos (estimado)
- **Calidad:** 24kHz, Mono, MP3
- **Tamaño:** ~10-15 MB (estimado)

## 🔧 Personalización

### Cambiar idioma:
Edita `generate_audio.sh` línea con `--lang es` por otro idioma:
```bash
--lang en    # Inglés
--lang fr    # Francés
--lang de    # Alemán
```

### Cambiar velocidad:
Agrega `--slow=true` para voz más lenta:
```bash
gtts-cli --lang es --slow=true --output ...
```

## 🚀 Comandos rápidos

```bash
# Generar audio
./generate_audio.sh

# Reproducir
./read_resume.sh

# Solo generar (sin reproducir)
./generate_audio.sh < /dev/null

# Reproducir en bucle
mpv --loop RESUMEN_EJECUTIVO_AUDIO.mp3
```

## 📝 Notas técnicas

- Los scripts procesan markdown removiendo formato para mejor TTS
- Google TTS requiere conexión a internet
- El audio se genera en español (es) por defecto
- Compatible con reproductores: mpv, mplayer, aplay (WAV)

---
*Scripts creados para el proyecto VerificadorVerificatum*