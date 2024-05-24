; -arch=x86 -host_arch=amd64 -no_logo
; nasm -f win32 shellcodeish32.asm && link shellcodeish32.obj /nologo /machine:x86 /out:shellcodeish32.exe /subsystem:console /stub:stub.bin /emittoolversioninfo:no /entry:entry /opt:icf /opt:ref /emitpogophaseinfo /fixed

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

section .data

instance_handle dd 0
ntdll_handle dd 0
kernel32_handle dd 0

section .text

global entry

_init_system_handles@0:
  xor eax, eax
  mov ecx, fs:[eax + 48]
  mov ecx, [ecx + 12]
  mov ecx, [ecx + 20]

  mov eax, [ecx + 16]
  mov [instance_handle], eax

  mov ecx, [ecx]

  mov eax, [ecx + 16]
  mov [ntdll_handle], eax

  mov ecx, [ecx]

  mov eax, [ecx + 16]
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

  mov ebx, [esp + 24]
  mov ecx, [ebx + 60]
  add ecx, ebx
  mov ecx, [ecx + 120]
  add ecx, ebx
  mov [esp + 16], ecx
  mov edx, [ecx + 24]
  test edx, edx
  je .end_null

  mov ebp, [ecx + 32]
  add ebp, ebx
  xor eax, eax
  cld

  .loop:
    mov esi, eax
    mov esi, [ebp + esi * 4]
    add esi, ebx
    mov edi, [esp + 28]
    mov ecx, [esp + 32]
    repe cmpsb
    jne .continue

    mov ecx, [esp + 16]
    mov edx, [ecx + 36]
    add edx, ebx
    mov esi, eax
    movzx esi, word [edx + esi * 2]
    mov edi, [ecx + 28]
    add edi, ebx
    mov eax, [edi + esi * 4]
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

entry:
  and esp, -16
  STDCALL _init_system_handles@0
  STDCALL _get_proc_address@12, eax, str_ExitProcess, end_ExitProcess - str_ExitProcess
  STDCALL eax, 0
  int3

section .rdata

str_ExitProcess db "ExitProcess", 0
end_ExitProcess:
