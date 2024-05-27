[bits 64]
[cpu x64]

section .data

instance_handle dq 0
ntdll_handle dq 0
kernel32_handle dq 0

section .text

global get_proc_address
global pre_entry
extern entry

init_system_handles:
  xor rax, rax
  mov rcx, gs:[rax + 96]
  mov rcx, [rcx + 24]
  mov rcx, [rcx + 32]

  mov rax, [rcx + 32]
  mov [instance_handle], rax

  mov rcx, [rcx]

  mov rax, [rcx + 32]
  mov [ntdll_handle], rax

  mov rcx, [rcx]

  mov rax, [rcx + 32]
  mov [kernel32_handle], rax

  ret

get_proc_address:
  test rcx, rcx
  je .ret
  test rdx, rdx
  je .ret
  test r8, r8
  je .ret

  mov [rsp + 8], rsi
  mov [rsp + 16], rdi
  mov [rsp + 24], rbp

  mov r9, rcx
  mov ecx, [r9 + 60]
  add rcx, r9
  mov ecx, [rcx + 136]
  add rcx, r9
  mov r10, rcx
  mov r11d, [rcx + 24]
  test r11, r11
  je .end_null

  mov ebp, [rcx + 32]
  add rbp, r9
  xor rax, rax
  cld

  .loop:
    mov rsi, rax
    mov esi, [rbp + rsi * 4]
    add rsi, r9
    mov rdi, rdx
    mov rcx, r8
    repe cmpsb
    jne .continue

    mov rcx, r10
    mov edx, [rcx + 36]
    add rdx, r9
    mov rsi, rax
    movzx rsi, word [rdx + rsi * 2]
    mov edi, [rcx + 28]
    add rdi, r9
    mov eax, [rdi + rsi * 4]
    add rax, r9
    jmp .end

  .continue:
    inc rax
    cmp r11, rax
    jne .loop

.end_null:
  xor rax, rax

.end:
  mov rbp, [rsp + 24]
  mov rdi, [rsp + 16]
  mov rsi, [rsp + 8]
.ret:
  ret

pre_entry:
  add rsp, -32
  and rsp, -16
  call init_system_handles
  mov rcx, rax
  mov rdx, str_ExitProcess
  mov r8, end_ExitProcess - str_ExitProcess
  call get_proc_address
  mov rbx, rax
  mov rcx, instance_handle
  call entry
  xor ecx, ecx
  call rbx
  int3

section .rdata

str_ExitProcess db "ExitProcess", 0
end_ExitProcess:
