#ifndef INPUT_h
#define INPUT_h

#include "defines.h"

#if _HAS_LINUX_INPUT
#include <uapi/linux/input.h>
#else
// If we can't import the linux input header, we simply used the copied values form uapi/linux/input.h
#include <time.h>
typedef unsigned short __u16;
typedef __signed__ int __s32;

struct input_event {
#if (__BITS_PER_LONG != 32 || !defined(__USE_TIME_BITS64)) && !defined(__KERNEL__)
    struct timeval time;
#define input_event_sec time.tv_sec
#define input_event_usec time.tv_usec
#else
    __kernel_ulong_t __sec;
#if defined(__sparc__) && defined(__arch64__)
    unsigned int __usec;
    unsigned int __pad;
#else
    __kernel_ulong_t __usec;
#endif
#define input_event_sec  __sec
#define input_event_usec __usec
#endif
    __u16 type;
    __u16 code;
    __s32 value;
};
#endif

// The following teypdefs and 
typedef __u16 input_event_type;
typedef __u16 input_event_code;
typedef __s32 input_event_value;

extern inline int input_event_get_sec(struct input_event event);
extern inline int input_event_get_usec(struct input_event event);

#endif /* INPUT_h */
