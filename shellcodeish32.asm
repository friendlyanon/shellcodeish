%macro STDCALL 1-*
  %rep %0-1
    %rotate -1
    push %1
  %endrep
  %rotate -1
  call %1
%endmacro

%macro PUSH 1-*
  %rep %0
    push %1
    %rotate 1
  %endrep
%endmacro

%macro POP 1-*
  %rep %0
    %rotate -1
    pop %1
  %endrep
%endmacro

[bits 32]
[cpu 386]
[default rel]

section .data

instance_handle dd 0
ntdll_handle dd 0
kernel32_handle dd 0

section .text

global _get_proc_address@12
global pre_entry
extern _entry@4
extern load_imports

pre_entry:
  mov eax, [esp + 4]
  and esp, -16
  call @init_system_handles@4
  mov esi, eax
  STDCALL _get_proc_address@12, eax, str_ExitProcess, end_ExitProcess - str_ExitProcess
  mov ebx, eax
  STDCALL load_imports, esi
  test eax, eax
  jne .exit
  STDCALL _entry@4, instance_handle

.exit:
  STDCALL ebx, eax
  int3

@init_system_handles@4:
  mov ecx, [eax + 12] ; ldr = peb->Ldr
  mov ecx, [ecx + 20] ; instance_entry = ldr->InMemoryOrderModuleList.Flink

  mov eax, [ecx + 16] ; instance_base = containerof(instance_entry, struct LDR_DATA_TABLE_ENTRY, InMemoryOrderLinks)->DllBase
  mov [instance_handle], eax

  mov ecx, [ecx] ; ntdll_entry = *instance_entry

  mov eax, [ecx + 16] ; ntdll_base = containerof(ntdll_entry, struct LDR_DATA_TABLE_ENTRY, InMemoryOrderLinks)->DllBase
  mov [ntdll_handle], eax

  mov ecx, [ecx] ; kernel32_entry = *ntdll_entry

  mov eax, [ecx + 16] ; kernel32_base = containerof(kernel32_entry, struct LDR_DATA_TABLE_ENTRY, InMemoryOrderLinks)->DllBase
  mov [kernel32_handle], eax

  ret

_get_proc_address@12:
  mov eax, [esp + 4]
  test eax, eax
  je .ret
  mov eax, [esp + 8]
  test eax, eax
  je .ret
  mov eax, [esp + 12]
  test eax, eax
  je .ret

  add esp, -4
  PUSH ebx, ebp, edi, esi

  mov ebx, [esp + 24] ; base = first_arg
  mov ecx, [ebx + 60] ; nt_offset = base->e_lfanew
  add ecx, ebx ; nt_base = base + nt_offset
  mov ecx, [ecx + 120] ; export_rva = nt_base->OptionalHeader.DataDirectory[0].VirtualAddress
  add ecx, ebx ; export_va = base + export_rva
  mov [esp + 16], ecx
  mov edx, [ecx + 24] ; names_count = export_va->NumberOfNames
  test edx, edx
  je .end_null

  mov ebp, [ecx + 32] ; names_rva = export_va->AddressOfNames
  add ebp, ebx ; names_va = base + names_rva
  xor eax, eax
  cld

  .loop:
    mov esi, eax
    mov esi, [ebp + esi * 4] ; name_rva = names_va[eax]
    add esi, ebx ; name_va = base + name_rva
    mov edi, [esp + 28]
    mov ecx, [esp + 32]
    repe cmpsb ; memcmp(name_va, second_arg, third_arg)
    jne .continue

    mov ecx, [esp + 16]
    mov edx, [ecx + 36] ; ordinals_rva = export_va->AddressOfNameOrdinals
    add edx, ebx ; ordinals_va = base + ordinals_rva
    mov esi, eax
    movzx esi, word [edx + esi * 2] ; ordinal = ordinals_va[eax]
    mov edi, [ecx + 28] ; functions = export_va->AddressOfFunctions
    add edi, ebx ; functions_rva = export_va->AddressOfFunctions
    mov eax, [edi + esi * 4] ; function = functions_va[ordinal]
    add eax, ebx
    jmp .end

  .continue:
    inc eax
    cmp edx, eax
    jne .loop

.end_null:
  xor eax, eax

.end:
  POP ebx, ebp, edi, esi
  add esp, 4
.ret:
  ret 12

section .rdata

str_ExitProcess db "ExitProcess", 0
end_ExitProcess:
