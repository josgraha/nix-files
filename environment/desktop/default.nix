{ userConfig, theme, icon-theme }:
{ config, lib, pkgs, ... }:
let gtk2rc = pkgs.writeText "gtk2rc" ''
      gtk-icon-theme-name = "${icon-theme.name}"
      gtk-theme-name = "${theme.name}"

      binding "gtk-binding-menu" {
        bind "j" { "move-current" (next) }
        bind "k" { "move-current" (prev) }
        bind "h" { "move-current" (parent) }
        bind "l" { "move-current" (child) }
      }
      class "GtkMenuShell" binding "gtk-binding-menu"
    '';
in {
  environment.variables = {
    GDK_PIXBUF_MODULE_FILE = "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
    GTK_DATA_PREFIX = "${theme.package}";
    GTK_EXEC_PREFIX = "${theme.package}";
    GTK_PATH = "${theme.package}:${pkgs.gtk3}";
    GTK_THEME = "${theme.name}";
    QT_STYLE_OVERRIDE = "GTK+";
    GTK2_RC_FILES = "${gtk2rc}:${theme.package}/share/themes/${theme.name}/gtk-2.0/gtkrc:$GTK2_RC_FILES";
  };

  environment.systemPackages = with pkgs; [
    gtk-engine-murrine
    shared_mime_info
    theme.package
    icon-theme.package

    clipit
    dmenu
    chromium
    #dragon-drop
    #dropbox-cli
    #pavucontrol
    #pidgin
    rxvt_unicode
    scrot
    slock
    userConfig
    weechat
    xautolock
    xbindkeys
    xdg_utils
    xlibs.xev
    xlibs.xmodmap
    xlibs.xset
    #zathura
  ];

  security.setuidPrograms = [ "slock" ];
}
