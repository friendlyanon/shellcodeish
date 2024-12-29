#include "base.h"
#include "functions.h"

static int output(size handle, struct string_view string)
{
#ifdef IS_ILP32
  i32 written = 0;
  if (WriteFile(handle, string.data, string.size, &written, 0) == 0
      || written != string.size)
  {
    return 1;
  }
#else
  i32 const max_i32 = 0x7FFFFFFF;
  for (;;) {
    i32 to_write = max_i32;
    _Bool more = 1;
    if (string.size <= (size)max_i32) {
      to_write = (i32)string.size;
      more = 0;
    }

    i32 written = 0;
    if (WriteFile(handle, string.data, to_write, &written, 0) == 0
        || written != to_write)
    {
      return 1;
    }

    if (!more) {
      break;
    }
    string.data += max_i32;
    string.size -= (size)max_i32;
  }
#endif

  return 0;
}

struct system_handles
{
  void const* instance;
  void const* ntdll;
  void const* kernel32;
};

int STDCALL entry(struct system_handles const* handles)
{
  (void)handles;

  if (SetConsoleOutputCP(65001) == 0) {
    return 1;
  }

  /* https://www.youtube.com/watch?v=Q55Uc2JCqo8 */
  STRING(message,
         "If you wish to make an apple pie from scratch you must first invent "
         "the universe "
         "\xf0\x9f\x8d\x8e\xf0\x9f\xa5\xa7\xf0\x9f\x8c\x8c"
         "\n");
  return output(GetStdHandle(-11),
                (struct string_view) {message, sizeof(message)});
}
