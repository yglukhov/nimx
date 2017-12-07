Architecture overview
=====================

Views
-----

Everything that an app presents with nimx is organized in views. The base
type of all views is the `View`. All other controls, such as buttons, textfields,
tables inherit from it.

Window
------

`Window` type also inherits from `View` and represents
the actual OS window. For web platforms `Window` will represent a canvas on the
document. `Window` should be inherited from only if you wish to support another
platform.

Hiearchy
--------

The views in the window are organized in a hiararchy. E.g. a `Button` in a
`Window` is one of the *subviews* of that `Window`, and the `Window` is the
*superview* of the `Button`.

Layout
-------

The layout is defined by defining constraints between the views. Nimx provides
its [layout DSL](layout-dsl.md) to make it easier.

