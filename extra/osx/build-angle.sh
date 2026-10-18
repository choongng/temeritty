#!/bin/sh
# Build ANGLE's libEGL and libGLESv2, Metal only, into OUT_DIR; several arches are lipo'd.
#
# Usage: build-angle.sh OUT_DIR [arm64|x64 ...]
#
# The checkout is kept in ANGLE_CACHE (default ~/.cache/temeritty), safe from `cargo clean`.

set -eu

# Head of chromium/7999.
ANGLE_COMMIT=25e721127e1c6c4c6fa0182b5c234b2c88971175
ANGLE_URL=https://chromium.googlesource.com/angle/angle
DEPOT_TOOLS_URL=https://chromium.googlesource.com/chromium/tools/depot_tools.git

out=${1:?usage: build-angle.sh OUT_DIR [arm64|x64 ...]}
shift
[ $# -gt 0 ] || set -- "$(uname -m | sed 's/x86_64/x64/')"
arches=$*

if ! xcrun metal --version >/dev/null 2>&1; then
    echo "ANGLE's Metal shaders need Xcode's Metal toolchain:" >&2
    echo "    xcodebuild -downloadComponent MetalToolchain" >&2
    exit 1
fi

cache=${ANGLE_CACHE:-$HOME/.cache/temeritty}
src=$cache/angle
mkdir -p "$cache" "$out"
out=$(cd "$out" && pwd)

if [ ! -d "$cache/depot_tools" ]; then
    git clone --depth 1 "$DEPOT_TOOLS_URL" "$cache/depot_tools"
fi
export PATH="$cache/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=0
# Bootstrap depot_tools; a no-op once done.
"$cache/depot_tools/ensure_bootstrap"

# Check out and sync the pinned commit, once.
if [ ! -d "$src" ]; then
    git clone "$ANGLE_URL" "$src"
fi
cd "$src"
if [ "$(cat .temeritty-synced 2>/dev/null)" != "$ANGLE_COMMIT" ]; then
    git cat-file -e "$ANGLE_COMMIT^{commit}" 2>/dev/null || git fetch origin "$ANGLE_COMMIT"
    git checkout -q "$ANGLE_COMMIT"
    [ -f ../.gclient ] || [ -f .gclient ] || python3 scripts/bootstrap.py
    gclient sync -D --no-history
    echo "$ANGLE_COMMIT" > .temeritty-synced
fi

libs=""
for arch in $arches; do
    build=out/temeritty-$arch
    gn gen "$build" --args="
        target_os=\"mac\"
        target_cpu=\"$arch\"
        is_debug=false
        is_component_build=false
        symbol_level=0
        angle_build_tests=false
        angle_enable_metal=true
        angle_enable_gl=false
        angle_enable_vulkan=false
        angle_enable_swiftshader=false
        angle_enable_null=false
        angle_enable_wgpu=false
    "
    autoninja -C "$build" libEGL libGLESv2
    libs="$libs $src/$build"
done

for lib in libEGL.dylib libGLESv2.dylib; do
    set --
    for dir in $libs; do
        set -- "$@" "$dir/$lib"
    done
    if [ $# -eq 1 ]; then
        cp -f "$1" "$out/$lib"
    else
        lipo -create "$@" -output "$out/$lib"
    fi
done

# Licences: ANGLE's, then each linked third_party dir's (README.chromium's file, else LICENSE).
# libc++ is built from //buildtools/third_party, but its source is in third_party.
build=out/temeritty-${arches%% *}
notices=$out/THIRD-PARTY-NOTICES.txt
licence_dirs() {
    for target in //:libEGL //:libGLESv2; do
        gn desc "$build" "$target" deps --all
    done | sed -n 's|^//\(buildtools/\)\{0,1\}\(third_party/[^:(]*\).*|\2|p' | sort -u |
        while read -r dir; do
            while [ ! -f "$dir/README.chromium" ] && [ "${dir%/*}" != third_party ]; do
                dir=${dir%/*}
            done
            echo "$dir"
        done | sort -u
}
{
    printf 'ANGLE %s (%s)\n\n' "$ANGLE_COMMIT" "$ANGLE_URL"
    cat LICENSE
    licence_dirs | while read -r dir; do
        if [ -f "$dir/README.chromium" ]; then
            name=$(sed -n 's/^Name: *//p' "$dir/README.chromium" | head -n 1)
            files=$(sed -n 's/^License File: *//p' "$dir/README.chromium" | head -n 1 | tr ',' ' ')
        else
            name=${dir#third_party/}
            files=$(cd "$dir" && ls LICENSE* src/LICENSE* 2>/dev/null | head -n 1)
        fi
        for file in $files; do
            case $file in
                //*) path=${file#//} ;;
                *) path=$dir/$file ;;
            esac
            [ -f "$path" ] || continue
            printf '\n\n==== %s (%s) ====\n\n' "${name:-$dir}" "$dir"
            cat "$path"
        done
    done
} > "$notices"

echo "ANGLE $ANGLE_COMMIT ($arches) in $out"
