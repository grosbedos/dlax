#!/bin/bash
# dlax : installe le bureau Slax sur une Debian 13 (trixie) netinstall pure.
#
# Usage : sudo ./install.sh [options] UTILISATEUR
#   --lang LOCALE        locale du système (défaut : fr_FR.UTF-8)
#   --keyboard L1[,L2]   dispositions clavier pour fbkeyboard (défaut : fr,us)
#   --no-autologin       ne pas ouvrir la session automatiquement sur tty1
#   --keep-build-deps    garder les paquets de compilation après la construction
#   --only ÉTAPES        n'exécuter que ces étapes (ex. --only 30,40)
#
# Le script est idempotent : on peut le relancer pour mettre à jour la configuration.
set -euo pipefail

DLAX=$(cd "$(dirname "$0")" && pwd)
LANG_LOCALE=fr_FR.UTF-8
KEYBOARD=fr,us
AUTOLOGIN=1
KEEP_BUILD_DEPS=0
ONLY=
TARGET_USER=

usage() { sed -n '2,12s/^# \{0,1\}//p' "$0"; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
   case "$1" in
      --lang) LANG_LOCALE=$2; shift 2 ;;
      --keyboard) KEYBOARD=$2; shift 2 ;;
      --no-autologin) AUTOLOGIN=0; shift ;;
      --keep-build-deps) KEEP_BUILD_DEPS=1; shift ;;
      --only) ONLY=$2; shift 2 ;;
      -h|--help) usage 0 ;;
      -*) echo "Option inconnue : $1" >&2; usage 1 ;;
      *) TARGET_USER=$1; shift ;;
   esac
done

[ -n "$TARGET_USER" ] || usage 1
[ "$(id -u)" = 0 ] || { echo "À lancer en root (sudo ./install.sh $TARGET_USER)." >&2; exit 1; }
. /etc/os-release
if [ "${VERSION_CODENAME:-}" != trixie ]; then
   echo "Attention : dlax vise Debian 13 (trixie), système détecté : ${PRETTY_NAME:-inconnu}." >&2
fi

export DEBIAN_FRONTEND=noninteractive
export DLAX LANG_LOCALE KEYBOARD AUTOLOGIN KEEP_BUILD_DEPS TARGET_USER

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
export -f log

for STEP in "$DLAX"/steps/[0-9][0-9]-*.sh; do
   NUM=$(basename "$STEP" | cut -c1-2)
   if [ -n "$ONLY" ] && ! printf ',%s,' "$ONLY" | grep -q ",$NUM,"; then
      continue
   fi
   log "Étape $(basename "$STEP")"
   bash -euo pipefail "$STEP"
done

log "Terminé. Redémarrez : la session Fluxbox de $TARGET_USER s'ouvrira sur tty1."
