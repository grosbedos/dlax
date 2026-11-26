# Réseau géré par ConnMan (applet connman-gtk, comme Slax) et automontage des
# disques amovibles par udisks2 + pcmanfm (remplace slax-automount, propre au live).

# --- Automontage ---
# Les membres de plugdev peuvent monter les disques amovibles sans mot de passe.
cat > /etc/polkit-1/rules.d/50-dlax-udisks.rules <<'EOF'
// dlax : montage des disques amovibles par les utilisateurs du groupe plugdev.
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
        action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
        action.id == "org.freedesktop.udisks2.eject-media" ||
        action.id == "org.freedesktop.udisks2.power-off-drive") &&
       subject.isInGroup("plugdev") && subject.local && subject.active) {
      return polkit.Result.YES;
   }
});
EOF
chmod 644 /etc/polkit-1/rules.d/50-dlax-udisks.rules

# --- Réseau ---
# ConnMan remplace ifupdown pour les interfaces physiques. On garde la boucle locale.
systemctl enable connman.service
if [ -f /etc/network/interfaces ] && grep -Eq '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+[^l]' /etc/network/interfaces; then
   cp -n /etc/network/interfaces /etc/network/interfaces.dlax-bak
   cat > /etc/network/interfaces <<'EOF'
# dlax : les interfaces réseau sont gérées par ConnMan (applet de la barre).
# Configuration d'origine sauvegardée dans /etc/network/interfaces.dlax-bak
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
EOF
   echo "ifupdown désactivé pour les cartes réseau ; ConnMan prendra le relais au redémarrage." >&2
   if [ -n "${SSH_CONNECTION:-}" ]; then
      echo "ATTENTION : session SSH détectée, la connexion peut changer d'adresse au redémarrage." >&2
   fi
fi
