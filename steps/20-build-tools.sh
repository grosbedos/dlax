# Compile les outils Slax absents de Debian : xlunch (lanceur), fbkeyboard
# (changement de langue), fbstartupnotify (curseur d'attente) et le module GTK
# de style. Binaires dans /usr/local : dpkg n'y touche jamais.

XLUNCH_VERSION=5.10.6
BUILD_DEPS=(build-essential pkg-config wget ca-certificates
   libimlib2-dev libx11-dev libgtk-3-dev libgtk2.0-dev libstartup-notification0-dev
   libxcursor-dev libxfixes-dev libxi-dev libfontconfig-dev libxkbcommon-dev)

# Ne retirer ensuite que les paquets que cette étape a elle-même ajoutés.
mapfile -t NEW_DEPS < <(for P in "${BUILD_DEPS[@]}"; do
   dpkg-query -W -f='${db:Status-Status}' "$P" 2>/dev/null | grep -qx installed || echo "$P"
done)
apt-get install --yes --no-install-recommends "${BUILD_DEPS[@]}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SRC=$DLAX/src
BIN=/usr/local/bin
CFLAGS="-Os -s"
# Seul dossier de modules que GTK 3 parcourt par défaut ; aucun paquet n'y installe ce fichier.
GTK_MODULES=/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || gcc -print-multiarch)/gtk-3.0/modules

# shellcheck disable=SC2046,SC2086  # pkg-config output must be word-split
{
cc $CFLAGS -o "$BIN/fbstartupnotify" "$SRC/fbstartupnotify.c" \
   $(pkg-config --cflags --libs gtk+-2.0 gio-unix-2.0 libstartup-notification-1.0 xcursor x11 xfixes)
cc $CFLAGS -o "$BIN/fbkeyboard" "$SRC/fbkeyboard.c" \
   $(pkg-config --cflags --libs gtk+-3.0 x11 xi fontconfig xkbcommon)
mkdir -p "$GTK_MODULES"
cc $CFLAGS -shared -fPIC -o "$GTK_MODULES/libslax-app-style.so" \
   "$SRC/gtk-app-style.c" $(pkg-config --cflags --libs gtk+-3.0)
}

# xlunch : même version que Slax, nécessaire pour le mode « focus ».
wget -q -O "$WORK/xlunch.tar.gz" "https://github.com/Tomas-M/xlunch/archive/v$XLUNCH_VERSION.tar.gz"
tar -xf "$WORK/xlunch.tar.gz" -C "$WORK"
make -C "$WORK/xlunch-$XLUNCH_VERSION" xlunch
install -m 755 "$WORK/xlunch-$XLUNCH_VERSION/xlunch" "$BIN/xlunch"
install -m 755 "$WORK/xlunch-$XLUNCH_VERSION/extra/gentriesquick" "$BIN/xlunch_genquick"
install -D -m 644 "$WORK/xlunch-$XLUNCH_VERSION/extra/ghost.png" /usr/share/icons/hicolor/48x48/apps/xlunch_ghost.png
install -D -m 644 "$WORK/xlunch-$XLUNCH_VERSION/docs/logo.png" /usr/share/icons/hicolor/48x48/apps/xlunch.png
mkdir -p /usr/share/xlunch
rm -rf /usr/share/xlunch/focus-icons
cp -r "$WORK/xlunch-$XLUNCH_VERSION/extra/focus-icons" /usr/share/xlunch/
"$BIN/xlunch" --check-ui-config "$DLAX/rootfs/etc/xlunch/focus.ini"

# Les binaires compilés ne sont pas des paquets : marquer leurs bibliothèques
# « installées manuellement » pour qu'apt autoremove ne les retire jamais.
mapfile -t RUNTIME_LIBS < <(
   ldd "$BIN/fbstartupnotify" "$BIN/fbkeyboard" "$BIN/xlunch" "$GTK_MODULES/libslax-app-style.so" |
   awk '$2 == "=>" && $3 ~ /^\// { print $3 }' | sort -u |
   while read -r LIB; do dpkg -S "$(readlink -f "$LIB")" 2>/dev/null || dpkg -S "$LIB" 2>/dev/null; done |
   cut -d: -f1 | sort -u)
apt-mark manual "${RUNTIME_LIBS[@]}" >/dev/null

if [ "$KEEP_BUILD_DEPS" = 0 ] && [ ${#NEW_DEPS[@]} -gt 0 ]; then
   # Sans SuggestsImportant=false, apt garderait gcc/perl car « suggérés » par apt et tar.
   apt-get purge --yes --auto-remove -o APT::AutoRemove::SuggestsImportant=false "${NEW_DEPS[@]}"
fi
