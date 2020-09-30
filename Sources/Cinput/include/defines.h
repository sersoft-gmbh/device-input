#ifndef DEFINES_h
#define DEFINES_h

#if __has_include(<linux/input.h>)
#define _HAS_LINUX_INPUT 1
#else
#define _HAS_LINUX_INPUT 0
#endif

#endif /* DEFINES_h */
