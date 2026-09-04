#include "grabdevice.h"

#if _HAS_SYS_IOCTL
#include <sys/ioctl.h>
#endif

#if _HAS_LINUX_INPUT
#include <linux/input.h>
#else
// Copied from <linux/input.h>
#define EVIOCGRAB _IOW('E', 0x90, int)
#endif

static inline _GRAB_CONST int _perform_grab_action(_GRAB_UNUSED int fd, _GRAB_UNUSED int action) {
#if _CAN_GRAB
    return ioctl(fd, EVIOCGRAB, action);
#else
    return 0;
#endif
}

inline _GRAB_CONST int grab_device(_GRAB_UNUSED int fd) {
    return _perform_grab_action(fd, 1);
}

inline _GRAB_CONST int release_device(_GRAB_UNUSED int fd) {
    return _perform_grab_action(fd, 0);
}
