; asmsyntax=masm

include common.inc
include language.inc
include execution.inc

includelib ucrt
externdef __acrt_iob_func:proc  ; get std streams
externdef fgets:proc
externdef strlen:proc

includelib kernel32
externdef GetCurrentDirectoryW:proc


.const

fmt_prompt byte "WkSh %ls> ", 0

fmt_error_general   byte "wksh: %s", NL, 0
fmt_error_tokenizer byte "wksh tokenizer: %s", NL, 0
fmt_error_syntax    byte "wksh syntax: %s", NL, 0
fmt_error_execution byte "wksh execution: %s", NL, 0
fmt_error_cd        byte "wksh cd: %s", NL, 0

error_str_0 byte "no error", 0
error_str_1 byte "too much input", 0
error_str_2 byte "no command provided", 0
error_str_3 byte "no redirection target", 0
error_str_4 byte "multiple redirection target", 0
error_str_5 byte "output stream already redirected", 0
error_str_6 byte "error stream already redirected", 0
error_str_7 byte "command is not a builtin or executable", 0
error_str_8 byte "cannot create redirection file", 0
error_str_9 byte "cannot set current directory", 0

align 16
__table_start = $
table_fmt_error qword offset fmt_error_general,
                      offset fmt_error_tokenizer,
                      offset fmt_error_syntax,
                      offset fmt_error_syntax,
                      offset fmt_error_syntax,
                      offset fmt_error_syntax,
                      offset fmt_error_syntax,
                      offset fmt_error_execution,
                      offset fmt_error_execution,
                      offset fmt_error_cd
__table_count = ($ - __table_start) / sizeof qword
if __table_count ne ERROR_COUNT
    .err <Must set an format string for each Error enum>
endif

__table_start = $
table_str_error qword offset error_str_0,
                      offset error_str_1,
                      offset error_str_2,
                      offset error_str_3,
                      offset error_str_4,
                      offset error_str_5,
                      offset error_str_6,
                      offset error_str_7,
                      offset error_str_8,
                      offset error_str_9
__table_count = ($ - __table_start) / sizeof qword
if __table_count ne ERROR_COUNT
    .err <Must set an error string for each Error enum>
endif


.code

show_prompt proc
    local curdir[MAX_PATH]:sword
    static_assert_eq sizeof curdir, MAX_PATH * 2

    push rbp
    mov rbp, rsp
    sub rsp, sizeof curdir + SB
    and rsp, -16

    mov rcx, sizeof curdir
    lea rdx, curdir
    call GetCurrentDirectoryW
    assert_ne eax, 0

    lea rcx, fmt_prompt
    lea rdx, curdir
    call printf

    mov rsp, rbp
    pop rbp
    ret
show_prompt endp


; rcx = input_buf : sbyte[INPUT_BUF_SIZE]
get_input proc
    local input_buf : ptr sbyte

    push rbp
    mov rbp, rsp
    sub rsp, 10h + SB

    mov input_buf, rcx

    xor rcx, rcx
    call __acrt_iob_func

    mov rcx, input_buf
    mov edx, INPUT_BUF_SIZE
    mov r8,  rax
    call fgets
    assert_ne rax, 0

    mov rcx, input_buf
    call strlen

    dec rax
    mov rcx, input_buf
    add rcx, rax
    mov [rcx], byte ptr 0

    xor rax, rax

    mov rsp, rbp
    pop rbp
    ret
get_input endp


; ecx = Error enum
print_error proc
    push rbp
    mov rbp, rsp
    sub rsp, SB

    mov r8d, ecx
    imul r8, r8, sizeof qword

    lea rcx, table_fmt_error
    add rcx, r8
    mov rcx, [rcx]

    lea rdx, table_str_error
    add rdx, r8
    mov rdx, [rdx]
    call printf

    mov rsp, rbp
    pop rbp
    ret
print_error endp


main proc
    local \
        input[INPUT_BUF_SIZE]:sbyte,
        tokens[MAX_TOKENS]:Token

    push rbp
    mov rbp, rsp
    sub rsp, sizeof input + sizeof tokens + SB
    and rsp, -16

    call _CRT_INIT

    enter_mainloop:
        call show_prompt

        lea rcx, input
        call get_input

        lea rcx, input
        lea rdx, tokens
        call parse_input
        cmp eax, ERROR_NONE
        je no_parse_error
            mov ecx, eax
            call print_error
            jmp enter_mainloop
        no_parse_error:

        lea rcx, input
        lea rdx, tokens
        call invoke_line
        cmp eax, ERROR_NONE
        je no_invoke_error
            mov ecx, eax
            call print_error
            jmp enter_mainloop
        no_invoke_error:

        jmp enter_mainloop

    assert_unreachable

    ret
main endp


end
