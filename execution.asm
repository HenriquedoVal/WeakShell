; asmsyntax=masm

includelib kernel32
externdef CloseHandle:proc
externdef CreateFileA:proc
externdef CreatePipe:proc
externdef CreateProcessA:proc
externdef ExitProcess:proc
externdef GetExitCodeProcess:proc
externdef GetLastError:proc
externdef GetStdHandle:proc
externdef SetCurrentDirectoryA:proc
externdef SetFilePointer:proc
externdef SetHandleInformation:proc
externdef WaitForSingleObject:proc

includelib ucrt
externdef memset:proc
externdef strncmp:proc

include common.inc
include execution.inc
include language.inc

public invoke_line


STD_INPUT_HANDLE         equ 0fffffff6h
STD_OUTPUT_HANDLE        equ 0fffffff5h
STD_ERROR_HANDLE         equ 0fffffff4h

INVALID_HANDLE_VALUE     equ -1
INVALID_SET_FILE_POINTER equ 0ffffffffh

FILE_ATTRIBUTE_NORMAL    equ 00000080h

GENERIC_READ             equ 080000000h
GENERIC_WRITE            equ 040000000h

CREATE_ALWAYS            equ 2
OPEN_ALWAYS              equ 4

INFINITE                 equ 0FFFFFFFFh

SEEK_END                 equ 2

STARTF_USESTDHANDLES     equ 00000100h


BOOL   typedef sdword
LPSTR  typedef ptr sbyte
LPBYTE typedef ptr byte
LPVOID typedef qword
HANDLE typedef qword

; SEEMS like passing 8 is enough to conform with c code.
; I've checked each offset manually on these two.
STARTUPINFOA struct 8
    cb              DWORD  ?
    lpReserved      LPSTR  ?
    lpDesktop       LPSTR  ?
    lpTitle         LPSTR  ?
    dwX             DWORD  ?
    dwY             DWORD  ?
    dwXSize         DWORD  ?
    dwYSize         DWORD  ?
    dwXCountChars   DWORD  ?
    dwYCountChars   DWORD  ?
    dwFillAttribute DWORD  ?
    dwFlags         DWORD  ?
    wShowWindow     WORD   ?
    cbReserved2     WORD   ?
    lpReserved2     LPBYTE ?
    hStdInput       HANDLE ?
    hStdOutput      HANDLE ?
    hStdError       HANDLE ?
STARTUPINFOA ends
static_assert_eq sizeof STARTUPINFOA, 104

PROCESS_INFORMATION struct
    hProcess    HANDLE ?
    hThread     HANDLE ?
    dwProcessId DWORD  ?
    dwThreadId  DWORD  ?
PROCESS_INFORMATION ends
static_assert_eq sizeof PROCESS_INFORMATION, 24

SECURITY_ATTRIBUTES struct 8
  nLength              DWORD  ?
  lpSecurityDescriptor LPVOID ?
  bInheritHandle       BOOL   ?
SECURITY_ATTRIBUTES ends
static_assert_eq sizeof SECURITY_ATTRIBUTES, 24

echo_alignment macro structure
    local struct_size, _align, size_text, align_text
    struct_size = sizeof structure
    _align = struct_size mod 16
    if _align ne 0
        size_text textequ %struct_size
        align_text textequ %_align
        %echo sizeof structure == size_text, pad align_text to align 16
    endif
endm

ifndef NDEBUG
    echo_alignment STARTUPINFOA
    echo_alignment PROCESS_INFORMATION
    echo_alignment SECURITY_ATTRIBUTES
endif


maybe_close_handle macro field, STDHANDLE
    local dont_close_field, not_invalid_handle
    cmp [r13].STARTUPINFOA.field, INVALID_HANDLE_VALUE
    jne not_invalid_handle
        mov [r13].STARTUPINFOA.field, 0
        jmp dont_close_field
    not_invalid_handle:
    cmp [r13].STARTUPINFOA.field, 0
    je dont_close_field
        mov ecx, STDHANDLE
        call GetStdHandle
        assert_ne rax, INVALID_HANDLE_VALUE
        cmp [r13].STARTUPINFOA.field, rax
        je dont_close_field
            mov rcx, [r13].STARTUPINFOA.field
            call CloseHandle
            assert_ne eax, false
            mov [r13].STARTUPINFOA.field, 0
    dont_close_field:
