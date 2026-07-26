
(*
 * Copyright (C) 2007-2014 The laby team
 * You have permission to copy, modify, and redistribute under the
 * terms of the GPL-3.0. For full license terms, see gpl-3.0.txt.
 *)

let configure_windows_runtime () =
  if Sys.os_type = "Win32" then begin
    let executable =
      if Filename.is_relative Sys.executable_name then
        Filename.concat (Sys.getcwd ()) Sys.executable_name
      else
        Sys.executable_name
    in
    let root = Filename.dirname executable in
    let share = Filename.concat root "share" in
    let loaders =
      Filename.concat root
        (Filename.concat "lib"
           (Filename.concat "gdk-pixbuf-2.0" "loaders"))
    in
    let fonts =
      Filename.concat root
        (Filename.concat "etc" (Filename.concat "fonts" "fonts.conf"))
    in
    Unix.putenv "GDK_PIXBUF_MODULEDIR" loaders;
    Unix.putenv "GTK_DATA_PREFIX" root;
    Unix.putenv "GTK_EXE_PREFIX" root;
    Unix.putenv "XDG_DATA_DIRS" share;
    if Sys.file_exists fonts then Unix.putenv "FONTCONFIG_FILE" fonts;

    let cache =
      Filename.concat root
        (Filename.concat "lib"
           (Filename.concat "gdk-pixbuf-2.0" "loaders.cache"))
    in
    if Sys.file_exists cache then
      Unix.putenv "GDK_PIXBUF_MODULE_FILE" cache
  end

let () = configure_windows_runtime ()

let conf =
  Conf.void
    ~l:[
      "mod", Mod.conf#ut;
      "log", Log.conf#ut;
      "ui", Ui.conf#ut;
      "gfx", Gfx.conf#ut;
      "res", Res.conf#ut;
      "sound", Sound.conf#ut;
    ]
    (F.x "laby configuration" [])

let proceed _ =
  begin try
    Gfx.run_gtk ()
  with
  | Gfx.Error f ->
      Run.fatal (
	F.x "display failed: <error>" [
	  "error", f;
	]
      )
  end

let opts =
  [
    Opt.conf ~short:'l' ~long:"lang" Ui.conf_lang;
    Mod.opt;
    Opt.conf ~long:"mod-translation" Mod.conf_translation;
    Opt.conf ~short:'s' ~long:"sound" Sound.conf_enabled;
    Opt.conf ~long:"tile-size" Gfx.conf_tilesize;
    Opt.conf ~long:"source-style" Gfx.conf_source_style;
    Opt.conf ~long:"playback-rate" Gfx.conf_playback_rate;
    Opt.conf ~long:"cue-rate" Gfx.conf_cue_rate;
    Opt.conf_set ~short:'c' ~long:"conf" conf;
    Opt.conf_descr ~long:"conf-descr" conf;
    Opt.conf_dump ~long:"conf-dump" conf;
    Version.opt;
    Run.opt_debug;
  ]

let _ =
  Printexc.record_backtrace true;
  Run.init
    ~name:Config.project_name
    ~conf:(conf, ["conf"])
    ~services:[Ui.theme; Ui.texts]
    (`Opts (opts, proceed))
