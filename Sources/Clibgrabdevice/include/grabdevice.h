#ifndef _GRABDEVICE_H
#define _GRABDEVICE_H

#if __has_include(<linux/input.h>)
#define _CAN_GRAB 1
#define _GRAB_CONST
#define _GRAB_UNUSED
#else
#define _CAN_GRAB 0
#define _GRAB_CONST const
#define _GRAB_UNUSED __attribute__((unused))
#endif

extern inline _GRAB_CONST int grab_device(_GRAB_UNUSED int fd);
extern inline _GRAB_CONST int release_device(_GRAB_UNUSED int fd);

#endif
