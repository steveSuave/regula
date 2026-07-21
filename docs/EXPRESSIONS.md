# Expression language reference (text tool, Phase 58)

Everything you can write inside a `{…}` slot of a text. Content outside
braces is literal; each slot evaluates live against the construction and
re-renders as the referenced geometry moves. A slot whose value is
currently undefined — unknown name, wrong object kind, degenerate
geometry, division by zero, out-of-domain input — shows `?` and recovers
when the cause passes; the text itself never disappears and nothing ever
errors mid-drag.

Values render at a fixed 2 decimals (`5.00`), matching the measurement
labels. All angles — inputs to trig, outputs of `angle()` and the inverse
trig functions — are in **degrees**, matching the app-wide angle display.

Example: `perimeter = {dist(A,B) + dist(B,C) + dist(C,A)} cm`

## Literals, operators, constants

| Syntax | Meaning |
|---|---|
| `42`, `3.5`, `.5` | numbers (a trailing dot like `3.` is an error) |
| `+  -  *  /  ^` | arithmetic; `^` is power, right-associative (`2^3^2` = `2^(3^2)`) |
| `-x` | unary minus, binding looser than `^`: `-2^2` = `−4`, `(-2)^2` = `4`, `2^-3` works |
| `( … )` | grouping |
| `pi`, `π` | 3.14159… |
| `e` | 2.71828… |
| `× · ÷ −` | typed math symbols, accepted as `* * / -` |

There is no implicit multiplication: write `2*pi`, not `2π`.

`pi` and `e` are reserved words and win over objects with those names
when used bare (the lowercase auto-name pool does contain `e`). Inside a
geometry accessor the argument is always an object name, so `len(e)`
still reaches the circle named `e`.

## Geometry accessors (regula objects)

Arguments are **object names** as shown on the canvas / in the tree
(auto-names like `A`, `B`, `a`, `α`, or your renames) — never nested
expressions. A name that matches nothing is rejected in the dialog; a
name whose object is the wrong kind for the accessor renders `?`.
Texts themselves cannot be referenced.

| Function | Arguments | Value |
|---|---|---|
| `dist(P, Q)` | two points | distance between them |
| `len(s)` | a segment | its length |
| `len(c)` | a circle | its circumference (2πr) |
| `len(c)` | an arc | its arc length (r·sweep) |
| `len(c)` | a sector | its full perimeter (2r + r·sweep, both radii included) |
| `angle(A, V, C)` | three points | the angle at the middle point `V`, in degrees, always in [0, 180] (undirected — argument order doesn't matter beyond `V` being the vertex) |
| `area(p)` | a polygon | its area (absolute shoelace value; a self-intersecting outline reports the magnitude of its alternating region sum) |
| `area(c)` | a circle | its disc area (πr²) |
| `area(c)` | a sector | its wedge area (½r²θ) |
| `area(c)` | an arc | the circular segment its chord cuts off (½r²(θ − sin θ)) |
| `radius(c)` | a circle, arc or sector | the carrier radius |
| `perimeter(p)` | a polygon | the closed edge-loop length |
| `x(P)` | a point | its world x coordinate |
| `y(P)` | a point | its world y coordinate |

`len` and `area` deliberately mirror the Distance/Length/Area measurement
tools' semantics, so a text and a measurement over the same object always
agree. Infinite objects (lines, rays) have no `len`.

## Bare-name shorthand

Some objects read as a number directly, without an accessor:

| Bare name of a… | Reads as |
|---|---|
| segment | its length (`{g / 2}` = half the segment `g`) |
| measurement | its value (build on an existing distance/area measurement) |
| angle object | its degree measure |

Points, circles, polygons and loci have no single obvious number (a
circle could mean radius, circumference or area) and stay accessor-only —
a bare reference to one renders `?`.

## Numeric functions

| Function | Notes |
|---|---|
| `sqrt(x)` | `sqrt(-1)` → `?` |
| `sin(x)`, `cos(x)`, `tan(x)` | **x in degrees**: `sin(30)` = 0.5; composes with `angle()` |
| `asin(x)`, `acos(x)`, `atan(x)` | result in degrees: `atan(1)` = 45; out-of-domain input → `?` |
| `abs(x)` | |
| `round(x)`, `floor(x)`, `ceil(x)` | |
| `min(a, b, …)`, `max(a, b, …)` | two or more arguments |

Function names and argument counts are checked when you press OK in the
dialog, with a specific inline error; only the *values* can degrade to
`?` later.

Not in v1 (deliberately deferred, the registry is built to extend):
integrals and any symbolic algebra.
