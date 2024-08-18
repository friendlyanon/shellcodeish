typedef unsigned INT64_TYPE u64;
typedef INT64_TYPE i64;
typedef unsigned int u32;
typedef int i32;
typedef unsigned short u16;
typedef short i16;
typedef unsigned char u8;
typedef signed char i8;

typedef USIZE_TYPE usize;
typedef SIZE_TYPE size;

typedef int(STDCALL* proc)(void);

#define sizeof(x) ((size)sizeof(x))
#define countof(x) (sizeof(x) / sizeof(*(x)))
#define lengthof(s) (countof(s) - 1)

/* clang-format off */
#define STRING(name, str) \
  _Pragma("warning(suppress:4295)") \
  static char const name[lengthof(str)] = str
/* clang-format on */

struct string_view
{
  char const* data;
  size size;
};

static struct string_view sv(char const* data, size size)
{
  return (struct string_view) {data, size};
}

typedef i32(STDCALL* t_WriteFile)(size, void const*, i32, i32*, size);

static t_WriteFile p_WriteFile;

static int output(size handle, struct string_view string)
{
  if (string.size != 0) {
    i32 const max_i32 = 0x7FFFFFFF;
    while (1) {
      i32 to_write = max_i32;
      _Bool more = 1;
      if (string.size <= (size)max_i32) {
        to_write = (i32)string.size;
        more = 0;
      }

      i32 written = 0;
      if (p_WriteFile(handle, string.data, to_write, &written, 0) == 0
          || written != to_write)
      {
        return 1;
      }

      if (!more) {
        break;
      }
      string.size -= (size)max_i32;
    }
  }

  return 0;
}

proc STDCALL get_proc_address(void const* handle,
                              char const* name,
                              size length);

struct system_handles
{
  void const* instance;
  void const* ntdll;
  void const* kernel32;
};

typedef i32(STDCALL* t_SetConsoleOutputCP)(u32);

static int set_utf8_output(void const* kernel32)
{
  STRING(s_SetConsoleOutputCP, "SetConsoleOutputCP\0");
  t_SetConsoleOutputCP p_SetConsoleOutputCP =
      (t_SetConsoleOutputCP)get_proc_address(
          kernel32, s_SetConsoleOutputCP, sizeof(s_SetConsoleOutputCP));
  if (!p_SetConsoleOutputCP) {
    return 1;
  }

  return p_SetConsoleOutputCP(65001) == 0;
}

typedef size(STDCALL* t_GetStdHandle)(u32);

int STDCALL entry(struct system_handles const* handles)
{
  if (set_utf8_output(handles->kernel32) != 0) {
    return 1;
  }

  STRING(s_GetStdHandle, "GetStdHandle\0");
  t_GetStdHandle p_GetStdHandle = (t_GetStdHandle)get_proc_address(
      handles->kernel32, s_GetStdHandle, sizeof(s_GetStdHandle));
  if (!p_GetStdHandle) {
    return 1;
  }

  STRING(s_WriteFile, "WriteFile\0");
  p_WriteFile = (t_WriteFile)get_proc_address(
      handles->kernel32, s_WriteFile, sizeof(s_WriteFile));
  if (!p_WriteFile) {
    return 1;
  }

  /* https://www.youtube.com/watch?v=Q55Uc2JCqo8 */
  STRING(message,
         "If you wish to make an apple pie from scratch you must first invent "
         "the universe "
         "\xf0\x9f\x8d\x8e\xf0\x9f\xa5\xa7\xf0\x9f\x8c\x8c"
         "\n");
  return output(p_GetStdHandle((u32)-11), sv(message, sizeof(message)));
}
