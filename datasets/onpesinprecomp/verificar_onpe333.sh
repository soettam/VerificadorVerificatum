#!/bin/bash
set -e
DATASET_DIR="/home/soettamusb/ShuffleProofs.jl-main/datasets/onpesinprecomp"
NIZKP_DIR="$DATASET_DIR/dir/nizkp"

# Backup existing default session
if [ -d "$NIZKP_DIR/default" ] && [ ! -L "$NIZKP_DIR/default" ]; then
    mv "$NIZKP_DIR/default" "$NIZKP_DIR/default_real"
fi

# Setup onpe333 as default
ln -sf "$NIZKP_DIR/onpe333" "$NIZKP_DIR/default"

# Ensure auxsid is 'default' (required for Julia wrapper compatibility)
# We backup the original auxsid just in case
cp "$NIZKP_DIR/onpe333/auxsid" "$NIZKP_DIR/onpe333/auxsid.bak"
echo -n "default" > "$NIZKP_DIR/onpe333/auxsid"

# Run verification
echo "Verificando sesión onpe333 (como default)..."
julia --project=/home/soettamusb/ShuffleProofs.jl-main /home/soettamusb/ShuffleProofs.jl-main/JuliaBuild/chequeo_detallado.jl "$DATASET_DIR"

# Restore
mv "$NIZKP_DIR/onpe333/auxsid.bak" "$NIZKP_DIR/onpe333/auxsid"
rm "$NIZKP_DIR/default"
if [ -d "$NIZKP_DIR/default_real" ]; then
    mv "$NIZKP_DIR/default_real" "$NIZKP_DIR/default"
fi
