A simple terminal shell for Windows written in MS MASM x64 assembly.

  
  

Todo:
* Nested execution (or input interpolation)
* Readline-like input processing
* Simple module/plugin system (so I can use [ShellServer](https://github.com/HenriquedoVal/new_shellserver) on it)

Builtins:
* cd
* exit
No `mkdir`, `echo`, etc. Encouraging the use of [Microsoft.CoreUtils](https://github.com/microsoft/coreutils)

  
  

Current input syntax BNF:
```
<input>           ::= <chunk> (<chain> <chunk> (<chain> <chunk> (...)*)*)*
<chunk>           ::= <any>+ <redirections>*
<chain>           ::= & | && | '||' | ';' | '|'
<redirections>    ::= <stdout>* <stderr>*
<stdout>          ::= (<stdout-write> | <stdout-append>) <any-non-whitespace>
<stderr>          ::= (<stderr-write> | <stderr-append>) <any-non-whitespace>
<stdout-write>    ::= '>' | 1>
<stdout-append>   ::= >> | 1>>
<stderr-write>    ::= 2>
<stderr-append>   ::= 2>>
```