endm


maybe_attrib_handle macro field, STDHANDLE
    local field_already_set
    cmp [r13].STARTUPINFOA.field, 0
    jne field_already_set
        mov ecx, STDHANDLE
        call GetStdHandle
        assert_ne rax, INVALID_HANDLE_VALUE
        mov [r13].STARTUPINFOA.field, rax
    field_already_set:
endm


.const

cd_str   byte "cd", 0
exit_str byte "exit", 0


.data?

g_last_exit_code dword ?


.code


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
; r9  = ptr_startupinfo : ptr STARTUPINFOA
handle_io_redir proc
    local \
        input : ptr sbyte,
        tokens : ptr Token,
        ptr_startupinfo : ptr STARTUPINFOA,
        handle : HANDLE,
        securityattr : SECURITY_ATTRIBUTES,
        token_cursor : Dword,
        creation_disposition : Dword,
        save_char : byte

    push rbp
    mov rbp, rsp
    sub rsp, 30h + sizeof securityattr  ; stack vars, sb on call
    and rsp, -16

    mov input, rcx
    mov tokens, rdx
    mov token_cursor, r8d
    mov ptr_startupinfo, r9

    mov securityattr.nLength, sizeof securityattr
    mov securityattr.bInheritHandle, true
    mov securityattr.lpSecurityDescriptor, NULL

    imul r12d, token_cursor, sizeof Token
    add r12, tokens
    assert_eq [r12].Token.kind, KIND_REDIR

    mov creation_disposition, CREATE_ALWAYS
    cmp [r12].Token.flags, REDIR_W_OUT
    je not_append
    cmp [r12].Token.flags, REDIR_W_ERR
    je not_append
        mov creation_disposition, OPEN_ALWAYS
    not_append:

    ; "... > out.file"
    ;      ^
    inc token_cursor
    ; "... > out.file"
    ;        ^

    ;; mov rcx, input
    ;; mov rdx, tokens
    mov r8d, token_cursor
    call null_terminate_last_neutral
    mov save_char, al

    ; HANDLE CreateFileA(
    ;   [in]           LPCSTR                lpFileName,
    ;   [in]           DWORD                 dwDesiredAccess,
    ;   [in]           DWORD                 dwShareMode,
    ;   [in, optional] LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    ;   [in]           DWORD                 dwCreationDisposition,
    ;   [in]           DWORD                 dwFlagsAndAttributes,
    ;   [in, optional] HANDLE                hTemplateFile
    ; );
    mov rcx, r12  ; the redir token
    add rcx, sizeof Token
    movzx ecx, [rcx].Token.offstart
    add rcx, input                          ; lpFileName
    mov edx, GENERIC_READ or GENERIC_WRITE  ; dwDesiredAccess
    xor r8, r8                              ; dwShareMode
    lea r9, securityattr                    ; lpSecurityAttributes

    sub rsp, 8  ; pad three pushes
    xor rax, rax
    push rax                                ; hTemplateFile
    mov eax, FILE_ATTRIBUTE_NORMAL
    push rax                                ; dwFlagsAndAttributes
    mov eax, creation_disposition
    push rax                                ; dwCreationDisposition

    sub rsp, SB
    call CreateFileA
    cmp rax, INVALID_HANDLE_VALUE
    jne file_created
        mov eax, ERROR_CREATE_REDIR_FILE
        jmp return_with_error_set
    file_created:
    mov handle, rax

    mov rcx, input
    mov rdx, tokens
    mov r8d, token_cursor
    mov r9b, save_char
    call restore_last_neutral

    ; It doesn't hurt this call if we created the file
    ; but it's required on append
    mov rcx, handle
    xor rdx, rdx
    xor r8, r8
    mov r9d, SEEK_END
    call SetFilePointer
    assert_ne eax, INVALID_SET_FILE_POINTER

    mov rax, handle
    mov rcx, ptr_startupinfo
    cmp [r12].Token.flags, REDIR_W_ERR
    je not_output
    cmp [r12].Token.flags, REDIR_A_ERR
    je not_output
        mov [rcx].STARTUPINFOA.hStdOutput, rax
        jmp handle_set
    not_output:
        mov [rcx].STARTUPINFOA.hStdError, rax
    handle_set:

    mov [rcx].STARTUPINFOA.dwFlags, STARTF_USESTDHANDLES

    mov eax, ERROR_NONE
    return_with_error_set:

    mov rsp, rbp
    pop rbp
    ret
