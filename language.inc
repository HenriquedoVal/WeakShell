ifndef _language_inc_
_language_inc_ = 1


KIND_GENERAL equ 0
KIND_SQUOTE  equ 1
KIND_DQUOTE  equ 2
KIND_CHAIN   equ 3
KIND_REDIR   equ 4
KIND_EOL     equ 5
KIND_COUNT   equ 6

REDIR_NONE  equ 0
REDIR_W_OUT equ 1
REDIR_W_ERR equ 2
REDIR_A_OUT equ 3
REDIR_A_ERR equ 4
REDIR_PIPE  equ 5
REDIR_COUNT equ 6

CHAIN_NONE  equ 0
CHAIN_1AMP  equ 1
CHAIN_2AMP  equ 2
CHAIN_BARS  equ 3
CHAIN_SEMI  equ 4
CHAIN_COUNT equ 5


Token struct
    offstart  word ?
    len       word ?
    pad       word ?
    kind      byte ?
    flags     byte ?
Token ends


; rcx = tokens:Tokens[MAX_TOKENS]
; edx = token_idx:Dword
; return: al = bool
externdef token_is_neutral:proc

; rcx = input:ptr sbyte const
; rdx = tokens:Token[MAX_TOKENS]
; return: eax = Error
externdef tokenize_input:proc

; rcx = input:ptr sbyte const
; rdx = tokens:Token[MAX_TOKENS]
; return: eax = Error
externdef validate_tokens:proc

; rcx = input:ptr sbyte const
; rdx = tokens:Token[MAX_TOKENS]
; return: eax = Error
externdef parse_input:proc


endif  ; _language_inc_
