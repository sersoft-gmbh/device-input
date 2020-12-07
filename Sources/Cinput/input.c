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

inline void input_event_set_sec(struct input_event *event, int new_sec) {
#ifdef input_event_sec
    event->input_event_sec = new_sec;
#else
    event->time.tv_sec = new_sec;
#endif
}

inline void input_event_set_usec(struct input_event *event, int new_usec) {
#ifdef input_event_usec
    event->input_event_usec = new_usec;
#else
    event->time.tv_usec = new_usec;
#endif
}