handle_io_redir endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
; r9  = ptr_startupinfo : ptr STARTUPINFOA
; r10 = ptr_child_stdin : ptr HANDLE
; return: eax = Error
handle_redirections proc
    local \
        input : ptr sbyte,
        tokens : ptr Token,
        ptr_startupinfo : ptr STARTUPINFOA,
        securityattr : SECURITY_ATTRIBUTES,
        ptr_child_stdin : ptr HANDLE,
        parent_stdout : HANDLE,
        token_cursor : Dword

    push rbp
    mov rbp, rsp
    sub rsp, 30h + sizeof securityattr + SB
    and rsp, -16

    mov input, rcx
    mov tokens, rdx
    mov token_cursor, r8d
    mov ptr_startupinfo, r9
    mov ptr_child_stdin, r10

    cmp [r9].STARTUPINFOA.hStdInput, 0
    je input_not_piped
        mov [r9].STARTUPINFOA.dwFlags, STARTF_USESTDHANDLES
    input_not_piped:

    iterate_tokens:
        imul ecx, token_cursor, sizeof Token
        add rcx, tokens

        cmp [rcx].Token.kind, KIND_EOL
        je return_ok
        cmp [rcx].Token.kind, KIND_CHAIN
        je return_ok

        cmp [rcx].Token.kind, KIND_REDIR
        jne not_redir
            cmp [rcx].Token.flags, REDIR_PIPE
            je not_io_redir
                mov rcx, input
                mov rdx, tokens
                mov r8d, token_cursor
                mov r9,  ptr_startupinfo
                call handle_io_redir
                cmp eax, ERROR_NONE
                jne return_with_error_set

                add token_cursor, 2
                jmp iterate_tokens
            not_io_redir:

            mov rcx, ptr_startupinfo
            cmp [rcx].STARTUPINFOA.hStdOutput, 0
            jne output_already_set
                mov securityattr.nLength, sizeof securityattr
                mov securityattr.bInheritHandle, true
                mov securityattr.lpSecurityDescriptor, NULL

                mov rcx, ptr_child_stdin
                lea rdx, parent_stdout
                lea r8, securityattr
                xor r9d, r9d
                call CreatePipe
                assert_ne eax, 0

                mov rcx, ptr_startupinfo
                mov rdx, parent_stdout
                mov [rcx].STARTUPINFOA.hStdOutput, rdx
                mov [rcx].STARTUPINFOA.dwFlags, STARTF_USESTDHANDLES

                jmp return_ok
            output_already_set:
            mov rcx, ptr_child_stdin
            mov qword ptr [rcx], INVALID_HANDLE_VALUE
            jmp return_ok

        not_redir:
        inc token_cursor
        jmp iterate_tokens

    return_ok:
    mov rcx, ptr_startupinfo
    cmp [rcx].STARTUPINFOA.dwFlags, STARTF_USESTDHANDLES
    jne dont_attrib_handles
        call attrib_startupinfo_handles
    dont_attrib_handles:
    mov eax, ERROR_NONE
    return_with_error_set:
    mov rsp, rbp
    pop rbp
    ret
handle_redirections endp


; rcx = tokens : Token[MAX_TOKENS]
; edx = token_cursor : Dword
; return: rax = ptr Token
get_last_neutral proc
    mov r10, rcx   ; tokens
    mov r11d, edx  ; token_cursor

    iterate_tokens:
        mov rcx, r10
        mov edx, r11d
        call token_is_neutral
        cmp al, false
        je return

        inc r11d
        jmp iterate_tokens

    return:
    dec r11d
    imul eax, r11d, sizeof Token
    add rax, r10
    ret
