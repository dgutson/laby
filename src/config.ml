(*
 * Copyright (C) 2007-2014 The laby team
 * You have permission to copy, modify, and redistribute under the
 * terms of the GPL-3.0. For full license terms, see gpl-3.0.txt.
 *)

let project_name = "laby"

let version_string = "0.7.0"
let version_base = "unknown"
let version_current = "unknown"
let version_status = "dune build"

let build_system = Sys.os_type
let build_arch = Printf.sprintf "%d-bit" Sys.word_size
let build_ocaml = Sys.ocaml_version
let build_lablgtk = "3.x"
let build_lablgtk_sourceview = "3.x"
