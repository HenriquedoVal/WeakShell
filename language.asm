; asmsyntax=masm

includelib ucrt
externdef exit:proc
externdef strncmp:proc


include common.inc
include language.inc


public token_is_neutral
public tokenize_input
public validate_tokens
public parse_input


DELIM_NOT_FOUND equ 0
DELIM_FOUND     equ 1


cmp_token macro string, FLAGS
    local outlabel
    mov rcx, token
    lea rdx, string
    mov r8,  sizeof string - 1
    call strncmp
    cmp rax, 0
    jne outlabel
        mov flags, FLAGS
        mov len, sizeof string - 1
        jmp return
    outlabel:
endm


.const

separators_str byte "12>|&;", SPACE, TAB, NL, 0  ; <, &1
squote_str     byte "'", 0
dquote_str     byte '"', 0

redir_w_out_str  byte ">",   0
redir_w_outn_str byte "1>",  0
redir_w_err_str  byte "2>",  0
redir_a_out_str  byte ">>",  0
redir_a_outn_str byte "1>>", 0
redir_a_err_str  byte "2>>", 0
redir_pipe_str   byte "|",   0

chain_1amp_str byte "&",  0
chain_2amp_str byte "&&", 0
chain_bars_str byte "||", 0
chain_semi_str byte ";",  0


.code

; rcx = token:ptr sbyte const
; return: al = chain flag; ah = chain len
get_chain proc
    local \
        token:ptr sbyte,
        flags:byte,
        len:byte

    push rbp
    mov rbp, rsp
    sub rsp, 20h + SB

    mov token, rcx
    mov flags, 0

    ; We use strncmp, the order is important, bigger to smaller
    cmp_token chain_2amp_str, CHAIN_2AMP
    cmp_token chain_bars_str, CHAIN_BARS
    cmp_token chain_1amp_str, CHAIN_1AMP
    cmp_token chain_semi_str, CHAIN_SEMI

    return:
    mov al, flags
    mov ah, len

    mov rsp, rbp
    pop rbp
    ret
get_chain endp


; rcx = token : ptr sbyte const
; return: al = redir flag; ah = redir len
get_redir proc
    local \
        token:ptr sbyte,
        flags:byte,
        len:byte

    push rbp
    mov rbp, rsp
    sub rsp, 20h + SB

    mov token, rcx
    mov flags, 0

    ; We use strncmp, the order is important, bigger to smaller
    cmp_token redir_a_outn_str, REDIR_A_OUT    ; 1>>
    cmp_token redir_a_err_str,  REDIR_A_ERR    ; 2>>
    cmp_token redir_w_outn_str, REDIR_W_OUT    ; 1>
    cmp_token redir_w_err_str,  REDIR_W_ERR    ; 2>
    cmp_token redir_a_out_str,  REDIR_A_OUT    ; >>
    cmp_token redir_w_out_str,  REDIR_W_OUT    ; >
    cmp_token redir_pipe_str,   REDIR_PIPE     ; |

    return:
    mov al, flags
    mov ah, len

    mov rsp, rbp
    pop rbp
    ret
get_redir endp


; rcx = cursor:ptr sbyte
; rdx = delim:ptr sbyte
; return: ax = the the number of bytes until first delimiter
; return: r10b = bool, if any delimiter is found
search_delim proc
    local \
        cursor:ptr sbyte,
        delim:ptr sbyte,
        i:qword,
        test_char:byte

    push rbp
    mov rbp, rsp
    sub rsp, 20h

    xor ax, ax
    mov r10b, DELIM_NOT_FOUND

    mov cursor, rcx
    mov delim, rdx

    outer_loop:
        mov r9, cursor
        mov r9b, byte ptr [r9]
        mov test_char, r9b
        cmp test_char, 0
        je return

        inc cursor
        inc ax

        mov i, 0
        inner_loop:
            ; r9b is the delimiter char
            mov rdx, delim
            add rdx, i
            mov r9b, byte ptr [rdx]
            cmp r9b, 0
            je outer_loop

            inc i

            cmp r9b, test_char
            jne inner_loop

            ; found, input char is equal to delim char
            mov r10b, DELIM_FOUND
            dec ax

    return:
    mov rsp, rbp
    pop rbp
    ret
search_delim endp


