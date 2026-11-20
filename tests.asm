; asmsyntax=masm

include common.inc
include language.inc


.const

fmt_i byte "%i", NL, 0
fmt_s byte "%s", NL, 0
fmt_test_test byte "%s", NL, "Expected: %i; Got: %i", NL, NL, 0

fmt_debug_token byte "Token: %p", NL,
                     "  offstart: %u", NL,
                     "  len:      %u", NL,
                     "  kind:     %s", NL,
                     "  flags:    %s", NL, NL, 0

ENUM_STRING_SIZE equ 16

align 16
__start_names = $
kind_general_name_str  byte "KIND_GENERAL", 0, 3 dup(?)
kind_squote_name_str   byte "KIND_SQUOTE",  0, 4 dup(?)
kind_dquote_name_str   byte "KIND_DQUOTE",  0, 4 dup(?)
kind_chain_name_str    byte "KIND_CHAIN",   0, 5 dup(?)
kind_redir_name_str    byte "KIND_REDIR",   0, 5 dup(?)
kind_eol_name_str      byte "KIND_EOL",     0, 7 dup(?)
if ($ - __start_names) / ENUM_STRING_SIZE ne KIND_COUNT
    .err <Must declare a string for each Kind enum>
endif

__static_assert_count = 0
for entry, <kind_general_name_str, kind_squote_name_str, kind_dquote_name_str, kind_chain_name_str, kind_redir_name_str, kind_eol_name_str>
    __static_assert_count = __static_assert_count + 1
    static_assert_entry_size entry, ENUM_STRING_SIZE
endm
if __static_assert_count ne KIND_COUNT
    .err <Not all Kind strings had their sizes checked>
endif

__start_names = $
__first_redir = redir_none_name_str
redir_none_name_str   byte "REDIR_NONE",   0, 5 dup(?)
redir_w_out_name_str  byte "REDIR_W_OUT",  0, 4 dup(?)
redir_w_err_name_str  byte "REDIR_W_ERR",  0, 4 dup(?)
redir_a_out_name_str  byte "REDIR_A_OUT",  0, 4 dup(?)
redir_a_err_name_str  byte "REDIR_A_ERR",  0, 4 dup(?)
redir_pipe_name_str   byte "REDIR_PIPE",   0, 5 dup(?)
if ($ - __start_names) / ENUM_STRING_SIZE ne REDIR_COUNT
    .err <Must declare a string for each Redir enum>
endif

__static_assert_count = 0
for entry, <redir_none_name_str, redir_w_out_name_str, redir_w_err_name_str, redir_a_out_name_str, redir_a_err_name_str, redir_pipe_name_str>
    __static_assert_count = __static_assert_count + 1
    static_assert_entry_size entry, ENUM_STRING_SIZE
endm
if __static_assert_count ne REDIR_COUNT
    .err <Not all Redir strings had their sizes checked>
endif

__start_names = $
__first_chain = chain_none_name_str
chain_none_name_str   byte "CHAIN_NONE",   0, 5 dup(?)
chain_1amp_name_str   byte "CHAIN_1AMP",   0, 5 dup(?)
chain_2amp_name_str   byte "CHAIN_2AMP",   0, 5 dup(?)
chain_bars_name_str   byte "CHAIN_BARS",   0, 5 dup(?)
chain_semi_name_str   byte "CHAIN_SEMI",   0, 5 dup(?)
if ($ - __start_names) / ENUM_STRING_SIZE ne CHAIN_COUNT
    .err <Must declare a string for each Chain enum>
endif

__static_assert_count = 0
for entry, <chain_none_name_str, chain_1amp_name_str, chain_2amp_name_str, chain_bars_name_str, chain_semi_name_str>
    __static_assert_count = __static_assert_count + 1
    static_assert_entry_size entry, ENUM_STRING_SIZE
endm
if __static_assert_count ne CHAIN_COUNT
    .err <Not all Chain strings had their sizes checked>
endif

