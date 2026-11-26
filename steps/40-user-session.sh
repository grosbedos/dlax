# Compte utilisateur, profil du bureau Slax et ouverture automatique de la session.

if ! id "$TARGET_USER" >/dev/null 2>&1; then
   adduser --disabled-password --gecos '' "$TARGET_USER"
   echo "Compte $TARGET_USER créé : définissez son mot de passe avec « passwd $TARGET_USER »." >&2
fi
for GROUP in sudo audio video netdev plugdev cdrom; do
   if getent group "$GROUP" >/dev/null; then
      usermod -a -G "$GROUP" "$TARGET_USER"
   fi
done

HOME_DIR=$(getent passwd "$TARGET_USER" | cut -d: -f6)
GROUP_ID=$(id -g "$TARGET_USER")

# Profil par défaut des futurs comptes, puis profil de l'utilisateur ciblé.
# Les fichiers existants de l'utilisateur sont sauvegardés en *.dlax-bak une seule fois.
install_profile()
{
   DEST=$1
   (cd "$DLAX/skel" && find . -type f -printf '%P\n') | while read -r F; do
      if [ -f "$DEST/$F" ] && [ ! -f "$DEST/$F.dlax-bak" ] && ! cmp -s "$DLAX/skel/$F" "$DEST/$F"; then
         cp -p "$DEST/$F" "$DEST/$F.dlax-bak"
      fi
      install -D -m 644 "$DLAX/skel/$F" "$DEST/$F"
   done
   chmod 755 "$DEST/.xinitrc" "$DEST/.fluxbox/startup"
}
install_profile /etc/skel
install_profile "$HOME_DIR"

# Dispositions clavier de fbkeyboard : la 1re active, la 2e en alternative (Super).
mkdir -p "$HOME_DIR/.config/slax"
printf '%s\n' "${KEYBOARD//,/$'\n'}" | head -2 > "$HOME_DIR/.config/slax/keyboard"

# Lancer X automatiquement à la connexion sur tty1.
PROFILE=$HOME_DIR/.bash_profile
if [ ! -f "$PROFILE" ]; then
   printf '# shellcheck shell=bash\n[ -f ~/.profile ] && . ~/.profile\n' > "$PROFILE"
fi
if ! grep -q 'dlax-startx' "$PROFILE"; then
   cat >> "$PROFILE" <<'EOF'

# dlax-startx : bureau Slax sur tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = /dev/tty1 ]; then
   exec startx -- -keeptty >"$HOME/.xsession-errors" 2>&1
fi
EOF
fi

for ENTRY in $(cd "$DLAX/skel" && ls -A) .bash_profile; do
   chown -R "$TARGET_USER:$GROUP_ID" "$HOME_DIR/$ENTRY"
done
sudo -u "$TARGET_USER" LANG="$LANG_LOCALE" xdg-user-dirs-update --force 2>/dev/null || true

# Ouverture automatique de la session (getty), sans gestionnaire de connexion.
DROPIN=/etc/systemd/system/getty@tty1.service.d/dlax-autologin.conf
if [ "$AUTOLOGIN" = 1 ]; then
   mkdir -p "$(dirname "$DROPIN")"
   cat > "$DROPIN" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $TARGET_USER --noclear %I \$TERM
EOF
else
   rm -f "$DROPIN"
fi
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi
