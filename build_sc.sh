#!/bin/bash
# build_sc.sh: build Faust .dsp files into SuperCollider UGens (scsynth), tuned and
# tested for Apple Silicon (M2). Replaces faust2supercollider for these files.
#
# Usage:
#     SUPERCOLLIDER_HEADERS=/path/to/supercollider/include ./build_sc.sh file1.dsp [file2.dsp ...]
#     ./build_sc.sh -install file.dsp      also copies the results into the Extensions folder
#     ./build_sc.sh -supernova file.dsp    also builds a supernova plugin
#
# SUPERCOLLIDER_HEADERS is the `include` folder of a SuperCollider source checkout (the one
# containing plugin_interface/, common/ and server/), as for faust2supercollider. Use the
# headers of the SuperCollider version you run.
#
# Output (next to each .dsp): Name.scx (the plugin) and Name.sc (the sclang class), where
# Name is the file's `declare name` (no "Faust" prefix; see PREFIX below).
#
# Differences from faust2supercollider, and why:
# * Compiler flags: -O3 -fno-math-errno -fno-trapping-math -ffp-contract=fast instead of
#   -Ofast. -Ofast includes -ffinite-math-only, which lets the compiler assume no infinities
#   or NaNs, but these designs take the log of silence (-inf). On an M2, -Ofast was also not
#   faster (OTT was 42 % slower); this set was the fastest safe one tested.
# * Faust options: scalar code, no -vec and no -ftz. These DSPs are almost all recursive
#   filters, so -vec was 20-80 % slower at block size 64. Apple Silicon handles denormals at
#   full speed (scsynth does not enable flush-to-zero on arm64), and -ftz 2 cost 2-34 %.
#   On Intel, scsynth turns on flush-to-zero and denormals-are-zero itself.
# * Architecture file: supercollider_fixed.cpp (in this folder), which fixes a constructor
#   bug in Faust's supercollider.cpp: when the UGen runs at control rate (.kr), the stock
#   file reports a false allocation failure, never sets the calc function, and frees an
#   uninitialised pointer when the synth is freed (which can crash scsynth). (.ar is not
#   affected: the generated class only accepts audio-rate inputs there.)
#
# Extra flags can be added with EXTRA_CXXFLAGS="...". FAUST_OPTIONS="..." adds Faust options.

set -e
# Prefix added to every UGen and class name. Empty: comp.dsp ("declare name \"CompFF\"")
# becomes CompFF. Set PREFIX=Faust (faust2supercollider's default) to get FaustCompFF.
# Without a prefix, check the names don't clash with other classes or extensions you have.
PREFIX="${PREFIX-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ARCH="$HERE/supercollider_fixed.cpp"
CXX="${CXX:-c++}"
OPT_FLAGS="-O3 -fno-math-errno -fno-trapping-math -ffp-contract=fast"
INSTALL=0; SUPERNOVA=0; FILES=()

for a in "$@"; do
    case "$a" in
        -install)   INSTALL=1 ;;
        -supernova) SUPERNOVA=1 ;;
        -h|-help)   sed -n '2,12p' "$0"; exit 0 ;;
        *.dsp)      FILES+=("$a") ;;
        *)          echo "Unknown argument: $a"; exit 1 ;;
    esac
done
[ ${#FILES[@]} -gt 0 ] || { echo "Usage: $0 [-install] [-supernova] file.dsp ..."; exit 1; }
[ -f "$ARCH" ] || { echo "Can't find $ARCH (keep it next to this script)"; exit 1; }

SC="${SUPERCOLLIDER_HEADERS:-}"
if [ ! -d "$SC/plugin_interface" ]; then
    for d in /usr/local/include/SuperCollider/include /usr/local/include/supercollider /usr/include/SuperCollider /usr/include/supercollider; do
        [ -d "$d/plugin_interface" ] && SC="$d" && break
    done
fi
[ -d "$SC/plugin_interface" ] || { echo "Set SUPERCOLLIDER_HEADERS to the 'include' folder of a SuperCollider source checkout"; exit 1; }

FAUSTINC="$(faust --includedir)"
INCLUDE="-I$SC/plugin_interface -I$SC/common -I$SC/server -I$FAUSTINC"

if [ "$(uname)" = Darwin ]; then
    EXT=scx
    PLAT="-DSC_DARWIN -bundle -arch arm64 -framework CoreFoundation -framework CoreServices -undefined dynamic_lookup"
    EXTDIR="$HOME/Library/Application Support/SuperCollider/Extensions/Faust"
else
    EXT=so
    PLAT="-DSC_LINUX -shared -fPIC"
    EXTDIR="$HOME/.local/share/SuperCollider/Extensions/Faust"
fi

for dsp in "${FILES[@]}"; do
    [ -f "$dsp" ] || { echo "No such file: $dsp"; exit 1; }
    src_dir="$(cd "$(dirname "$dsp")" && pwd)"; base="$(basename "$dsp" .dsp)"
    tmp="$(mktemp -d)"
    # 1. Faust -> C++ (scalar, no -ftz) and XML for faust2sc
    ( cd "$src_dir" && faust -i -a "$ARCH" -xml $FAUST_OPTIONS "$base.dsp" -o "$tmp/$base.cpp" )
    mv "$src_dir/$base.dsp.xml" "$tmp/"
    # 2. sclang class
    ( cd "$tmp" && faust2sc --prefix="$PREFIX" "$base.dsp.xml" > "$tmp/$base.sc" 2>/dev/null )
    cls="$(grep -oE '^[A-Za-z0-9_]+ *: *(MultiOut)?UGen' "$tmp/$base.sc" | grep -oE '^[A-Za-z0-9_]+')"
    [ -n "$cls" ] || { echo "faust2sc produced no class for $dsp"; exit 1; }
    if [ ${#cls} -ge 32 ]; then echo "UGen name $cls is ${#cls} characters; scsynth rejects 32 or more. Shorten 'declare name'."; exit 1; fi
    # 3. C++ -> plugin
    flags="-std=c++14 $OPT_FLAGS -DNDEBUG -DNO_LIBSNDFILE -DSC_FAUST_PREFIX=\"$PREFIX\" $INCLUDE $EXTRA_CXXFLAGS"
    $CXX $flags $PLAT "-Dmydsp=$base" "$tmp/$base.cpp" -o "$src_dir/$cls.$EXT"
    [ $SUPERNOVA = 1 ] && $CXX $flags -DSUPERNOVA $PLAT "-Dmydsp=$base" "$tmp/$base.cpp" -o "$src_dir/${cls}_supernova.$EXT"
    cp "$tmp/$base.sc" "$src_dir/$cls.sc"
    rm -rf "$tmp"
    echo "Built $cls: $src_dir/$cls.$EXT and $cls.sc"
    if [ $INSTALL = 1 ]; then
        mkdir -p "$EXTDIR"
        cp "$src_dir/$cls.$EXT" "$src_dir/$cls.sc" "$EXTDIR/"
        [ $SUPERNOVA = 1 ] && cp "$src_dir/${cls}_supernova.$EXT" "$EXTDIR/"
        echo "  installed in $EXTDIR"
    fi
done
