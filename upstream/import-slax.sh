#!/bin/sh
# Regenerate src/, rootfs/ and skel/ from Slax's build tree (Tomas-M/linux-live).
#
# Usage: upstream/import-slax.sh [LINUX_LIVE_CHECKOUT]
#   Without an argument, clones github.com/Tomas-M/linux-live at the commit in
#   upstream/UPSTREAM_COMMIT into a temporary directory.
#
# Everything under src/, rootfs/ and skel/ is GENERATED: do not edit it by hand.
# dlax-specific changes live in upstream/overrides/ (copied last) and in the
# adapt() function below. Re-run this script and review `git diff` to resync.
set -eu

DLAX=$(cd "$(dirname "$0")/.." && pwd)
COMMIT=$(cat "$DLAX/upstream/UPSTREAM_COMMIT")

if [ $# -ge 1 ]; then
   LL=$(cd "$1" && pwd)
else
   TMP=$(mktemp -d)
   trap 'rm -rf "$TMP"' EXIT
   git clone --quiet https://github.com/Tomas-M/linux-live.git "$TMP/linux-live"
   git -C "$TMP/linux-live" checkout --quiet "$COMMIT"
   LL=$TMP/linux-live
fi

SLAX=$LL/Slax/debian13
DESK=$SLAX/modules/03-desktop
RC=$DESK/rootcopy
[ -d "$RC" ] || { echo "Not a linux-live checkout: $LL" >&2; exit 1; }
if [ -d "$LL/.git" ]; then
   echo "Importing from linux-live $(git -C "$LL" rev-parse HEAD)"
fi

rm -rf "$DLAX/src" "$DLAX/rootfs" "$DLAX/skel"
mkdir -p "$DLAX/src" "$DLAX/rootfs" "$DLAX/skel"

# --- C sources of the desktop helpers that do not depend on the live system ---
for F in fbkeyboard.c fbstartupnotify.c gtk-app-style.c icon-aliases cursor-aliases; do
   cp "$DESK/$F" "$DLAX/src/"
done

# --- System files: 03-desktop/rootcopy minus live-only / VM / guest pieces ---
# Paths are relative to rootcopy/. Directories exclude their whole subtree.
EXCLUDES='
root
home
etc/skel
usr/bin
usr/libexec
usr/lib
etc/systemd
etc/default
etc/locale.conf
etc/X11/slax-framebuffer.conf
etc/X11/xinit
etc/X11/xorg.conf.d/20-hyperv-primary.conf
etc/xdg/skippy-xd.rc
etc/gtk-2.0
etc/gtk-3.0
etc/gtk-4.0
etc/scite
usr/share/applications
usr/share/polkit-1
usr/share/file-manager
usr/local/share/applications/slax-ai.desktop
usr/local/share/applications/slax-installer.desktop
usr/local/share/applications/chromium.desktop
usr/local/share/applications/com.github.maoschanz.drawing.desktop
usr/local/share/applications/lxtask.desktop
usr/local/share/applications/org.gnome.Mines.desktop
usr/local/share/applications/org.gnome.Sudoku.desktop
usr/local/share/applications/org.remmina.Remmina.desktop
usr/local/share/applications/simple-scan.desktop
usr/local/share/applications/vlc.desktop
usr/local/share/applications/xfburn.desktop
'
EXCL_FILE=$(mktemp)
printf '%s\n' "$EXCLUDES" | sed '/^$/d; s|^|./|' > "$EXCL_FILE"
(cd "$RC" && tar -cf - --exclude-from="$EXCL_FILE" --anchored --no-wildcards .) |
   (cd "$DLAX/rootfs" && tar -xf -)
rm -f "$EXCL_FILE"

# Desktop helper scripts go to /usr/local/bin (admin-owned, never touched by dpkg).
mkdir -p "$DLAX/rootfs/usr/local/bin"
for F in fbappselect fblogout fbsetkb fbcommand fbprintscreen; do
   cp "$RC/usr/bin/$F" "$DLAX/rootfs/usr/local/bin/"
done

# Debian conffiles are not overwritten (that would make dpkg prompt on upgrades):
# their content moves to the per-user equivalents below.
# Default applications: /etc/xdg/mimeapps.list is not owned by any package.
mkdir -p "$DLAX/rootfs/etc/xdg"
cp "$RC/usr/share/applications/mimeapps.list" "$DLAX/rootfs/etc/xdg/mimeapps.list"

# --- User profile (was /root in Slax) ---
(cd "$RC/root" && tar -cf - .) | (cd "$DLAX/skel" && tar -xf -)
(cd "$RC/etc/skel" && tar -cf - .) | (cd "$DLAX/skel" && tar -xf -)
mkdir -p "$DLAX/skel/.config"
cp -a "$SLAX/rootcopy/root/.config/mc" "$DLAX/skel/.config/"
# GTK settings that Slax put in /etc conffiles.
{ cat "$RC/root/.gtkrc-2.0"; echo; cat "$RC/etc/gtk-2.0/gtkrc"; } > "$DLAX/skel/.gtkrc-2.0"
cp "$RC/etc/gtk-3.0/settings.ini" "$DLAX/skel/.config/gtk-3.0/settings.ini"
printf 'gtk-dialogs-use-header=true\ngtk-modules=slax-app-style\n' >> "$DLAX/skel/.config/gtk-3.0/settings.ini"
cp "$RC/etc/gtk-4.0/settings.ini" "$DLAX/skel/.config/gtk-4.0/settings.ini"
cp "$RC/etc/scite/SciTEGlobal.properties" "$DLAX/skel/.SciTEUser.properties"
# Slax's guest-only startup history is not useful.
rm -f "$DLAX/skel/.fluxbox/fbrun_history"

adapt()
{
   # Chromium is replaced by Firefox ESR.
   sed -i 's/chromium\.desktop/firefox-esr.desktop/g' "$DLAX/rootfs/etc/xdg/mimeapps.list"
   # shellcheck disable=SC2016  # literal $NAME in the sed pattern
   sed -i 's/\[ "$NAME" = chromium \]/[ "$NAME" = firefox-esr ]/; s/ || \[ "$NAME" = fbliveapp \]//' \
      "$DLAX/rootfs/usr/local/bin/fbcommand"
   # Fluxbox's native window cycling replaces skippy-xd (not in Debian).
   sed -i \
      -e 's|^Mod1 Tab :Exec skippy-xd.*|Mod1 Tab :NextWindow {groups} (workspace=[current])|' \
      -e 's|^Mod1 Shift Tab :Exec skippy-xd.*|Mod1 Shift Tab :PrevWindow {groups} (workspace=[current])|' \
      -e '/skippy-xd/d' \
      "$DLAX/skel/.fluxbox/keys"
   # Applications not shipped by dlax.
   sed -i '/^\[app\] (class=slax-ai)/,/^\[end\]/d; /^\[app\] (class=PartitionManager)/,/^\[end\]/d' \
      "$DLAX/skel/.fluxbox/apps"
   sed -i 's/chromium\.desktop/firefox-esr.desktop/g' "$DLAX/rootfs/etc/xlunch/focus.ini"
   # Removable drives: udisks2 + pcmanfm replace slax-automount (live-only).
   sed -i 's/^mount_removable=0/mount_removable=1/' "$DLAX/skel/.config/pcmanfm/default/pcmanfm.conf"
   # Let xdg-user-dirs create folders in the user's language (Bureau, Téléchargements...).
   rm -f "$DLAX/skel/.config/user-dirs.dirs"
}
adapt

# dlax-owned files replace their upstream counterparts.
(cd "$DLAX/upstream/overrides" && tar -cf - .) | (cd "$DLAX" && tar -xf -)

# Files checked out from Windows/OneDrive lose their mode: make it explicit.
chmod 755 "$DLAX"/rootfs/usr/local/bin/* "$DLAX/skel/.xinitrc" "$DLAX/skel/.fluxbox/startup"

if grep -rIl 'chromium\|fbliveapp\|/run/initramfs\|slax-ai\|skippy' "$DLAX/rootfs" "$DLAX/skel" \
      --exclude-dir=icons --exclude='*.css' --exclude=picom.conf --exclude=xfce4-panel.xml; then
   echo "WARNING: the files above still reference Slax-only components." >&2
fi
echo "Done. Review with: git -C \"$DLAX\" status && git -C \"$DLAX\" diff"
