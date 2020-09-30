#include "input.h"

inline int input_event_get_sec(struct input_event event) {
#ifdef input_event_sec
    return event.input_event_sec;
#else
    return event.time.tv_sec;
#endif
}

inline int input_event_get_usec(struct input_event event) {
#ifdef input_event_usec
    return event.input_event_usec;
#else
    return event.time.tv_usec;
#endif
}
