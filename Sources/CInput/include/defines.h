#ifndef DEFINES_h
#define DEFINES_h

#if __has_include(<sys/ioctl.h>)
#define _HAS_SYS_IOCTL 1
#else
#define _HAS_SYS_IOCTL 0
#endif

#if __has_include(<linux/input.h>)
#define _HAS_LINUX_INPUT 1
#else
#define _HAS_LINUX_INPUT 0
#endif

#endif /* DEFINES_h */
