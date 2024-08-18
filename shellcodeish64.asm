[bits 64]
[cpu x64]
[default rel]

section .data

instance_handle dq 0
ntdll_handle dq 0
kernel32_handle dq 0

section .text

global get_proc_address
global pre_entry
extern entry

pre_entry:
  add rsp, -40
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

init_system_handles:
  mov rcx, [rcx + 24] ; ldr = peb->Ldr
  mov rcx, [rcx + 32] ; instance_entry = ldr->InMemoryOrderModuleList.Flink

  mov rax, [rcx + 32] ; instance_base = containerof(instance_entry, struct LDR_DATA_TABLE_ENTRY, InMemoryOrderLinks)->DllBase
  mov [instance_handle], rax

  mov rcx, [rcx] ; ntdll_entry = *instance_entry

  mov rax, [rcx + 32] ; ntdll_base = containerof(ntdll_entry, struct LDR_DATA_TABLE_ENTRY, InMemoryOrderLinks)->DllBase
  mov [ntdll_handle], rax

  mov rcx, [rcx] ; kernel32_entry = *ntdll_entry

  mov rax, [rcx + 32] ; kernel32_base = containerof(kernel32_entry, struct LDR_DATA_TABLE_ENTRY, InMemoryOrderLinks)->DllBase
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

  mov r9, rcx ; base = first_arg
  mov ecx, [r9 + 60] ; nt_offset = base->e_lfanew
  add rcx, r9 ; nt_base = base + nt_offset
  mov ecx, [rcx + 136] ; export_rva = nt_base->OptionalHeader.DataDirectory[0].VirtualAddress
  add rcx, r9 ; export_va = base + export_rva
  mov r10, rcx
  mov r11d, [rcx + 24] ; names_count = export_va->NumberOfNames
  test r11, r11
  je .end_null

  mov ebp, [rcx + 32] ; names_rva = export_va->AddressOfNames
  add rbp, r9 ; names_va = base + names_rva
  xor rax, rax
  cld

  .loop:
    mov rsi, rax
    mov esi, [rbp + rsi * 4] ; name_rva = names_va[rax]
    add rsi, r9 ; name_va = base + name_rva
    mov rdi, rdx
    mov rcx, r8
    repe cmpsb ; memcmp(name_va, second_arg, third_arg)
    jne .continue

    mov rcx, r10
    mov edx, [rcx + 36] ; ordinals_rva = export_va->AddressOfNameOrdinals
    add rdx, r9 ; ordinals_va = base + ordinals_rva
    mov rsi, rax
    movzx rsi, word [rdx + rsi * 2] ; ordinal = ordinals_va[rax]
    mov edi, [rcx + 28] ; functions_rva = export_va->AddressOfFunctions
    add rdi, r9 ; functions_va = base + functions_rva
    mov eax, [rdi + rsi * 4] ; function = functions_va[ordinal]
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

section .rdata

str_ExitProcess db "ExitProcess", 0
end_ExitProcess:
