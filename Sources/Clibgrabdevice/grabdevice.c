#include "grabdevice.h"

#if _CAN_GRAB
#include <sys/ioctl.h>
#include <linux/input.h>
#endif

inline _GRAB_CONST int grab_device(_GRAB_UNUSED int fd) {
#if _CAN_GRAB
	return ioctl(fd, EVIOCGRAB, 1);
#else
    return 0;
#endif
}

inline _GRAB_CONST int release_device(_GRAB_UNUSED int fd) {
#if _CAN_GRAB
    return ioctl(fd, EVIOCGRAB, 0);
#else
    return 0;
#endif
}
