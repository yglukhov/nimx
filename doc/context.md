Context
=======

WindowView
----------

Interfaces with window and graphics backend.

Each view has a graphics context.

TODO: The context may be unique or shared between windows depending on backend.

A view may need app data and backend data to properly initialize itself.

Some backends (js) do not currently support sharing between opengl contexts.