zero_str              byte "0",            0, 14 dup(?)
eol_str               byte "INPUT_END",    0, 6 dup(?)

quote_incomplete_str  byte "INCOMPLETE",   0, 5 dup(?)
quote_complete_str    byte "COMPLETE",     0, 7 dup(?)


for entry, <zero_str, eol_str>
    static_assert_entry_size entry, ENUM_STRING_SIZE
endm
for entry, <quote_incomplete_str, quote_complete_str>
    static_assert_entry_size entry, ENUM_STRING_SIZE
endm

flag_str_table qword offset zero_str,              ; kind_general
                     offset quote_incomplete_str,  ; kind_squote
                     offset quote_incomplete_str,  ; kind_dquote
                     offset __first_chain,         ; kind_chain
                     offset __first_redir,         ; kind_redir
                     offset zero_str               ; kind_eol


if (sizeof flag_str_table / sizeof qword) ne KIND_COUNT
    .err <flag_str_table size is wrong>
endif


; Test cases

TEST_TABLE_ITEM_SIZE equ 32

__START_OF_TEST_TABLE equ $
test_str_0  byte                     0, 31 dup(?)
test_str_1  byte "cmd",              0, 28 dup(?)
test_str_2  byte "cmd >",            0, 26 dup(?)
test_str_3  byte "cmd > out",        0, 22 dup(?)
test_str_4  byte "cmd > out >",      0, 20 dup(?)
test_str_5  byte "cmd 2> out",       0, 21 dup(?)
test_str_6  byte "cmd 2> out 2>",    0, 18 dup(?)
test_str_7  byte "cmd > out > out",  0, 16 dup(?)
test_str_8  byte "cmd > out 2> out", 0, 15 dup(?)
test_str_9  byte "cmd &&",           0, 25 dup(?)
for entry, <test_str_0, test_str_1, test_str_2, test_str_3, test_str_4, test_str_5, test_str_6, test_str_7, test_str_8, test_str_9>
    static_assert_entry_size entry, TEST_TABLE_ITEM_SIZE
endm

test_str_10 byte "cmd > a b",    0, 22 dup(?)
test_str_11 byte ">&&",          0, 28 dup(?)
test_str_12 byte "cmd&&",        0, 26 dup(?)
test_str_13 byte "cmd&&other",   0, 21 dup(?)
test_str_14 byte "cmd>out2>out", 0, 19 dup(?)
test_str_15 byte "cmd && >",     0, 23 dup(?)
test_str_16 byte "cmd|",         0, 27 dup(?)
test_str_17 byte "cmd;",         0, 27 dup(?)
test_str_18 byte "cmd&other;",   0, 21 dup(?)
test_str_19 byte "cmd||other",   0, 21 dup(?)
for entry, <test_str_10, test_str_11, test_str_12, test_str_13, test_str_14, test_str_15, test_str_16, test_str_17, test_str_18, test_str_19>
    static_assert_entry_size entry, TEST_TABLE_ITEM_SIZE
endm

test_str_20 byte "a>a.txt&&a>b.txt",    0, 15 dup(?)
for entry, <test_str_20>
    static_assert_entry_size entry, TEST_TABLE_ITEM_SIZE
endm

TEST_TABLE_COUNT equ ($ - __START_OF_TEST_TABLE) / TEST_TABLE_ITEM_SIZE

__START_OF_EXPECTED_TABLE equ $

expected_err byte ERROR_NONE,                             ; 0
                  ERROR_NONE,
                  ERROR_VALIDATE_NO_REDIR_TARGET,
                  ERROR_NONE,
                  ERROR_VALIDATE_OUT_ALREADY_REDIRECTED,
                  ERROR_NONE,                             ; 5
                  ERROR_VALIDATE_ERR_ALREADY_REDIRECTED,
                  ERROR_VALIDATE_OUT_ALREADY_REDIRECTED,
                  ERROR_NONE,
                  ERROR_VALIDATE_NO_CMD
