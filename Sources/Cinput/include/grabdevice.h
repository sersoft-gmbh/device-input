#ifndef _GRABDEVICE_H
#define _GRABDEVICE_H

#include "defines.h"

#define _CAN_GRAB _HAS_LINUX_INPUT
#if _CAN_GRAB
#define _GRAB_CONST
#define _GRAB_UNUSED
#else
#define _GRAB_CONST const
#define _GRAB_UNUSED __attribute__((unused))
#endif

extern inline _GRAB_CONST int grab_device(_GRAB_UNUSED int fd);
extern inline _GRAB_CONST int release_device(_GRAB_UNUSED int fd);

#endif
