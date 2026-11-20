ifndef _common_inc_
_common_inc_ = 1


includelib ucrt
externdef exit:proc

includelib msvcrt
externdef _CRT_INIT:proc

includelib legacy_stdio_definitions
externdef printf:proc


option casemap:none
option prologue:none
option epilogue:none


INPUT_BUF_SIZE equ 1024
MAX_TOKENS     equ 30

SB             equ 32
TAB            equ 9
NL             equ 10
SPACE          equ 32
DQUOTE         equ 34
SQUOTE         equ 39
NULL           equ 0

MAX_PATH       equ 260

ERROR_NONE                            equ 0
ERROR_PARSE_TOO_MUCH_INPUT            equ 1
ERROR_VALIDATE_NO_CMD                 equ 2
ERROR_VALIDATE_NO_REDIR_TARGET        equ 3
ERROR_VALIDATE_MULTIPLE_REDIR_TARGET  equ 4
ERROR_VALIDATE_OUT_ALREADY_REDIRECTED equ 5
ERROR_VALIDATE_ERR_ALREADY_REDIRECTED equ 6
ERROR_CREATE_PROCESS                  equ 7
ERROR_CREATE_REDIR_FILE               equ 8
ERROR_BUILTIN_CD                      equ 9
ERROR_COUNT                           equ 10

bool typedef byte

false equ 0
true  equ 1


stringfy macro arg
    local string
    string catstr <'>, arg, <'>
    exitm string
endm


_assert_failed macro expr
    local const_in_code_label, expr_str

    ifndef assertion_err_str
        .const
        assertion_err_str byte stringfy(@FileCur),
                "(%i): assertion failed: %s", NL, 0
        .code
    endif

    jmp const_in_code_label
    expr_str byte stringfy(expr), 0
    const_in_code_label:

    ; We don't need to alloc sb to assert.
    sub rsp, SB
    and rsp, -16

    lea rcx, assertion_err_str
    mov rdx, @Line
    lea r8, expr_str
    call printf
    mov rcx, 1
    call exit
endm

_assert_cmps macro cmp1, cmp2, jump, expr
    local assert_out
ifndef NDEBUG
    cmp cmp1, cmp2
    jump assert_out
        _assert_failed expr
    assert_out:
endif
endm

assert_unreachable macro cmp1, cmp2
    local expr
ifndef NDEBUG
    expr textequ <unreachable>
    _assert_failed expr
endif
endm

assert_eq macro cmp1, cmp2
    local expr
    expr catstr <cmp1>, < == >, <cmp2>
    _assert_cmps cmp1, cmp2, je, expr
endm

assert_ne macro cmp1, cmp2
    local expr
    expr catstr <cmp1>, < != >, <cmp2>
    _assert_cmps cmp1, cmp2, jne, expr
endm


static_assert_eq macro a, b
    local expr
    expr catstr <a>, < == >, <b>
    if a ne b
        %.err <static assertion failed: expr>
    endif
endm

static_assert_entry_size macro const_name, item_size
    local name_size, size_str, should
    name_size = sizeof const_name
    if name_size ne item_size
        size_str textequ %name_size
        should textequ %item_size
        %.err <size of `const_name` is size_str, should be should>
    endif
endm


endif  ; _common_inc_