get_last_neutral endp


; rcx = ptr_startupinfo : ptr STARTUPINFOA
attrib_startupinfo_handles proc
    push rbp
    mov rbp, rsp
    sub rsp, SB

    mov r13, rcx  ; ptr_startupinfo

    maybe_attrib_handle hStdInput,  STD_INPUT_HANDLE
    maybe_attrib_handle hStdOutput, STD_OUTPUT_HANDLE
    maybe_attrib_handle hStdError,  STD_ERROR_HANDLE

    mov rsp, rbp
    pop rbp
    ret
attrib_startupinfo_handles endp


; rcx = ptr_startupinfo : ptr STARTUPINFOA
close_startupinfo_handles proc
    push rbp
    mov rbp, rsp
    sub rsp, SB

    mov r13, rcx  ; ptr_startupinfo

    cmp [r13].STARTUPINFOA.dwFlags, STARTF_USESTDHANDLES
    jne not_inherited_handles
        ; Call CloseHandle if handle is not zero and not our stdhandle
        maybe_close_handle hStdInput,  STD_INPUT_HANDLE
        maybe_close_handle hStdOutput, STD_OUTPUT_HANDLE
        maybe_close_handle hStdError,  STD_ERROR_HANDLE

    not_inherited_handles:

    mov rsp, rbp
    pop rbp
    ret
close_startupinfo_handles endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
cd_builtin proc
    local \
        input : ptr sbyte,
        tokens : ptr Token,
        token_cursor : Dword,
        save_char : sbyte

    ; TODO: handle no arg, +, and -

    push rbp
    mov rbp, rsp
    sub rsp, 20h + SB

    mov input, rcx
    mov tokens, rdx
    mov token_cursor, r8d

    ;; mov rcx, input
    ;; mov rdx, tokens
    ;; mov r8d, token_cursor
    call null_terminate_last_neutral
    mov save_char, al

    mov rcx, input
    inc token_cursor
    imul edx, token_cursor, sizeof Token
    add rdx, tokens
    movzx edx, [rdx].Token.offstart
    add rcx, rdx
    call SetCurrentDirectoryA  ; return 0 on error
    cmp eax, 0
    jne no_cd_error
        call GetLastError
        mov g_last_exit_code, eax
        jmp cd_return_done
    no_cd_error:
        mov g_last_exit_code, 0
        ;; jmp cd_return_done
    cd_return_done:

    mov rcx, input
    mov rdx, tokens
    mov r8d, token_cursor
    mov r9b, save_char
    call restore_last_neutral

    mov rsp, rbp
    pop rbp
    ret
cd_builtin endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
; r9  = ptr_startupinfo : ptr STARTUPINFOA
; return: al = isbuiltin : bool
handle_builtins proc
    local \
        input : ptr sbyte,
        tokens : ptr Token,
        input_cursor : ptr sbyte,
        token_cursor : Dword,
        isbuiltin : bool

    push rbp
    mov rbp, rsp
    sub rsp, 20h + SB

    mov input, rcx
    mov tokens, rdx
    mov token_cursor, r8d
    mov isbuiltin, false

    imul r8d, r8d, sizeof Token     ; imul token_cursor
    add r8, rdx                     ; add tokens
    movzx r8d, [r8].Token.offstart
    add rcx, r8                     ; add input, offstart
    mov input_cursor, rcx

    ;; mov rcx, input_cursor
    lea rdx, cd_str
    mov r8, sizeof cd_str - 1
    call strncmp
    cmp eax, 0
    jne not_cd
        mov isbuiltin, true

        mov rcx, input
        mov rdx, tokens
        mov r8d, token_cursor
        call cd_builtin

        jmp return
    not_cd:

    mov rcx, input_cursor
    lea rdx, exit_str
    mov r8, sizeof exit_str - 1
    call strncmp
    cmp eax, 0
    jne not_exit
        ; TODO: handle arg
        xor rcx, rcx
        call ExitProcess
    not_exit:

    return:
    mov al, isbuiltin
    mov rsp, rbp
    pop rbp
    ret