_continue byte    ERROR_VALIDATE_MULTIPLE_REDIR_TARGET,   ; 10
                  ERROR_VALIDATE_NO_CMD,
                  ERROR_VALIDATE_NO_CMD,
                  ERROR_NONE,
                  ERROR_NONE,
                  ERROR_VALIDATE_NO_CMD,                  ; 15
                  ERROR_VALIDATE_NO_CMD,
                  ERROR_NONE,
                  ERROR_NONE,
                  ERROR_NONE
_continue2 byte   ERROR_NONE                              ; 20

__EXPECTED_TABLE_COUNT equ ($ - __START_OF_EXPECTED_TABLE) / 1

if __EXPECTED_TABLE_COUNT ne TEST_TABLE_COUNT
    .err <there's difference is size of expected_table and test_cases>
endif


.code

; rcx = Token[MAX_TOKENS] tokens
dump_tokens proc
    local \
        tokens:qword,
        current_token:qword,
        token_idx:Dword

    push rbp
    mov rbp, rsp
    sub rsp, 20h  ; stack vars printf, dynamic SB

    mov tokens, rcx

    mov token_idx, 0
    loop_enter:
        imul edx, token_idx, sizeof Token
        add rdx, tokens
        mov current_token, rdx

        mov r15, current_token

        lea rcx, fmt_debug_token
        ;; mov rdx, current_token
        movzx r8d, [r15].Token.offstart
        movzx r9d, [r15].Token.len

        lea r11, flag_str_table
        movzx r12d, [r15].Token.kind
        imul r12d, r12d, sizeof qword
        add r11, r12
        mov r11, [r11]
        movzx r12d, [r15].Token.flags
        imul r12d, r12d, ENUM_STRING_SIZE
        add r11, r12
        push r11

        movzx r11d, [r15].Token.kind
        imul r11d, r11d, ENUM_STRING_SIZE
        lea r10, kind_general_name_str
        add r10, r11
        push r10

        sub rsp, SB
        call printf

        add rsp, SB
        pop r10
        pop r11

        inc token_idx

        mov r15, current_token
        cmp [r15].Token.len, 0
        jne loop_enter

    mov rsp, rbp
    pop rbp
    ret
dump_tokens endp


; rcx = case
; edx = expected
; r8d = got
; r9  = tokens:Token[MAX_TOKENS]
test_ok proc
    local \
        tokens : ptr Token,
        result : bool

    push rbp
    mov rbp, rsp
    sub rsp, 20h + SB

    mov tokens, r9
    mov result, true

    cmp edx, r8d
    je pass
        mov result, false

        mov r9d, r8d
        mov r8d, edx
        mov rdx, rcx
        lea rcx, fmt_test_test
        call printf

        mov rcx, tokens
        call dump_tokens
    pass:

    mov al, result

    mov rsp, rbp
    pop rbp
    ret
test_ok endp


main proc
    local \
        tokens[MAX_TOKENS]:Token,
        case:qword,
        idx:dword,
        result:bool

    push rbp
    mov rbp, rsp
    sub rsp, sizeof tokens + sizeof case + sizeof idx + 1 + SB
    and rsp, -16

    mov idx, 0
    mov result, 0

    call _CRT_INIT

    enter_loop:
        cmp idx, TEST_TABLE_COUNT
        jnb out_of_bounds

        lea rcx, test_str_0
        imul r8d, idx, TEST_TABLE_ITEM_SIZE
        add rcx, r8
        mov case, rcx

        ;; mov rcx, case
        lea rdx, tokens
        call parse_input

        mov rcx, case
        lea rdx, expected_err
        mov r9d, idx
        add rdx, r9
        movzx edx, byte ptr [rdx]
        mov r8d, eax
        lea r9, tokens
        call test_ok
        cmp al, true
        je no_err
            mov result, 1
        no_err:

        inc idx
        jmp enter_loop
    out_of_bounds:

    movzx rax, result

    mov rsp, rbp
    pop rbp
    ret
main endp


end
