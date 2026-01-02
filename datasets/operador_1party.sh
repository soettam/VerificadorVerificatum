#!/bin/sh
################### Sin precomputation

mkdir onpesinprecomp
cd onpesinprecomp
PGROUP=$(vog -gen ECqPGroup -name "P-256") 
vmni -prot -sid 'ONPE' -name 'Eleccion Onpe' -nopart 1 -thres 1 -pgroup "$PGROUP"
RAND=$(vog -gen RandomDevice /dev/urandom) 
vmni -party -e -name "Servidor01" -hint "localhost:4041" -http "http://localhost:8041" -rand "$RAND"
cp localProtInfo.xml protInfo01.xml
vmni -merge protInfo01.xml protInfo.xml
vmn -keygen -e publicKey
vmnc -pkey -outi native publicKey publicKey_ext
vmnd -ciphs -e -i native -width 1 publicKey_ext 10 ciphertexts_ext
vmnc -ciphs -sloppy -ini native -width 1 ciphertexts_ext ciphertexts
vmn -shuffle privInfo.xml protInfo.xml ciphertexts ciphertextsout 
cd ..
cd ..
julia JuliaBuild/chequeo_detallado.jl datasets/onpesinprecomp

################### Con precomputation

mkdir onpeconprecomp
cd onpeconprecomp
PGROUP=$(vog -gen ECqPGroup -name "P-256") 
vmni -prot -sid 'ONPE' -name 'Eleccion Onpe' -nopart 1 -thres 1 -pgroup "$PGROUP"
RAND=$(vog -gen RandomDevice /dev/urandom) 
vmni -party -e -name "Servidor01" -hint "localhost:4041" -http "http://localhost:8041" -rand "$RAND"
cp localProtInfo.xml protInfo01.xml
vmni -merge protInfo01.xml protInfo.xml
vmn -keygen -e publicKey
vmnc -pkey -outi native publicKey publicKey_ext
vmn -precomp -e -width 1 -maxciph 10
vmnd -ciphs -e -i native -width 1 publicKey_ext 10 ciphertexts_ext
vmnc -ciphs -sloppy -ini native -width 1 ciphertexts_ext ciphertexts
vmn -shuffle privInfo.xml protInfo.xml ciphertexts ciphertextsout 
cd ..
cd ..
julia JuliaBuild/chequeo_detallado.jl datasets/onpeconprecomp
##ERROR porque no se logra generar /dir/nizkp/default//proofs//PoSCommitment01.bt 

###################

################### Hasta decriptacion

mkdir onpeprueba
cd onpeprueba
PGROUP=$(vog -gen ECqPGroup -name "P-256") 
vmni -prot -sid 'ONPE' -name 'Eleccion Onpe' -nopart 1 -thres 1 -pgroup "$PGROUP"
RAND=$(vog -gen RandomDevice /dev/urandom) 
vmni -party -e -name "Servidor01" -hint "localhost:4041" -http "http://localhost:8041" -rand "$RAND"
cp localProtInfo.xml protInfo01.xml
vmni -merge protInfo01.xml protInfo.xml
vmn -keygen -e publicKey
vmnc -pkey -outi native publicKey publicKey_ext
vmnd -ciphs -e -i native -width 1 publicKey_ext 33 ciphertexts_ext
vmnc -ciphs -sloppy -ini native -width 1 ciphertexts_ext ciphertexts

vmn -shuffle privInfo.xml protInfo.xml ciphertexts ciphertextsout -auxsid onpeprueba

mkdir -p shuffle
cp -r dir shuffle/ 2>/dev/null || true
cp -r httproot shuffle/ 2>/dev/null || true

vmn -decrypt privInfo.xml protInfo.xml ciphertextsout plaintexts_orig -auxsid onpeprueba

mkdir -p decrypt
cp -r dir decrypt/ 2>/dev/null || true
cp -r httproot decrypt/ 2>/dev/null || true

vmnc -plain -outi native plaintexts_orig plaintexts
cp shuffle/dir/nizkp/onpeprueba/ShuffledCiphertexts.bt dir/nizkp/onpeprueba/

cd ..
cd ..

julia JuliaBuild/chequeo_detallado.jl datasets/onpedecrypt -mix onpeprueba
julia JuliaBuild/chequeo_detallado.jl datasets/onpedecrypt -mix onpeprueba > log_onpedecrypt.txt
###################


/usr/local/bin/vmnv -shuffle -t der.rho,bas.h /home/soettamusb/ShuffleProofs.jl-main/datasets/onpesinprecomp/protInfo.xml /home/soettamusb/ShuffleProofs.jl-main/datasets/onpesinprecomp/dir/nizkp/default

ERROR: Attempting to verify proof of mixing, but proof is a proof of shuffling!


~/ShuffleProofs.jl-main/dist/VerificadorShuffleProofs/bin/verificador ~/ShuffleProofs.jl-main/datasets/onpesinprecomp

vmn -decrypt privInfo.xml protInfo.xml ciphertextsout plaintexts_orig

/usr/local/bin/vmnv -mix -t der.rho,bas.h /home/soettamusb/ShuffleProofs.jl-main/datasets/onpesinprecomp/protInfo.xml /home/soettamusb/ShuffleProofs.jl-main/datasets/onpesinprecomp/dir/nizkp/default


vmnc -plain -outi native plaintexts_orig plaintexts
vmnv -v -e -mix protInfo.xml dir/nizkp/default 

