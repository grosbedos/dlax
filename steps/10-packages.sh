# Installe les paquets Debian du bureau (aucun paquet modifié, aucun apt-mark hold).

mapfile -t PACKAGES < <(sed 's/#.*//' "$DLAX/packages.list" | tr -s ' \t' '\n' | sed '/^$/d')

apt-get update

# Traduction de Firefox selon la langue choisie (fr_FR.UTF-8 -> fr).
L10N=firefox-esr-l10n-${LANG_LOCALE%%_*}
if apt-cache show "$L10N" >/dev/null 2>&1; then
   PACKAGES+=("$L10N")
fi

apt-get install --yes --no-install-recommends "${PACKAGES[@]}"
