import slider
export slider

import composition
import context
import font
import view_event_handling
import app

type ScrollBar* = ref object of Slider
    knobSize: float # Knob size should vary between 0.0 and 1.0 depending on
                    # shown part of document in the clip view. E.g. if all of
                    # the document fits, then it should be 1.0. Half of the
                    # document is 0.5.
