#include "input.h"

inline int input_event_get_sec(struct input_event event) {
    return event.input_event_sec;
}

inline int input_event_get_usec(struct input_event event) {
    return event.input_event_usec;
}
