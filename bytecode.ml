open Ast

type atom =
    Lit of int    (*  literal *)
  | Cchar of char
  | Sstr of string * string (* Sstr(name, label) *)
  | Lvar of int * int(* Lvar(offset,size) *)
  | Gvar of string * int (* Global var (name,size) *)
  | Pntr of atom * int (* Pntr(addr,size) *)
  | Addr of atom
  | Neg  of atom
  | Debug of string

type bstmt =
    Atom of atom
  | VarArr of atom * atom
  | Rval of atom
  | BinEval of atom * atom * Ast.op * atom (*Binary evaluation *)
  | BinRes of cpitypes list
  | Assgmt of atom * atom
  | Str of atom * int (*Store (Lvar,value) *)
  | Ldr of atom * int (*Load (Lvar,value) *)
  | Mov of atom * atom
  | Fcall of string * atom list * atom 
  | Branch of string
  | Predicate of atom * bool * string (* (var_to_check, jump_on_what? , label)*)
  | Label of string

type prog = 
  Fstart of string * atom list * bstmt list * int (*start of a function*)
  | Global of atom list
