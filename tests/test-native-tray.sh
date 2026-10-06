#!/usr/bin/env bash
set -euo pipefail
test_source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_build_dir="$(mktemp -d /tmp/aurora-tray-test.XXXXXX)"
trap 'rm -rf -- "$test_build_dir"' EXIT
mkdir -p "$test_build_dir/config"
g++ -fPIC "$test_source_dir/native-tray.cpp" -o "$test_build_dir/test" \
    $(pkg-config --cflags --libs Qt6Widgets Qt6Quick Qt6Test) \
    -I/usr/include/Plasma -I/usr/include/PlasmaQuick \
    -I/usr/include/KF6/KConfig -I/usr/include/KF6/KCoreAddons \
    -I/usr/include/KF6/KPackage -I/usr/include/KF6/KConfigCore \
    -lPlasma -lPlasmaQuick -lKF6Package -lKF6ConfigCore -lKF6CoreAddons
XDG_CONFIG_HOME="$test_build_dir/config" QT_QPA_PLATFORM=offscreen \
    QT_QUICK_BACKEND=software "$test_build_dir/test"