handle_builtins endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
; return: al = replaced : sbyte
null_terminate_last_neutral proc
    local input : ptr sbyte

    push rbp
    mov rbp, rsp
    sub rsp, 10h

    mov input, rcx

    mov rcx, rdx
    mov edx, r8d
    call get_last_neutral

    movzx ecx, [rax].Token.len
    movzx edx, [rax].Token.offstart
    add rdx, input
    add rdx, rcx
    mov al, byte ptr [rdx]
    mov byte ptr [rdx], 0  ; What if buffer is immutable?

    mov rsp, rbp
    pop rbp
    ret
null_terminate_last_neutral endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
; r9b = save_char : sbyte
restore_last_neutral proc
    local \
        input : ptr sbyte,
        save_char : sbyte

    push rbp
    mov rbp, rsp
    sub rsp, 10h

    mov input, rcx
    mov save_char, r9b

    mov rcx, rdx
    mov edx, r8d
    call get_last_neutral

    movzx ecx, [rax].Token.len
    movzx edx, [rax].Token.offstart
    add rdx, input
    add rdx, rcx
    mov al, save_char
    mov byte ptr [rdx], al  ; What if buffer is immutable?

    mov rsp, rbp
    pop rbp
    ret
restore_last_neutral endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; r8d = token_cursor : Dword
; r9 = ptr_child_stdin : ptr HANDLE
; return: eax = Error
invoke_chunk proc
    local \
        input : ptr sbyte,
        tokens : ptr Token,
        ptr_child_stdin : ptr HANDLE,
        procinfo : PROCESS_INFORMATION,
        startupinfo : STARTUPINFOA,
        token_cursor : Dword,
        error : Dword,
        save_char : sbyte

    push rbp
    mov rbp, rsp
    sub rsp, 30h + sizeof procinfo + sizeof startupinfo + SB
    and rsp, -16

    mov input, rcx
    mov tokens, rdx
    mov token_cursor, r8d
    mov ptr_child_stdin, r9
    mov error, ERROR_NONE

    lea rcx, startupinfo
    mov rdx, 0
    mov r8, sizeof startupinfo
    call memset

    mov startupinfo.cb, sizeof startupinfo
    mov rax, ptr_child_stdin
    mov rax, [rax]
    mov startupinfo.hStdInput, rax

    mov rcx, input
    mov rdx, tokens
    mov r8d, token_cursor
    lea r9, startupinfo
    mov r10, ptr_child_stdin
    call handle_redirections
    cmp eax, ERROR_NONE
    je no_redirection_error
        mov error, eax
        jmp return
    no_redirection_error:

    ; check if cmd is builtin
    mov rcx, input
    mov rdx, tokens
    mov r8d, token_cursor
    lea r9,  startupinfo
    call handle_builtins
    cmp al, false
    je not_builtin
        cmp g_last_exit_code, 0
        je return
        mov error, ERROR_BUILTIN_CD
        jmp return
    not_builtin:

    mov rcx, input
    mov rdx, tokens
    mov r8d, token_cursor
    call null_terminate_last_neutral
    mov save_char, al

    lea rcx, procinfo
    push rcx              ; lpProcessInformation
    lea rcx, startupinfo
    push rcx              ; lpStartupInfo
    xor rcx, rcx
    push rcx              ; lpCurrentDirectory
    push rcx              ; lpEnvironment
    push rcx              ; dwCreationFlags
    mov rcx, true
    push rcx              ; bInheritHandles

    sub rsp, SB

    xor rcx, rcx          ; lpApplicationName

    imul edx, token_cursor, sizeof Token
    add rdx, tokens
    movzx edx, [rdx].Token.offstart
    add rdx, input        ; lpCommandLine

    xor r8, r8            ; lpProcessAttributes
    xor r9, r9            ; lpThreadAttributes
    call CreateProcessA

    cmp eax, false
    jne no_create_process_error
        mov error, ERROR_CREATE_PROCESS
        jmp return
    no_create_process_error:

    mov rcx, input
    mov rdx, tokens
    mov r8d, token_cursor
    mov r9b, save_char
    call restore_last_neutral

    lea rcx, startupinfo
    call close_startupinfo_handles

    mov rcx, procinfo.hProcess
    mov rdx, INFINITE
    call WaitForSingleObject

    mov rcx, procinfo.hProcess
    lea rdx, g_last_exit_code
    call GetExitCodeProcess
    assert_ne eax, false

    mov rcx, procinfo.hProcess
    call CloseHandle
    assert_ne rax, false
    mov rcx, procinfo.hThread
    call CloseHandle
    assert_ne rax, false

    return:
    mov eax, error

    mov rsp, rbp
    pop rbp
    ret
