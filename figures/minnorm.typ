// Explanatory figures for the min-norm estimator.
// Use with `#import "figures/minnorm.typ": *` and then `#fig-param-space` etc.
#import "@preview/cetz:0.4.2"

#let c-signal = rgb(31, 94, 160)
#let c-bias = rgb(194, 59, 31)
#let c-noise = rgb(214, 140, 20)
#let c-muted = luma(130)

#let right-angle(at, u, v, s: 0.16) = {
  import cetz.draw: *
  let p(a, b) = (at.at(0) + a * u.at(0) + b * v.at(0), at.at(1) + a * u.at(1) + b * v.at(1))
  line(p(s, 0), p(s, s), p(0, s), stroke: 0.5pt + c-muted)
}

// Parameter space, p = 2 and n = 1. One observation x'beta = y leaves a line
// of solutions; min-norm takes the point of it closest to the origin, which
// lies in the row space of X. The part of the true beta orthogonal to that
// row space is lost (bias); the noise moves the estimate along it (variance).
#let fig-param-space = cetz.canvas(length: 1.25cm, {
  import cetz.draw: *
  set-style(content: (padding: 0.08))

  let s5 = calc.sqrt(5)
  let u = (2 / s5, 1 / s5) // row-space direction
  let v = (-1 / s5, 2 / s5) // null-space direction
  let bstar = (0.5, 2.0) // true coefficients, x'beta* = 3
  let proj = (1.2, 0.6) // row-space part of beta*
  let bhat = (1.6, 0.8) // min-norm estimate, y = 4
  let other = (2.2, -0.4) // another interpolating solution

  // axes
  line((-0.9, 0), (3.0, 0), mark: (end: ">", fill: black), stroke: 0.6pt)
  line((0, -0.9), (0, 3.0), mark: (end: ">", fill: black), stroke: 0.6pt)
  content((3.0, 0), $beta_1$, anchor: "north-east")
  content((0, 3.0), $beta_2$, anchor: "north-west")

  // row space of X
  line((-0.8, -0.4), (2.9, 1.45), stroke: (paint: c-muted, thickness: 0.6pt, dash: "dotted"))
  content((2.9, 1.45), text(fill: c-muted, size: 7pt)[row space], anchor: "west")

  // set of interpolating solutions
  line((0.5, 3.0), (2.5, -1.0), stroke: 1.1pt + black)
  content((0.5, 3.0), text(size: 7pt)[$x^top beta = y$], anchor: "south-west")

  // smallest-norm ball touching the solution line
  circle((0, 0), radius: calc.sqrt(1.6 * 1.6 + 0.8 * 0.8), stroke: (paint: c-signal, thickness: 0.5pt, dash: "dashed"))

  // decomposition of the truth
  line(bstar, proj, stroke: (paint: c-bias, thickness: 1pt, dash: "dashed"))
  content(((bstar.at(0) + proj.at(0)) / 2, (bstar.at(1) + proj.at(1)) / 2), text(fill: c-bias, size: 7pt)[bias], anchor: "east", padding: 0.12)
  // drawn just below the row space so the estimate arrow does not hide it
  line((1.254, 0.493), (1.654, 0.693), mark: (start: "|", end: "|"), stroke: 1.2pt + c-noise)
  content((1.454, 0.593), text(fill: c-noise, size: 7pt)[noise], anchor: "north", padding: 0.1)
  right-angle(proj, (-u.at(0), -u.at(1)), v)
  right-angle(bhat, (-u.at(0), -u.at(1)), v)

  // vectors from the origin
  line((0, 0), bstar, mark: (end: ">", fill: c-bias), stroke: 0.9pt + c-bias)
  content(bstar, text(fill: c-bias)[$beta^*$], anchor: "south-east")
  line((0, 0), other, mark: (end: ">", fill: c-muted), stroke: 0.6pt + c-muted)
  content(other, text(fill: c-muted, size: 8pt)[$tilde(beta)$], anchor: "north-east")
  line((0, 0), bhat, mark: (end: ">", fill: c-signal), stroke: 1.1pt + c-signal)
  content(bhat, text(fill: c-signal)[$hat(beta)$], anchor: "south-west", padding: 0.12)

  circle(proj, radius: 0.04, fill: black, stroke: none)
  content(proj, text(size: 7pt)[$P beta^*$], anchor: "north-east", padding: (top: 0.22, right: 0.05))
  content((0, 0), text(size: 8pt)[$0$], anchor: "north-east")
})

