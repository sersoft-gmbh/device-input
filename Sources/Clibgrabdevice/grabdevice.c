#include "grabdevice.h"

#if _CAN_GRAB
#include <sys/ioctl.h>
#include <linux/input.h>
#endif

static inline _GRAB_CONST int _perform_grab_action(_GRAB_UNUSED int fd, _GRAB_UNUSED int action) {
#if _CAN_GRAB
    return ioctl(fd, EVIOCGRAB, (void *)action);
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
