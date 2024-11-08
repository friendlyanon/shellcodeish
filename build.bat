@echo off

set now=%time:,=.%
echo Start build: %now: =0%>&2
call :build %*
set now=%time:,=.%
echo Finish build: %now: =0%>&2
exit /b %errorlevel%

:build
setlocal EnableDelayedExpansion

set arch=amd64
set format=64
set machine=x64
set cflags="/DSIZE_TYPE=long long" "/DUSIZE_TYPE=unsigned long long" "/DINT64_TYPE=long long" /DSTDCALL=
if "%1" == "32" (
  set arch=x86
  set format=32
  set machine=x86
  set cflags=/DSIZE_TYPE=int "/DUSIZE_TYPE=unsigned int" /DINT64_TYPE=__int64 /DSTDCALL=__stdcall /DIS_ILP32=1
)

if "%VSCMD_ARG_TGT_ARCH%" == "" (
  if "%VCVARS%" == "" set VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\vsdevcmd.bat
  call "!VCVARS!" -arch=%arch% -host_arch=amd64 -no_logo
  if not !errorlevel! == 0 exit /b !errorlevel!
) else if not !VSCMD_ARG_TGT_ARCH! == %machine% (
  echo vcvars has already been initialized for !VSCMD_ARG_TGT_ARCH!, but the build is targeting %machine%>&2
  exit /b 1
)

echo shellcodeish%format%.asm
nasm.exe -f win%format% shellcodeish%format%.asm
if not %errorlevel% == 0 exit /b %errorlevel%

set warnings=/w14165 /w44242 /w44254 /w34287 /w44296 /w44365 /w44388 /w44464 /w14545 /w14546 /w14547 /w14549 /w14555 /w34619 /w44774 /w44777 /w24826 /w14905 /w14906 /w14928 /W4
set conformance=/utf-8 /std:c17 /permissive- /volatile:iso /Zc:inline /we4213
set clargs=/nologo /GS- /Gs1000000000 /O2 /diagnostics:caret %warnings% %conformance% %cflags%
set linkargs=shellcodeish%format%.obj /machine:%machine% /out:shellcodeish%format%.exe /subsystem:console /stub:stub.bin /ignore:4060 /entry:pre_entry /opt:icf /opt:ref /emittoolversioninfo:no /emitpogophaseinfo /fixed /safeseh:no /align:16 /ignore:4108

cl.exe %clargs% main.c /link %linkargs%
if not %errorlevel% == 0 exit /b %errorlevel%

del main.obj shellcodeish%format%.obj
if exist cff_error.txt del cff_error.txt

call :cff clear_timestamp.cff shellcodeish%format%.exe
if not %errorlevel% == 0 exit /b %errorlevel%

if %format% == 64 (
  call :cff remove_pdata.cff shellcodeish64.exe
  if not !errorlevel! == 0 exit /b !errorlevel!
)

endlocal

exit /b 0

:cff
"C:\Program Files\NTCore\Explorer Suite\CFF Explorer.exe" %*
if not exist cff_error.txt exit /b 0

type cff_error.txt>&2
exit /b 1