// Observation space. With p < n the columns of X span a subspace, and OLS
// projects y onto it; the residual is what the model cannot reach. With
// p >= n the columns span the whole space, every y is reached exactly, and
// many coefficient vectors do it.
#let fig-obs-space = {
  let panel-under = cetz.canvas(length: 1.05cm, {
    import cetz.draw: *
    // the plane col(X), drawn as a parallelogram
    let a = (-0.4, -0.3)
    let b = (3.0, -0.3)
    let c = (3.8, 1.1)
    let d = (0.4, 1.1)
    line(a, b, c, d, close: true, fill: c-signal.transparentize(85%), stroke: 0.5pt + c-signal)
    content(c, text(fill: c-signal, size: 7pt)[$"col"(X)$], anchor: "north-east", padding: 0.12)

    let o = (0.3, 0.1)
    let yhat = (2.6, 0.6)
    let y = (2.6, 2.4)
    line(o, (1.6, -0.1), mark: (end: ">", fill: black), stroke: 0.7pt)
    content((1.6, -0.1), text(size: 7pt)[$x_1$], anchor: "north")
    line(o, (0.75, 0.95), mark: (end: ">", fill: black), stroke: 0.7pt)
    content((0.75, 0.95), text(size: 7pt)[$x_2$], anchor: "south-east")

    line(o, y, mark: (end: ">", fill: black), stroke: 0.9pt)
    content(y, $y$, anchor: "south")
    line(o, yhat, mark: (end: ">", fill: c-signal), stroke: 1.1pt + c-signal)
    content(yhat, text(fill: c-signal, size: 8pt)[$X hat(beta)$], anchor: "north-west")
    line(yhat, y, stroke: (paint: c-bias, thickness: 0.9pt, dash: "dashed"))
    content((2.6, 1.5), text(fill: c-bias, size: 7pt)[residual], anchor: "west")
    line((2.6, 0.78), (2.78, 0.78), (2.78, 0.6), stroke: 0.5pt + c-muted)
  })

  let panel-over = cetz.canvas(length: 1.05cm, {
    import cetz.draw: *
    let o = (0, 0)
    let x1 = (1.3, -0.15)
    let x2 = (0.35, 0.9)
    let x3 = (1.0, 0.75)
    let y = (2.3, 1.9)
    // y as two different combinations of the columns
    // path A: 1.149 x1 + 2.303 x2; path B: 2.204 x3 + 0.275 x2
    let a1 = (1.3 * 1.149, -0.15 * 1.149)
    line(o, a1, stroke: 0.8pt + c-signal)
    line(a1, y, mark: (end: ">", fill: c-signal), stroke: 0.8pt + c-signal)
    let b1 = (1.0 * 2.204, 0.75 * 2.204)
    line(o, b1, stroke: (paint: c-noise, thickness: 0.8pt, dash: "dashed"))
    line(b1, y, mark: (end: ">", fill: c-noise), stroke: (paint: c-noise, thickness: 0.8pt, dash: "dashed"))

    line(o, x1, mark: (end: ">", fill: black), stroke: 0.7pt)
    content(x1, text(size: 7pt)[$x_1$], anchor: "south")
    line(o, x2, mark: (end: ">", fill: black), stroke: 0.7pt)
    content(x2, text(size: 7pt)[$x_2$], anchor: "south")
    line(o, x3, mark: (end: ">", fill: black), stroke: 0.7pt)
    content(x3, text(size: 7pt)[$x_3$], anchor: "south-east")
    circle(y, radius: 0.05, fill: black, stroke: none)
    content(y, $y = X hat(beta)$, anchor: "south-west")
    content((1.3, -0.65), text(size: 7pt)[$"col"(X) = RR^n$, residual $= 0$])
  })

  grid(
    columns: 2,
    column-gutter: 1.2em,
    row-gutter: 0.6em,
    align: bottom + center,
    panel-under, panel-over,
    [(a) $p < n$: OLS], [(b) $p >= n$: interpolation],
  )
}
