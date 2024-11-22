@if (@CodeSection == @Batch) @then

@echo off

set now=%time:,=.%
>&2 echo Start build: %now: =0%
call :build %*
set now=%time:,=.%
>&2 echo Finish build: %now: =0%
:exit
exit /b %errorlevel%

:build
setlocal

set arch=amd64
set format=64
set machine=x64
set cflags="/DSIZE_TYPE=long long" "/DUSIZE_TYPE=unsigned long long" "/DINT64_TYPE=long long" /DSTDCALL=
if "%1" == "32" (
  set arch=x86
  set format=32
  set machine=x86
  set cflags=/DSIZE_TYPE=int "/DUSIZE_TYPE=unsigned int" "/DINT64_TYPE=long long" /DSTDCALL=__stdcall /DIS_ILP32=1
)

if "%VSCMD_ARG_TGT_ARCH%" == "" (
  call :vcvars -arch=%arch% -host_arch=amd64 -no_logo || goto :exit
) else if not "%VSCMD_ARG_TGT_ARCH%" == "%machine%" (
  >&2 echo vcvars has already been initialized for %VSCMD_ARG_TGT_ARCH%, but the build is targeting %machine%
  exit /b 1
)

cscript.exe //Nologo //E:JScript "%~f0" %format% || goto :exit

echo import%format%.asm
nasm.exe -f win%format% import%format%.asm || goto :exit

if not exist stub.bin (
  echo stub.bin
  nasm.exe -f bin stub.asm -o stub.bin || goto :exit
)

echo shellcodeish%format%.asm
nasm.exe -f win%format% shellcodeish%format%.asm || goto :exit

set warnings=/Wall /wd4711
set conformance=/utf-8 /std:c17 /permissive- /volatile:iso /Zc:inline
set clargs=/nologo /GS- /Gs1000000000 /O2 /diagnostics:caret /I. %warnings% %conformance% %cflags%
set linkargs=shellcodeish%format%.obj import%format%.obj /machine:%machine% /out:shellcodeish%format%.exe /subsystem:console /stub:stub.bin /ignore:4060 /entry:pre_entry /opt:icf /opt:ref /emittoolversioninfo:no /emitpogophaseinfo /fixed /safeseh:no /align:16 /ignore:4108

cl.exe %clargs% main.c /link %linkargs% || goto :exit

del main.obj shellcodeish%format%.obj import%format%.obj
if exist cff_error.txt del cff_error.txt

call :cff clear_timestamp.cff shellcodeish%format%.exe || goto :exit

if %format% == 64 call :cff remove_pdata.cff shellcodeish64.exe || goto :exit

exit /b 0

:cff
"C:\Program Files\NTCore\Explorer Suite\CFF Explorer.exe" %*
if not exist cff_error.txt exit /b 0

>&2 type cff_error.txt
exit /b 1

:vcvars
if "%VCVARS%" == "" (
  call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\vsdevcmd.bat" %*
) else (
  call "%VCVARS%" %*
)
goto :exit

@end

var format = WScript.Arguments(0);
WScript.Echo("Generating functions.h and import" + format + ".asm");

function fmt(format) {
  var i = 0;
  var args = Array.prototype.slice.call(arguments, 1);
  return format.replace(/\{(\d*)\}/g, function(_, x) { return args[x ? parseInt(x, 10) : i++]; });
}

var asm = [];
var header = "#pragma once\n\n#include \"base.h\"\n";

function f(ret, name, args, bytes) {
  asm.push({ name: name, bytes: String(bytes) });
  header += fmt("\n{} STDCALL {}({});\n", ret, name, args);
}

f("i32", "WriteFile", "size, void const*, i32, i32*, size", 20);
f("size", "GetStdHandle", "i32", 4);
f("i32", "SetConsoleOutputCP", "i32", 4);

var fso = WScript.CreateObject("Scripting.FileSystemObject");
fso.CreateTextFile("functions.h", true).Write(header);
fso.CreateTextFile("import" + format + ".asm", true).Write(function() {
  var is64 = format === "64";
  var dd = is64 ? "dq" : "dd";
  var gpa = is64 ? "get_proc_address" : "_get_proc_address@12";
  var n = is64 ? function(o) { return o.name; } : function(o) {
    return fmt("_{}@{}", o.name, o.bytes);
  };

  function x(f) {
    var string = "";
    var i = 0;
    var length = asm.length;
    for (; i !== length; ++i) {
      string += f(asm[i], i) + "\n";
    }
    return string;
  }

  var data = x(function(o) { return fmt("p_{} {} 0", o.name, dd); });
  var rdata = x(function(o) { return fmt("str_{} db \"{0}\", 0\nend_{0}:\n", o.name); });
  var globals = x(function(o) { return "global " + n(o); });
  var thunks = x(function(o) { return fmt("{} jmp [p_{}]", n(o), o.name); });
  var proc = x(function(o, i) {
    if (is64) {
      return fmt("{}  mov rdx, str_{}\n  mov r8, end_{1} - str_{1}\n  call {}\n  test rax, rax\n  je .fail\n  mov [p_{1}], rax\n", i === 0 ? "" : "  mov rcx, rbx\n", o.name, gpa);
    }

    return fmt("  push end_{} - str_{0}\n  push str_{0}\n  push ebx\n  call {}\n  test eax, eax\n  je .fail\n  mov [p_{0}], eax\n", o.name, gpa);
  });
  var prologue = is64 ? "  mov [rsp + 8], rbx\n  add rsp, -32\n  mov rbx, rcx" : "  push ebx\n  mov ebx, [esp + 8]";
  var epilogue = fmt("  xor eax, eax\n  {}\n\n.fail:\n  mov eax, 1\n  {0}", is64 ? "add rsp, 32\n  mov rbx, [rsp + 8]\n  ret" : "pop ebx\n  ret 4");
  var text = fmt("extern {}\n\nglobal load_imports\n\n{}\n{}\nload_imports:\n{}\n\n{}{}\n", gpa, globals, thunks, prologue, proc, epilogue);
  return fmt("[bits {}]\n[cpu {}]\n[default rel]\n\nsection .data\n\n{}\nsection .rdata\n\n{}section .text\n\n{}", format, is64 ? "x64" : "386", data, rdata, text);
}());