; rcx = token : ptr Token
; rdx = input : ptr sbyte const
; r8  = input_cursor : ptr sbyte const
set_token proc
    local \
        token:ptr Token,
        input:ptr sbyte,
        input_cursor:ptr sbyte,
        offstart:word,
        len:word,
        kind:byte,
        flags:byte

    push rbp
    mov rbp, rsp
    sub rsp, 20h

    mov token, rcx
    mov input, rdx
    mov input_cursor, r8

    mov len, 0
    mov kind, KIND_GENERAL
    mov flags, 0

    loop_enter:
        mov r8, input_cursor
        cmp byte ptr [r8], 0
        je done

        cmp byte ptr [r8], SPACE
        jne not_space
            inc input_cursor
            jmp loop_enter
        not_space:

    cmp byte ptr [r8], SQUOTE
    jne not_squote
        inc input_cursor

        mov rcx, input_cursor
        lea rdx, squote_str
        call search_delim

        mov len, ax
        mov kind, KIND_SQUOTE
        mov flags, r10b
        jmp done
    not_squote:

    cmp byte ptr [r8], DQUOTE
    jne not_dquote
        inc input_cursor

        mov rcx, input_cursor
        lea rdx, dquote_str
        call search_delim

        mov len, ax
        mov kind, KIND_DQUOTE
        mov flags, r10b
        jmp done
    not_dquote:

    ; Must call get_chain before get_redir
    ; bc redir pipe (|) is smaller than chain or (||)
    mov rcx, input_cursor
    call get_chain
    cmp al, 0
    je not_chain
        movzx dx, ah
        mov len, dx
        mov kind, KIND_CHAIN
        mov flags, al
        jmp done
    not_chain:

    mov rcx, input_cursor
    call get_redir
    cmp al, 0
    je not_redir
        movzx dx, ah
        mov len, dx
        mov kind, KIND_REDIR
        mov flags, al
        jmp done
    not_redir:

    mov rcx, input_cursor
    lea rdx, separators_str
    call search_delim

    mov len, ax

    done:

    mov rcx, input_cursor
    sub rcx, input
    mov offstart, cx

    cmp len, 0
    jne len_not_zero
        mov kind, KIND_EOL
    len_not_zero:

    mov rcx, token
    mov dx, offstart
    mov [rcx].Token.offstart, dx
    mov dx, len
    mov [rcx].Token.len, dx
    mov dl, kind
    mov [rcx].Token.kind, dl
    mov dl, flags
    mov [rcx].Token.flags, dl

    mov rsp, rbp
    pop rbp
    ret
set_token endp


; rcx = input:ptr sbyte const
; rdx = tokens:Token[MAX_TOKENS]
; return: eax = Error
tokenize_input proc
    local \
        input:ptr sbyte,
        tokens:ptr Token,
        current_token:ptr Token,
        input_cursor:ptr sbyte,
        token_idx:Dword

    push rbp
    mov rbp, rsp
    sub rsp, 30h

    mov input, rcx
    mov input_cursor, rcx
    mov tokens, rdx

    mov token_idx, 0
    loop_enter:
        cmp token_idx, MAX_TOKENS
        jl in_bounds
            mov eax, ERROR_PARSE_TOO_MUCH_INPUT
            jmp return
        in_bounds:

        imul ecx, token_idx, sizeof Token
        add rcx, tokens
        mov current_token, rcx

        ;; mov rcx, current_token
        mov rdx, input
        mov r8,  input_cursor
        call set_token

        inc token_idx

        mov rcx, current_token
        movzx r8, [rcx].Token.len
        movzx r9, [rcx].Token.offstart
        add r9, r8
        add r9, input
        mov input_cursor, r9

        ; if kind == dquote|squote
        ;    && flags == COMPLETE   then input_cursor++
        cmp [rcx].Token.kind, KIND_SQUOTE
        jne not_squote
            cmp [rcx].Token.flags, DELIM_FOUND
            jne done
                inc input_cursor
                jmp done

        not_squote:
        cmp [rcx].Token.kind, KIND_DQUOTE
        jne done
            cmp [rcx].Token.flags, DELIM_FOUND
            jne done
                inc input_cursor
                ; jmp done

        done:

        cmp r8, 0
        jne loop_enter

    mov eax, ERROR_NONE

    return:
    mov rsp, rbp
    pop rbp
    ret
tokenize_input endp


; rcx = tokens:Token[MAX_TOKENS]
; edx = token_idx:Dword
; r8b = Kind
token_kind proc
    imul edx, edx, sizeof Token
    add rdx, rcx
    cmp [rdx].Token.kind, r8b
    jne return_false

    mov al, true
    ret

    return_false:
    mov al, false
    ret
token_kind endp


; rcx = tokens:Token[MAX_TOKENS]
; edx = token_idx:Dword
; return: al = bool
token_is_neutral proc
    imul edx, edx, sizeof Token
    add rdx, rcx
    cmp [rdx].Token.kind, KIND_GENERAL
    je return_true
    cmp [rdx].Token.kind, KIND_SQUOTE
    je return_true
    cmp [rdx].Token.kind, KIND_DQUOTE
    je return_true

    mov al, false
    ret

    return_true:
    mov al, true
    ret
token_is_neutral endp


; rcx = tokens:Token[MAX_TOKENS]
; edx = token_idx:Dword
redir_is_out proc
    imul edx, edx, sizeof Token
    add rdx, rcx
    assert_eq [rdx].Token.kind, KIND_REDIR

    cmp [rdx].Token.flags, REDIR_W_OUT
    je return_true
    cmp [rdx].Token.flags, REDIR_A_OUT
    je return_true

    mov al, false
    ret

    return_true:
    mov al, true
    ret
redir_is_out endp


; rcx = tokens:Token[MAX_TOKENS]
; edx = token_idx:Dword
redir_is_err proc
    imul edx, edx, sizeof Token
    add rdx, rcx
    assert_eq [rdx].Token.kind, KIND_REDIR

    cmp [rdx].Token.flags, REDIR_W_ERR
    je return_true
    cmp [rdx].Token.flags, REDIR_A_ERR
    je return_true

    mov al, false
    ret

    return_true:
    mov al, true
    ret
redir_is_err endp


; rcx = input:ptr sbyte const
; rdx = tokens:Token[MAX_TOKENS]
; return: eax = Error
validate_tokens proc
    local \
        input:ptr sbyte,
        tokens:ptr Token,
        token_idx:Dword,
        first_chunk:bool,
        cmd_found:bool,
        out_redirected:bool,
        err_redirected:bool

    push rbp
    mov rbp, rsp
    sub rsp, 20h + SB

    mov input, rcx
    mov tokens, rdx

    mov token_idx, 0
    mov first_chunk, true

    chunk_loop:
        mov out_redirected, false
        mov err_redirected, false

        cmp first_chunk, false
        je must_have_input
            mov rcx, tokens
            mov edx, token_idx
            mov r8b, KIND_EOL
            call token_kind
            cmp al, true
            je return_ok
        must_have_input:

        mov cmd_found, false

        ; neutrals = KIND_{GENERAL|DQUOTE|SQUOTE}
        skip_neutrals_loop:
            mov rcx, tokens
            mov edx, token_idx
            call token_is_neutral
            cmp al, false
            je skip_neutrals_out

            mov cmd_found, true
            inc token_idx
            jmp skip_neutrals_loop
        skip_neutrals_out:

        ; if no input, error
        cmp cmd_found, true
        je has_command
            mov eax, ERROR_VALIDATE_NO_CMD
            jmp return_with_error_set
        has_command:

        redirections_loop:
        ; if redir -> number of subsequent neutrals must be exactly 1
        mov rcx, tokens
        mov edx, token_idx
        mov r8b, KIND_REDIR
        call token_kind
        cmp al, false
        je not_redir

            imul ecx, token_idx, sizeof Token
            add rcx, tokens
            cmp [rcx].Token.flags, REDIR_PIPE
            jne not_pipe
                mov first_chunk, false
                inc token_idx
                jmp chunk_loop
            not_pipe:

            mov rcx, tokens
            mov edx, token_idx
            call redir_is_out
            cmp al, false
            je not_output_stream
                cmp out_redirected, false
                je no_out_redirected_error
                    mov eax, ERROR_VALIDATE_OUT_ALREADY_REDIRECTED
                    jmp return_with_error_set
                no_out_redirected_error:
                mov out_redirected, true
                jmp checked_redirection_duplicity
            not_output_stream:

            mov rcx, tokens
            mov edx, token_idx
            call redir_is_err
            assert_ne al, false

            cmp err_redirected, false
            je no_err_redirected_error
                mov eax, ERROR_VALIDATE_ERR_ALREADY_REDIRECTED
                jmp return_with_error_set
            no_err_redirected_error:
            mov err_redirected, true
            ; jmp checked_redirection_duplicity

            checked_redirection_duplicity:

            inc token_idx

            mov rcx, tokens
            mov edx, token_idx
            call token_is_neutral
            cmp al, true
            je is_neutral
                mov eax, ERROR_VALIDATE_NO_REDIR_TARGET
                jmp return_with_error_set
            is_neutral:

            ; Redir target is fine, check if there are more than one
            inc token_idx

            mov rcx, tokens
            mov edx, token_idx
            call token_is_neutral
            cmp al, false
            je no_excess_args
                mov eax, ERROR_VALIDATE_MULTIPLE_REDIR_TARGET
                jmp return_with_error_set
            no_excess_args:
            jmp redirections_loop
        not_redir:

        ; if chain -> recurse/iterate
        mov rcx, tokens
        mov edx, token_idx
        mov r8b, KIND_CHAIN
        call token_kind
        cmp al, false
        je not_chain
            mov first_chunk, true

            ; token_kind leaves `token *` in rdx
            cmp [rdx].Token.flags, CHAIN_SEMI
            je is_semi
                mov first_chunk, false
            is_semi:

            inc token_idx
            jmp chunk_loop
        not_chain:

        ; if eol, return ok
        mov rcx, tokens
        mov edx, token_idx
        mov r8b, KIND_EOL
        call token_kind
        assert_eq al, true

    return_ok:
    mov eax, ERROR_NONE

    return_with_error_set:
    mov rsp, rbp
    pop rbp
    ret
validate_tokens endp


; rcx = input:ptr sbyte const
; rdx = tokens:Token[MAX_TOKENS]
; return: eax = Error
parse_input proc
    local \
        input:ptr sbyte,
        tokens:ptr Token

    push rbp
    mov rbp, rsp
    sub rsp, 10h + SB

    mov input, rcx
    mov tokens, rdx

    ;; mov rcx, input
    ;; mov rdx, tokens
    call tokenize_input
    cmp eax, ERROR_NONE
    jne return

    mov rcx, input
    mov rdx, tokens
    mov r8d, false
    call validate_tokens

    return:
    mov rsp, rbp
    pop rbp
    ret
parse_input endp


end