invoke_chunk endp


; rcx = tokens : Token[MAX_TOKENS]
; rdx = _In_Out_ ptr_token_cursor : ptr Dword
; return: al = bool
get_next_chain proc
    mov r9d, dword ptr [rdx]  ; r9d = our local token_cursor

    imul r8d, r9d, sizeof Token
    add r8, rcx

    mov al, false

    iterate_tokens:
        cmp [r8].Token.kind, KIND_EOL
        je return_false

        cmp [r8].Token.kind, KIND_CHAIN
        je return_true
        cmp [r8].Token.kind, KIND_REDIR
        jne not_redir
            cmp [r8].Token.flags, REDIR_PIPE
            je return_true
        not_redir:

        add r8, sizeof Token
        inc r9d
        jmp iterate_tokens

    return_true:
    mov al, true
    return_false:
    mov dword ptr [rdx], r9d
    ret
get_next_chain endp


; rcx = tokens : Token[MAX_TOKENS]
; edx = token_cursor : Dword
chain_should_invoke_next_chunk proc
    push rbp
    mov rbp, rsp
    sub rsp, SB

    mov al, false

    imul edx, edx, sizeof Token
    add rdx, rcx
    cmp [rdx].Token.kind, KIND_REDIR
    jne not_redir
        assert_eq [rdx].Token.flags, REDIR_PIPE
        mov al, true
        jmp return
    not_redir:

    assert_eq [rdx].Token.kind, KIND_CHAIN

    cmp [rdx].Token.flags, CHAIN_1AMP
    jne not_1amp
        mov al, true
        jmp return
    not_1amp:

    cmp [rdx].Token.flags, CHAIN_2AMP
    jne not_2amp
        cmp g_last_exit_code, 0
        jne return
        mov al, true
        jmp return
    not_2amp:

    cmp [rdx].Token.flags, CHAIN_BARS
    jne not_bars
        cmp g_last_exit_code, 0
        je return
        mov al, true
        jmp return
    not_bars:

    cmp [rdx].Token.flags, CHAIN_SEMI
    jne not_semi
        mov al, true
        jmp return
    not_semi:

    assert_unreachable

    return:
    mov rsp, rbp
    pop rbp
    ret
chain_should_invoke_next_chunk endp


; rcx = input : ptr sbyte
; rdx = tokens : Token[MAX_TOKENS]
; return error on eax
invoke_line proc
    local \
        input : ptr sbyte,
        tokens : ptr Token,
        child_stdin : HANDLE,
        token_cursor : Dword

    push rbp
    mov rbp, rsp
    sub rsp, 20h
    and rsp, -16

    mov input, rcx
    mov tokens, rdx
    mov token_cursor, 0
    mov child_stdin, NULL

    iterate_chunks:
        imul ecx, token_cursor, sizeof Token
        add rcx, tokens
        cmp [rcx].Token.kind, KIND_EOL
        je return_ok

        mov rcx, input
        mov rdx, tokens
        mov r8d, token_cursor
        lea r9, child_stdin
        call invoke_chunk
        cmp eax, ERROR_NONE
        jne return_with_error_set

        mov rcx, tokens
        lea rdx, token_cursor
        call get_next_chain
        cmp al, false
        je return_ok

        mov rcx, tokens
        mov edx, token_cursor
        call chain_should_invoke_next_chunk
        inc token_cursor
        cmp al, true
        je iterate_chunks

    return_ok:
    mov eax, ERROR_NONE
    return_with_error_set:
    mov rsp, rbp
    pop rbp
    ret
invoke_line endp


end
