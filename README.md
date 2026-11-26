# dlax : le bureau Slax sur une Debian pure

dlax reprend le bureau de [Slax](https://www.slax.org) : Fluxbox, le lanceur
xlunch, le panneau, les applets réseau, son, clavier et batterie, ainsi que le thème.
Il l'installe sur une **Debian 13 « trixie » netinstall**, sans modules `.sb`, sans AUFS et
sans démarrage live. Le système reste une Debian normale qui se met à jour avec
`apt full-upgrade`. dlax ne modifie aucun paquet et ne pose aucun `apt-mark hold`.

La source est le dépôt de construction de Slax,
[Tomas-M/linux-live](https://github.com/Tomas-M/linux-live), dossier
`Slax/debian13/`, au commit indiqué dans `upstream/UPSTREAM_COMMIT`.

## Installation

1. Installez Debian 13 depuis l'ISO netinstall. Au choix des logiciels,
   **décochez tout l'environnement de bureau**. Ne gardez que « utilitaires usuels
   du système » et, si vous le voulez, « serveur SSH ».
2. Connectez-vous en root, puis lancez :

   ```sh
   apt install git
   git clone <ce dépôt> /opt/dlax
   /opt/dlax/install.sh moi          # « moi » = votre compte utilisateur
   reboot
   ```

Au redémarrage, la session Fluxbox s'ouvre automatiquement sur tty1.

Options : `--lang fr_FR.UTF-8`, `--keyboard fr,us`, `--no-autologin`,
`--keep-build-deps`, `--only 30,40`. Les détails sont dans `./install.sh --help`.
Le script est idempotent : on peut le relancer sans risque.

## Ce qui est installé

| Élément | Provenance |
|---|---|
| Fluxbox + style « Slax », menus, raccourcis | paquet Debian `fluxbox` + `skel/.fluxbox/` |
| Panneau (docklike, pager, horloge, zone de notification) | `xfce4-panel`, `xfce4-docklike-plugin` |
| Lanceur plein écran (Ctrl+Échap, bouton du panneau) | **xlunch 5.10.6**, compilé depuis Tomas-M/xlunch |
| Changement de langue du clavier (applet, touche Super) | **fbkeyboard**, compilé depuis les sources Slax |
| Réseau (applet) | `connman` + `connman-gtk` |
| Volume, batterie | `volumeicon-alsa`, `cbatticon` |
| Composition (fondus, coins arrondis) | `picom` |
| Bureau à icônes, fichiers, automontage USB | `pcmanfm` + `udisks2` + `gvfs` |
| Navigateur | `firefox-esr` (+ traduction) |
| Divers | `xterm`, `scite`, `galculator`, `xarchiver`, `feh`, `lxtask`, `scrot` |

Les binaires compilés et les scripts `fb*` (fbappselect, fblogout, fbcommand,
fbprintscreen, fbsetkb) sont installés dans `/usr/local`, où dpkg n'intervient jamais.
Les fichiers que Slax ajoute sous `/usr/share` n'appartiennent pour la plupart à aucun paquet.
Une trentaine remplacent pourtant ceux d'un paquet : le thème GTK2 MurrinaChrome, des icônes de
dossiers Adwaita et les boutons de fenêtre. Ceux-là sont **détournés avec `dpkg-divert`**.
Le fichier Debian est renommé en `*.debian`, et les mises à jour l'écrivent sous ce nom
sans toucher à la version Slax (`dpkg-divert --list` les affiche).
Les réglages que Slax plaçait dans des fichiers de configuration Debian (`/etc/gtk-*/`,
`/etc/scite/`) sont déplacés dans le profil utilisateur, pour que dpkg ne pose jamais
de question pendant une mise à jour.

Un hook apt (`/etc/apt/apt.conf.d/99dlax-icons`) relance `dlax-refresh-icons`, qui
réapplique les ajouts de Slax à `index.theme` d'Adwaita quand une mise à jour les efface.

## Ce qui est volontairement laissé de côté

- **Le système live** : `slax`, `sb`, `savechanges`, la persistance, le bootsplash,
  `slax-status` (gestion des changements en RAM), les comptes `guest` et `root:toor`.
- **Les 11 paquets Debian patchés** par Slax (fluxbox, gtk2/3, picom, xfce4-panel,
  docklike, pcmanfm, libfm, volumeicon, connman-gtk, imlib2). On utilise les versions
  d'origine. Ce qui diffère :
  - pas d'aperçus animés des fenêtres dans la barre des tâches ;
  - pas de liseré autour des fenêtres ;
  - quelques détails de focus et de dialogues GTK.
- **skippy-xd** (Alt+Tab avec aperçus) : il est remplacé par l'Alt+Tab de Fluxbox.
- **fbinstall** (installation d'une application au premier clic) : il lançait apt en
  root. Utilisez `sudo apt install`.
- **Les outils pour machines virtuelles**, partition-manager et Chromium.

## Structure du dépôt

```
install.sh              point d'entrée
steps/NN-*.sh           étapes : paquets, compilation, système, utilisateur, réseau/automontage
packages.list           paquets Debian
bin/                    scripts propres à dlax (dlax-refresh-icons)
upstream/import-slax.sh régénère src/, rootfs/, skel/ depuis linux-live
upstream/overrides/     fichiers réécrits pour dlax (startup Fluxbox, menu, picom.conf)
src/ rootfs/ skel/      GÉNÉRÉS par import-slax.sh : ne pas modifier à la main
```

### Resynchroniser avec Slax

```sh
echo <nouveau-commit> > upstream/UPSTREAM_COMMIT
sh upstream/import-slax.sh          # ou : sh upstream/import-slax.sh /chemin/vers/linux-live
git diff                            # relire ce qui a changé côté Slax
```

Pour changer un fichier Slax, ajoutez une règle `sed` dans `adapt()`
(`upstream/import-slax.sh`), ou placez sa version complète dans `upstream/overrides/`.

## Licence

GPL, comme Slax et Linux Live Kit (voir `LICENSE` et `GNU_GPL`). Les crédits de
Slax et des icônes reviennent à Tomas M. et à leurs auteurs
(voir `rootfs/usr/share/doc/slax-icons/`).
