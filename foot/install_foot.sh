#!/bin/bash

# Install dependencies
sudo pacman -S meson ninja wayland-protocols libxkbcommon pixman tllist

# Clone repo (latest commit only)
git clone --depth 1 https://codeberg.org/barsmonster/foot
cd foot

# Edit the fcft subproject to use the ligature-enabled fork
cat > subprojects/fcft.wrap << 'EOF'
[wrap-git]
url = https://codeberg.org/barsmonster/fcft
revision = master
depth = 1
EOF

# Build
meson setup build --buildtype=release --force-fallback-for=fcft
ninja -C build

# Install
sudo ninja -C build install

# Uninstall
# sudo ninja -C build uninstall

