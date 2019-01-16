Layout DSL
==========

The layout DSL (for Domain Specific Language) is designed to help with common
use-case layout definitions. Here's an example:

```nim
import nimx / [ window, button, layout ]

let w = newWindow(newRect(50, 50, 400, 200))
let margin = 5.0

w.makeLayout:
    - Button:
        leading == super.leading + margin
        trailing == super.trailing - margin
        top == super.top + margin
        bottom == super.bottom - margin

        title: "Hello"
        onAction:
            echo "Action!"
```

`makeLayout` macro accepts the `View` as a first argument. This view is where
the layout should happen. The second argument is the body of the DSL, that
has the following syntax.

```
DSL ::= ViewConfiguration

ViewConfiguration ::= ViewConfigurationStatement*

ViewConfigurationStatement ::=
      "discard"
    | SubviewDefinition
    | PropertyDefinition
    | ConstraintDefinition

SubviewDefinition ::= "-" ( ViewType | ViewCreationExpression ) ( "as" Identifier )? ":" ViewConfiguration
PropertyDefinition ::= PropertyName ":" PropertyValue
ConstraintDefinition ::= ConstraintExpression (ConstraintPriority)?
```

- In the example above the `- Button:` and everything that follows is the `SubviewDefinition`.
`Button` is the `ViewType`. Note that the types have to be valid symbols in the
scope of layout definition, that's why the sample code imports `button`.

- `title: "Hello"` is the property definition of the button. If this button was
bound to a variable `myButton`, this would be equivalent to `myButton.title = "Hello"`.

- `onAction: ...` is also a property, but with a special rule. Properties
starting with "on" and uppercased third letter are treated as callback properties.
So this would expand to roughly:
```nim
myButton.onAction = proc() =
    echo "Action!"
```
If your callback takes arguments or returns something, you can use the do-notation:
```nim
- MyControl:
    onSomeEvent do(e: EventData) -> EventDataResult:
        echo "hi"
```

- `leading == super + margin` is a constraint definition, consisting of constraint
expression, and default priority. Constraint expression should always be one
of the following comparison expressions: `<=`, `==`, or `>=`. Constraint expression
can refer to the following "variables": `width`, `height`, `left`, `right`,
    `x`, `y`, `top`, `bottom`, `leading`, `trailing`, `centerX`, `centerY`,
    `origin`, `center`, `size`.

Some examples:
- `mySubView` should completely fill the `mainView`:
```nim
mainView.makeLayout:
    - View as mySubView:
        origin == super.origin
        size == super.size
```

- `mySubView` should be of size 20 by 20, and be centered within the `mainView`:
```nim
mainView.makeLayout:
    - View as mySubView:
        center == super.center
        width == 20
        height == 20
```

Note there's a special word `super` in the examples above. This is a placeholder
designating the superview of the currently defined view. There are other placeholders:
- `self` - the currently defined view
- `prev` - the previous sibling of the currently defined view
- `next` - the next sibling of the currently defined view


Note the pattern of `smth == super.smth` is pretty common, so there's a special
case to make it shorter:
```nim
mainView.makeLayout:
    - View:
        center == super
```
This works because the left side of the constraint expression consist of exactly
one identifier which is treated as subject. When `super`, `self`, `prev` or `next`
is met in the expression and it is not within the dot-expression, it is treated
as a dot expression with the subject.

If the left side of expression is not a single identifier then there is no
subject and thus such shortcut would not work:
```nim
mainView.makeLayout:
    - View:
        width + 20 == super # Will not compile
        width + 20 == super.width # Will compile
        width == super - 20 # Will compile
```


