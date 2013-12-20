%{ open Ast %}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA LSUBS RSUBS
%token PLUS MINUS TIMES DIVIDE ASSIGN
%token EQ NEQ LT LEQ GT GEQ
%token RETURN IF ELSE FOR WHILE INT CHAR STRUCT VOID
%token AMPERSAND INDIRECTION DOT
%token LAND LOR
%token <string> CONSTCHAR
%token <string> STRING
%token <string> ID
%token <int> LITERAL
%token NULL
%token EOF

%nonassoc NOELSE
%nonassoc ELSE
%right ASSIGN
%left LOR
%left LAND
%left EQ NEQ
%left LT GT LEQ GEQ
%left PLUS MINUS
%left TIMES DIVIDE
%left INDIRECTION DOT LPAREN RPAREN LSUBS RSUBS

%start program
%type <Ast.program> program

%%

program:
        /* nothing */ { {gdecls=[];sdecls=[];fdecls=[] } }
 | program sdecl { {gdecls= $1.gdecls; sdecls=$2::$1.sdecls; fdecls= $1.fdecls} }
 | program vdecl { {gdecls= $2::$1.gdecls; sdecls=$1.sdecls; fdecls=$1.fdecls} }
 | program fdecl { {gdecls= $1.gdecls; sdecls=$1.sdecls; fdecls=$2::$1.fdecls} }


fdecl:
   retval formals_opt RPAREN LBRACE vdecl_list stmt_list RBRACE
     { { fname = snd $1;
         formals = $2; 
         locals = List.rev $5;
         body = List.rev $6;
         ret = fst $1
         } }

retval:
        INT ID LPAREN { [Int], $2  }
        |CHAR ID LPAREN { [Char], $2  }
        |VOID ID LPAREN { [Void], $2  }

sdecl:
        STRUCT ID LBRACE vdecl_list RBRACE SEMI 
        { {
          sname = $2;
          smembers = $4;
           }
        }

formals_opt:
    /* nothing */ { [] }
  | formal_list   { List.rev $1 }

formal_list:
    tdecl                   { [$1] }
  | formal_list COMMA tdecl {
                  (match List.hd $3.vtype with
                  Arr(s) -> (match s with 
                    Id(id) -> raise( Failure("Array declaration: "^
                      "variable not allowed in" ^
                      "funciton argument"))
                    |_ -> $3)
                  | _ -> $3) :: $1

    
    }

vdecl_list:
    /* nothing */    { [] }
  | vdecl_list vdecl { $2 :: $1 }

vdecl:
   | tdecl SEMI { match List.hd $1.vtype with
                  Arr(s) -> (match s with
                    Noexpr -> raise( Failure("Array declaration: Size not specified"))
                    |_ -> $1)
                  | _ -> $1
                }

tdecl:
       INT rdecl      {
                        {
                        vname = $2.vname;
                        vtype = $2.vtype @ [Int]
                        }
                       }
     | CHAR rdecl      { 
                        {
                        vname = $2.vname;
                        vtype = $2.vtype @ [Char]
                        }
                       }
     | STRUCT ID rdecl {
                      { vname = $3.vname; 
                        vtype = $3.vtype @ [Struct($2)]
                      }
                       }

rdecl: 
        ID           { 
                      { vname = $1;
                        vtype = []
                      }
                     }
        | arrdecl       { $1 }
        | TIMES rdecl   { {
                        vname = $2.vname;
                        vtype = $2.vtype @ [Ptr];
                        } }

arrdecl:
        ID LSUBS LITERAL RSUBS { {
          vname = $1;
          vtype = [Arr(Literal($3))]
           } }
        | ID LSUBS RSUBS { {
          vname = $1;
          vtype = [Arr(Noexpr)]
           } }
        | ID LSUBS ID RSUBS { {
          vname = $1;
          vtype = [Arr(Id($3))]
           } }

stmt_list:
    /* nothing */  { [] }
  | stmt_list stmt { $2 :: $1 }

stmt:
    expr SEMI { Expr($1) }
  | RETURN expr SEMI { Return($2) }
  | RETURN SEMI { Return(Noexpr) }
  | LBRACE stmt_list RBRACE { Block(List.rev $2) }
  | IF LPAREN expr RPAREN stmt %prec NOELSE { If($3, $5, Block([])) }
  | IF LPAREN expr RPAREN stmt ELSE stmt    { If($3, $5, $7) }
  | FOR LPAREN expr_opt SEMI expr_opt SEMI expr_opt RPAREN stmt
     { For($3, $5, $7, $9) }
  | WHILE LPAREN expr RPAREN stmt { While($3, $5) }

expr_opt:
    /* nothing */ { Noexpr }
  | expr          { $1 }

expr:
    LITERAL          { Literal($1) }
  | NULL             { Null }
  | MINUS LITERAL    { Literal(-$2) }
  | PLUS LITERAL     { Literal($2) }
  | AMPERSAND lvalue { Addrof($2)  }
  | MINUS lvalue     { Negof($2)  }
  | PLUS lvalue      { $2 }
  | CONSTCHAR        { ConstCh($1) }
  | STRING           { String($1) }
  | expr PLUS   expr { Binop($1, Add,   $3) }
  | expr MINUS  expr { Binop($1, Sub,   $3) }
  | expr TIMES  expr { Binop($1, Mult,  $3) }
  | expr DIVIDE expr { Binop($1, Div,   $3) }
  | expr EQ     expr { Binop($1, Equal, $3) }
  | expr NEQ    expr { Binop($1, Neq,   $3) }
  | expr LT     expr { Binop($1, Less,  $3) }
  | expr LEQ    expr { Binop($1, Leq,   $3) }
  | expr GT     expr { Binop($1, Greater,  $3) }
  | expr GEQ    expr { Binop($1, Geq,   $3) }
  | expr LOR    expr { Binop($1, Lor,   $3) }
  | expr LAND   expr { Binop($1, Land,   $3) }
  | expr ASSIGN expr   { Assign($1, $3) }
  | ID LPAREN actuals_opt RPAREN { Call($1, $3) }
  | expr DOT var { MultiId($1,Dot,$3) }
  | expr INDIRECTION var { MultiId($1,Ind,$3) }
  | lvalue           { $1 }

lvalue:
        ptr   {$1}
        |var  {$1}
        |LPAREN expr RPAREN {$2}

ptr:
        TIMES expr {Pointer($2)}

var:
        ID      { Id($1) }
        | arr   { Array( fst $1, snd $1) }

arr:
        ID LSUBS expr RSUBS { Id($1),$3 }

actuals_opt:
    /* nothing */ { [] }
  | actuals_list  { List.rev $1 }

actuals_list:
    expr                    { [$1] }
  | actuals_list COMMA expr { $3 :: $1 }
