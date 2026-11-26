# Fichiers système du bureau Slax (thème, icônes, xlunch, picom...) et réglages globaux.

# Copie de rootfs/. Quelques fichiers remplacent ceux d'un paquet Debian (thème
# GTK2 MurrinaChrome, icônes de dossiers, boutons de fenêtre...) : ils sont
# détournés avec dpkg-divert, la méthode Debian prévue pour ça. Le fichier du
# paquet est renommé en *.debian et les mises à jour l'écrivent sous ce nom,
# sans jamais écraser la version Slax ni poser de question.
(cd "$DLAX/rootfs" && find . -type f -printf '/%P\n') |
   xargs -d '\n' dpkg -S 2>/dev/null | grep -v '^diversion ' | sed 's/^.*: //' | sort -u |
   while read -r F; do
      if [ "$(dpkg-divert --listpackage "$F")" != LOCAL ]; then
         dpkg-divert --local --rename --divert "$F.debian" --add "$F"
      fi
   done || true
(cd "$DLAX/rootfs" && tar -cf - --owner=0 --group=0 --mode='u=rwX,go=rX' .) |
   tar -xf - -C / --no-overwrite-dir
chmod 755 /usr/local/bin/fb*

# Script de maintenance des icônes, relancé après chaque opération dpkg (voir plus bas).
install -D -m 755 "$DLAX/bin/dlax-refresh-icons" /usr/local/sbin/dlax-refresh-icons
install -D -m 644 "$DLAX/src/icon-aliases" /usr/local/share/dlax/icon-aliases
install -D -m 644 "$DLAX/src/cursor-aliases" /usr/local/share/dlax/cursor-aliases
cat > /etc/apt/apt.conf.d/99dlax-icons <<'EOF'
// dlax : réapplique les réglages d'icônes Slax si une mise à jour d'Adwaita les a effacés.
DPkg::Post-Invoke { "if [ -x /usr/local/sbin/dlax-refresh-icons ]; then /usr/local/sbin/dlax-refresh-icons --quiet || true; fi"; };
EOF
/usr/local/sbin/dlax-refresh-icons --force

# Thème de curseurs Slax par défaut (aussi pour les applications X sans réglage GTK).
update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme \
   /usr/share/icons/Windows-Modern-Light/cursor.theme 100
update-alternatives --set x-cursor-theme /usr/share/icons/Windows-Modern-Light/cursor.theme

# Polices : garder les préférences latines, Micro Hei ne sert que pour le CJK.
rm -f /etc/fonts/conf.d/65-wqy-microhei.conf
fc-cache -f >/dev/null

glib-compile-schemas /usr/share/glib-2.0/schemas
update-desktop-database /usr/local/share/applications
update-alternatives --set x-terminal-emulator /usr/bin/xterm

# Langue du système.
if ! grep -q "^${LANG_LOCALE} " /etc/locale.gen; then
   sed -i "s/^# *\(${LANG_LOCALE} \)/\1/" /etc/locale.gen
fi
grep -q "^${LANG_LOCALE} " /etc/locale.gen || echo "${LANG_LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG="$LANG_LOCALE"

# Clavier de la console et disposition X par défaut (la première de --keyboard).
FIRST_LAYOUT=${KEYBOARD%%,*}
sed -i "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$FIRST_LAYOUT\"/" /etc/default/keyboard
setupcon --save-only 2>/dev/null || true
