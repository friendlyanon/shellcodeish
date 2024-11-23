#pragma once

typedef unsigned long long u64;
typedef long long i64;
typedef unsigned int u32;
typedef int i32;
typedef unsigned short u16;
typedef short i16;
typedef unsigned char u8;
typedef signed char i8;

typedef unsigned SIZE_TYPE usize;
typedef SIZE_TYPE size;

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
