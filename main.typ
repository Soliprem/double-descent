#bibliography("bib.yaml", title: "References")

#import "@preview/frame-it:1.2.0": *
#import "@preview/game-theoryst:0.1.0": *
#import "@preview/quick-maths:0.2.1": shorthands

#set footnote(numbering: "<1>")
#set page(numbering: "1")

#show: shorthands.with(
  ($+-$, $plus.minus$),
  ($|-$, math.tack),
  ($=/>$, math.arrow.double.not),
  // avanti
)
#let succstar = $succ.eq^*$
#let ubt = $tilde(underline(beta))$
#let succeq = $succ.eq$
#let ux = $underline(x)$
#let uy = $underline(y)$
#let uz = $underline(z)$
#let uX = $underline(X)$
#let uY = $underline(Y)$
#let uZ = $underline(Z)$
#let ub = $underline(beta)$
#let uu = $underline(u)$
#let hb = $hat(beta)$
#let fs(bottom, top) = $sum_(bottom)^(top)$
#let isum(bottom, top) = $sum_(i=bottom)^(top)$
#let qs(top) = $sum_(i=1)^(top)$
#let un(variable) = $limits(variable)$
#let ul(variable) = $underline(variable)$
#let hl(variable) = $hat(underline(variable))$
#let SSR = "SSR"
#let SST = "SST"

#let nvec(..args) = {
  assert(args.pos().len() <= 1, message: "nvec accepts at most one argument")
  let variable = if args.pos().len() > 0 { args.pos().at(0) } else { $x$ }
  $vec(variable_1, dots.v, variable_j)$
}
#let nkmat(..args) = {
  assert(args.pos().len() <= 1, message: "nkmat accepts at most one argument")
  let variable = if args.pos().len() > 0 { args.pos().at(0) } else { $x$ }
  $mat(
     variable _(1,1), dots, variable _(1,k);
     dots.v, dots.down, dots.v;
     variable _(n,1), dots, variable _(n,k)
  )$
}

#let (example, feature, variant, syntax) = frames(
  feature: ("Feature",),
  // For each frame kind, you have to provide its supplement title to be displayed
  variant: ("Variant",),
  // You can provide a color or leave it out and it will be generated
  example: ("Example", gray),
  // You can add as many as you want
  syntax: ("Syntax",),
)
// This is necessary. Don't forget this!
#show: frame-style(styles.boxy)
#show: frame-style(kind: "hint", styles.hint)

// Possiamo definirne altri andando avanti se serve https://html-preview.github.io/?url=https://github.com/marc-thieme/frame-it/blob/assets/README.html

#let theorem = frame("Theorem", red)
#let definition = frame("Definition", teal)
#let axiom = frame("Axiom", green)
#let proof = frame("Proof", blue) // volevo il viola ma è troppo scuro
// #example[come usare il template][optional tag][
  // text
  // #divide()
  // oh wow a divider
// ] <tag>
// referencing.... @tag

#let definition(name, body, fill: gray) = {
  set align(left)
  rect(
    fill: fill,
    inset: 8pt,
    radius: 4pt,
    [#underline[*#name:*]\ #body],
  )
}

#import "@preview/graceful-genetics:0.2.0" as graceful-genetics
#import "@preview/wordometer:0.1.4": word-count, total-words
#import "figures/minnorm.typ": fig-param-space, fig-obs-space
#set heading(numbering: "1.")

#total-words
#show: graceful-genetics.template.with(
  title: [An Assessment of Minimum-Norm for Double Descent and Benign Overfitting using Synthetic Data],
  authors: (
    (
      name: "Francesco Prem Solidoro",
      department: "Economics Department",
      institution: "University of Bologna",
      city: "Bologna",
      country: "Italy",
      mail: "francesco.solidoro@studio.unibo.it",
    ),
    (
      name: "Michele Salvi",
      department: "Economics Department",
      institution: "University of Bologna",
      city: "Bologna",
      country: "Italy",
      mail: "michele.salvi4@studio.unibo.it",
    )
  ),
  make-venue: move(dy: -1.9cm, {
  box(rect(fill: rgb(194, 59, 31), inset: 10pt, height: 2.5cm)[
    #set text(font: "TeX Gyre Pagella", fill: white, weight: 700, size: 20pt)
    #align(bottom)[BOLOGNA]
  ])
  set text(22pt, font: "TeX Gyre Pagella")
  box(pad(left: 10pt, bottom: 10pt, [ALMA MATER STUDIORUM]))
}),
  make-title: (
    title,
    authors,
    abstract,
    keywords,
  ) => {
    set par(spacing: 1em)
    set text(font: "TeX Gyre Heros")

    par(
      justify: false,
      text(24pt, fill: rgb("004b71"), title, weight: "bold"),
    )

    text(
      12pt,
      authors
        .enumerate()
        .map(((i, author)) => box[#author.name #super[#(i + 1)]])
        .join(", "),
    )
    parbreak()

    for (i, author) in authors.enumerate() [
      #set text(8pt)
      #super[#(i + 1)]
      #author.institution,
      #link("mailto:" + author.mail) \
    ]
    v(8pt)

    set text(10pt)
    set par(justify: true)
    if abstract != none and abstract != [] {
      [
        #heading(outlined: false, bookmarked: false)[Abstract]
        #text(font: "TeX Gyre Pagella", abstract)
        #v(3pt)
      ]
    }

    if keywords.len() > 0 [
      *Keywords:* #keywords.join(text(font: "TeX Gyre Pagella", "; "))
    ]
    v(18pt)
  },
  date: (
    year: 2025,
    month: "June",
    day: 3,
  ),
  keywords: (),
  abstract: [
    Overparameterised models can interpolate noisy data and still predict well. Using simulated data, we study when this holds for the minimum-norm least squares estimator, and how much its coefficients can then be interpreted. We vary the number of features, their factor structure, the placement and signs of the signal, and the signal-to-noise ratio, and compare min-norm with ridge, lasso and post-lasso, computing prediction risk exactly from the population covariance. Overparameterisation makes the noise nearly harmless in every design, but the bias remains, and depends on whether the signal lies along a few strong factors: min-norm recovers 97.5% of an aligned dense signal, and 3.6% of a sparse one with independent features, while interpolating in both. Good prediction does not imply readable coefficients: min-norm spreads effects across correlated features, so factor totals remain interpretable while individual coefficients do not. Per-coefficient tests over-reject when scaled by the noise level, because of leakage between coefficients; scaling by the spread of the outcome controls the error rate, but power, coverage and false discoveries remain problems.

  ],
)

#outline(depth: 2)
= Introduction
Can we evaluate the min-norm estimator's performance in forecasting and inference?
 
We set out to use synthetic data to better understand this and Double Descent in a regime of benign overfitting. The main question is best summarised as "what underlying structure in the data allows us to use a min-norm estimator to obtain a useful double descent as parameters grow?". We find that for forecasting (as expected), min-norm works best when the signal lies along a few strong factors. For inference, scaling the tests by the spread of the outcome keeps each test at its nominal error rate, but the intervals can miss the true effect, and with thousands of features most of the discoveries are false.

== Double Descent
Double Descent as a topic expands the classical notion of the bias-variance trade-off, highlighting that increasing model complexity does not necessarily lead to an increasing generalization error.
Every model can be characterized via the following regimes:
- Underparametrized $p<n$, where increasing complexity reduces bias
- At the Interpolation Threshold $p=n$, where we observe high test error due to the increasing estimation variance
- Overparametrized $p>n$ where test error may decrease again due to the availability of parameters

During the "second" descent, the estimator still interpolates the training observations, while (possibly) maintaining good predictive performance. This is defined as *Benign Overfitting*. @belkin2019


= Methods


== Min-norm

The min-norm estimator is in some ways an extension of the OLS estimator for high dimensions. When p (dimensions of parameters) is greater than n (dimensions of observations), OLS becomes underdetermined, yielding infinite possible solutions. Min-norm simply picks the solution having the smallest norm. This is best understood if we observe the estimator as creating a vector in the space of parameters. OLS alone picks a vector β that, when transformed through the application of the matrix of the data X, is closest to the vector of observations Y. 

#figure(
  fig-obs-space,
  caption: [The fit seen from the observations. With $p < n$ the columns of $X$ span only a subspace, and OLS projects $y$ onto it. With $p >= n$ they span everything, so $y$ is reached exactly, and in more than one way.],
) <fig-obs-space>

Since when $p>n$, there's an excess in degrees of freedom, we use min-norm to collapse most of them. Since the degrees of freedom being shrunk won't necessarily be orthogonal to all dimensions of the data, there's some bias being introduced, alongside shrinkage of errors. It's important to note that, while there's obviously some element of bias /*#footnote[even ignoring the fact that we can show there's bias in this specific estimator, we know by Guass Markov that, since this is a linear model, if it were unbiased and have minimum variance, it'd have to be the OLS. This is not the OLS, so it can't both have minimum variance and unbiasedness.] DA RIVEDERE NON PROPRIO CORRETTO bc GM non si applica per p > n perchè richiede full rank X*/, noise only moves $hb$ along n of the p dimensions in the model. This means that, even if we can't eliminate all of the bias, we can spread the noise incredibly thin, being immersed in many $p >> n$ dimensions, the n noise values can be fitted with very small coefficients.

#figure(
  fig-param-space,
  caption: [Min-norm in parameter space, with $p = 2$ and $n = 1$. Every point on the line fits the data perfectly. Min-norm picks the one closest to the origin, which lies in the row space of $X$. It keeps the part of $beta^*$ along the row space (shifted by noise) and sets the orthogonal part to zero, which is the bias.],
) <fig-param-space>

Then, as the prediction error for a new observation is $ x_0^T (hat(beta) - beta^*)$
and assuming that the test observation has covariance $Sigma$ we can get an expression for the conditional prediction error, averaged over test observations:
$ R(hat(beta)) = (hat(beta) - beta^*)^T Sigma(hat(beta) - beta^*   )  $

As we saw in the lectures, min-norm is the limit of ridge as $lambda -> 0$. 
Minimum norm selects the following solution:
$ hat(beta)_"min" = arg min_beta norm(beta)_2^2 quad "s.t." quad X beta = y $


The closed form solution#footnote[ can also be stated as $ hat(beta)_"min" = X^T (X X^T)^(-1) y$], using the Moore-Penrose pseudoinverse #footnote[which doesn't require X full rank] can be obtained as
$
hb = X^dagger y =  X^T (X X^T)^(-1) y
$

== Benign Overfitting
As shown in @bartlett2020 // cite Bartlett et al : https://www.pnas.org/doi/10.1073/pnas.1907378117
the covariance structure of the regressor matrix matters greatly for the prediction error.

Considering the eigendecomposition $ Sigma = V bold(Lambda) V^T $ where $bold(Lambda) = "diag"(lambda_1, ..., lambda_p)$ we can consider the eigenvectors of $Sigma$ as directions in the feature space while their associated eigenvalues describe observation variance in those directions.

Then considering the true parameter vector $theta^* = V^T beta^*$ and substituting into the expression for conditional prediction error stated before, we get that:
$
R(hat(beta)) = (hat(beta) - beta^*)^T V bold(Lambda) V^T (hat(beta) - beta^*) \
= norm(bold(Lambda)^(1/2)V^T (hat(beta) - beta^* ))^2 \
= sum_(j = 1)^p lambda_j (hat(theta)_j - theta^*_j)^2
$

with
$
hat(theta) = V^T hb
$

Hence estimation errors along directions with higher eigenvalue (higher variance) are very costly in terms of predictions, unlike errors in low-variance directions.

Contextualizing this with the minimum norm estimator, it can recover the most important directions well, while errors in directions with lower eigenvalues have lower consequences in prediction:

If the signal is concentrated in high variance directions the estimator recovers the meaningful directions well and errors in other directions bear little effect on prediction.

Instead if the signal is concentrated in low variance directions the minimum norm estimator fails to capture the true signal, even if it accounts for relatively little variance, which creates prediction bias.  

This distinction allows us to analyse directly the estimator's performance according to the varying effects stated above.

At the same time, if the tail is large and flat, noise is rendered harmless, as it's spread over many small eigenvalues.





== Data Generation

We parametrise data generation around several parameters:
- Spectrum characteristics (i.e. how many spikes there are in the spectrum, and how relevant they are)
- support  (sparse v grouped v dense)
- signs, i.e. if effects load onto the spikes or cancel them. This allows to test whether min-norm has a blind spot for low-variance factors.
- signal-to-noise ratio

To generate the data, we assign features randomly to one of K factors. Then $x_j = sqrt(1-rho) dot e_j + sqrt(rho) dot f_(g(j))$ with e and f being standard normals. This yields unit variance, correlation $rho$ within a factor and 0 between factors, and covariance $Sigma = (1-rho) I + rho sum_g bold(1)_g bold(1)_g^T$. This naturally generates K spikes of size $1-rho + rho dot p slash K$, over $p- K$ tail eigenvalues equal to $1-rho$. For example $rho=0.7, K=50$ at $p=2000$, the spikes are about 28.

Then depending on the choice of sparsity, we choose the features we use to generate the data.
- sparse $=>$ 10 features are chosen at random, scattered across factors
- grouped $=>$ 10 features are chosen, packed into as few factors as possible (usually one)
- dense $=>$ all p features are chosen

Then we decide whether to set all effects to +1 or to alternate between +1 and -1 within each factor#footnote[this leads to effects canceling out for factors with even numbers of features], normalise by rescaling $beta$ so that $beta^T Sigma beta = 1$, and build the dataset with

$
y = X beta + epsilon
$

with $epsilon ~ N(0, 1 slash "SNR")$

It's important to note that min-norm is defined only by lengths: it picks the perfect fit closest to the origin. Rotating the axes leaves lengths unchanged, so it simply rotates the fit with them; in @fig-param-space, the ball is round and has no preferred direction. What matters to min-norm is therefore where $beta^*$ lies relative to the directions of the data, not which of its coordinates are zero. The "ball" of lasso, instead, is a diamond with its corners on the axes, which is exactly why it finds zeros in the original coordinates."

== Benchmarks

We compare results obtained with min-norm with results coming from Ridge, Lasso, Post-lasso and OLS performed on the true active features (let's call it the "Oracle" model, for brevity). 

The Oracle is a baseline comparison for the best possible attainable model of the signal.

With a dense support, the active features are the whole of $X$, so the Oracle just reduces to min-norm, therefore we only use it as a benchmark for sparse and grouped supports.

Within a seed, all estimators share the same cross-validation folds, so differences between them do not come from different splits.

=== Ridge and min-norm 
We stated above that min-norm estimator is the Ridge estimator's limit. Expanding on that, we see that ridge regression solves:
$ hat(beta)_lambda = arg min_beta { norm(y - X beta )_2^2 + lambda norm(beta)_2^2} $
And its solution is:
$ hat(beta)_lambda = (X^T X + lambda I)^(-1) X^T y $
Connecting this with the minimum norm estimator's context, i.e. when $ p > n$ and $X$ full rank we can take $lambda$'s limit#footnote[the limit must be taken from positive parameters, as at $lambda = 0$ the original normal-equation matrix is singular] to show that
$ lim_(lambda  -> 0^+)hat(beta)_lambda = X^T (X X^T)^(-1) y  $
Which is the min-norm estimator in its non Moore-Penrose formulation, the zero-regularization limit of Ridge.

As such, Ridge is a natural benchmark for min-norm due to their relationship and the key difference of ridge allowing residual training error (to reduce variance) while min-norm forces training data interpolation. \
Additionally, Ridge is well suited to estimation of dense signals, due to its $L^2$ penalty, fitting for the dense configurations generated. Furthermore, since we introduce by construction correlated regressors, ridge reduces their influence and prevents the noise amplification found in similar cases with OLS estimates

In our example, we tune Ridge with 5-fold cross-validation over 60 penalties, ranging from $10^(-10) "to" 10$ times the largest squared singular value of X. The value of this benchmark is in estimating the cost of interpolation compared with optimal shrinkage. // duh

=== Lasso and Post-Lasso
LASSO, differently from Ridge, introduces the assumption of the underlying parameter vector being sparse. It solves:
$ hat(beta)_"LASSO" = arg min_beta {1/(2n )norm(y - X beta)^2_2 + lambda norm(beta)_1} $
It shrinks coefficients with a $L^1$ penalty, setting some individual coefficients to exactly zero.

It is immediately understood that minimum-norm handles badly such information, as only a small share of the features is actually involved in the data generation process, as min-norm chooses the solution with the smallest $L^2$ norm and does not single out irrelevant variables.

We use LASSO as a benchmark mainly for our sparse and grouped setups, where we are able to investigate compatibility behind the model's underlying assumptions and the true data generating process, while considering LASSO's difficulties in variable selection among highly correlated features.

Post-LASSO is LASSO's natural extension, and acts as follows:
- LASSO is run to conduct variable selection
- OLS is run on the selected variables, effectively foregoing penalization

Formally, considering the support $ hat(S) = {j: hat(beta)_("LASSO"j) != 0} $ post-LASSO estimates:
$ hat(beta)_("P-L") = arg min_(beta: beta_j = 0, j in.not hat(S) ) norm(y - X beta)^2_2 $
This solves the potential shrinkage bias introduced by LASSO, but may reintroduce variance if too many variables are selected.

// possible post lasso citation Belloni and Chernozhukov (2013) (if needed, idk tho): https://dspace.mit.edu/entities/publication/3c5d4faf-664e-4d65-9483-94eaf136ab09

In our examples these specifications act as benchmark, mainly interesting in the sparse and grouped scenarios, to compare with min-norm in a setting that antagonizes it by construction.

We tune Lasso with 5-fold cross-validation and no intercept, and post-lasso by running the cross-validation on the loss of the refit done via OLS. Refits that would interpolate or are rank deficient are excluded.

As inference is likely unfeasible due to the uncertainty introduced by the variable selection step, as OLS does not eliminate it, we limit it to "parameter recovery" // found a paper by belloni, Hansen and Charnozhukov on post double selection, but is out of scope here imo
, via coefficient estimation error
$ R_"coef" = norm(hat(beta) - beta^*)^2_2 $

=== Pre-Preparation
Both Ridge and LASSO are scale-sensitive, but due to us using a synthetic dataset, regressors are already standardized. \ Additionally we ensure that the selected LASSO specification is able to be estimated via OLS, i.e. the selected matrix must have full column rank and restricts regressors to $ k < n$ 

== Evaluation

To trace the double-descent curve, we also fit min-norm on nested prefixes of the features: the first $k$ columns of the same $X$, for $k$ from $0.1 n$ up to $p$, sampled densely around $k = n$. Features are assigned to factors at random, so each prefix is a representative subset of the design. For $k < p$ the fitted model leaves out part of the signal, so only at $k = p$ is it correctly specified; all results other than the curves refer to $k = p$.

Since we generate the data, we know $Sigma$ and $beta^*$, and can compute the risk $R(hb)$ exactly instead of estimating it on a test set. Because $beta^(* T) Sigma beta^* = 1$, the risk is a share of the signal, and we report

$
R^2_"signal" = 1 - R(hb)
$

When comparing estimators, we treat differences in $R^2_"signal"$ below 0.05 (five percentage points of the signal) as negligible.

To see where the error comes from, we can substitute $y = X beta^* + epsilon$ into $hb = X^dagger y$, and split the expected risk given $X$ in two:

$
B = R(X^dagger X beta^*), quad V = sigma^2 "tr"(X^(dagger T) Sigma X^dagger)
$

$B$ is the risk of noiseless fit, i.e. the part of $beta^*$ that falls outside of the row space in @fig-param-space. On top of that, the noise adds $V$. Benign overfitting, in these terms, means that $V$ collapses when compared to the signal's magnitude as $p$ grows.

Prediction says very little about whether the coefficients *mean* anything, so we also compare $hb$ with $beta^*$ directly. The cosine of the angle between them measures whether $hb$ points the right way, ignoring scale. Top precision is the share of the ten largest coefficients (in absolute value) that are truly active, and is undefined for dense supports. The factor cosine is the same cosine computed on the within-factor totals $sum_(j in g) beta_j$: when correlated features can't be told apart, it measures whether we at least get right what each factor does.

Inference is harder to assess. Given $X$, each coefficient is normal, 
$ hb_j ~ N(P_(j j) beta^*_j + sum_(k != j) P_(j k) beta^*_k, space sigma^2 norm(r_j)^2), $
where $P = X^dagger X$ and $r_j$ is the $j$-th row of $X^dagger$. The sum is leakage: the effects of other features bleeding into coefficient $j$. We reject $beta^*_j = 0$ when $abs(hb_j) > 1.96 dot s norm(r_j)$, for two choices of the scale $s$. The first is the true noise level $sigma$, which is not available in practice (an interpolating fit leaves no residuals to estimate it from) and ignores leakage entirely. The second is the root mean square of $y$, which is available and charges the leakage as noise. For each, we report the rejection rate on null features (type I error), on active features (power), and the coverage of the interval around $hb_j slash P_(j j)$, which undoes the attenuation.

All results are medians over 20 seeds.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    inset: (x: 4pt, y: 3pt),
    table.hline(),
    table.header([*Factor*], [*Levels*]),
    table.hline(stroke: 0.5pt),
    [Overparameterisation $p slash n$], [2, 5, 20],
    [Spectrum $(rho, K)$], [isotropic $(0, 1)$, $(0.3, 5)$, $(0.7, 5)$, $(0.3, 50)$, $(0.7, 50)$],
    [Support], [sparse, grouped, dense],
    [Signs], [aligned, contrast],
    [SNR], [1, 4, 16],
    table.hline(stroke: 0.5pt),
    table.cell(colspan: 2)[Fixed: $n = 100$, 10 active features (sparse and grouped), 20 seeds per scenario. \ Full factorial: $3 times 5 times 3 times 2 times 3 = 270$ scenarios.],
    table.hline(),
  ),
  caption: [Simulation design.],
) <tab-design>

= Results
== Double Descent

#figure(placement: auto, scope: "parent",  image("figures/curves.png"), caption: [the log scale hides it, but the blue line is roughly the sum of the values of the orange and green lines, in accordance with the theoretical result saying that $E[R] = B + V$]) <fig-curves>

As expected, excess risk peaks at $n = p$ in every panel of @fig-curves, where the theoretical result diverges for variance, and then comes back down. Bias diverges because each prefix leaves out part of the signal, which enters $y$ like noise and is amplified by the pseudoinverse in the same way.

While both bias and variance fall back down on the right side of panels, variance only descends back to underparametrised levels when the data was generated from few factors or isotropy, regardless of whether the signal is contrasted or aligned, or in the case of isotropic data and a sparse signal. That leaves the case with many factors and a scattered signal; in this case, since noise can't be spread across the tail, each spike costs about $sigma^2 slash n$ of variance. With $K=50$ spikes, the floor is $K /n sigma^2 = 0.5 times 0.25 approx 0.125$, which is quite close to the observed 0.110 and is the $k slash n$ term in the bound of @bartlett2020.

The advantage of overparametrisation, in this experiment, only comes out through an analysis of the bias: on the left bias comes mostly from omitted features, while at $k = p$ nothing is omitted, and what's left is the min-norm's own bias. When the signal lies on the spikes, bias ends well below its underparametrised level (0.24 vs 0.04 with few factors, 1.03 vs 0.44 with many factors). When it lies in the tail, or there are no spikes at all, bias returns to about one, i.e. it's as good as predicting zero.

== Prediction
#figure(
  placement: auto, scope: "parent",
  image("figures/prediction.png"),
  caption: [Share of the signal recovered by min-norm ($R^2_"signal"$) in every scenario at SNR 4, medians over 20 seeds. Rows go from isotropic (bottom) to few, strong spikes (top).],
) <fig-prediction>

#figure(
  placement: auto, scope: "parent",
  image("figures/tradeoffs.png"),
  caption: [One point per scenario, coloured by $p slash n$. From the left: share recovered against the share of the signal on the spikes; min-norm against tuned ridge; coefficient cosine and factor-total cosine against share recovered.],
) <fig-tradeoffs>

@fig-prediction is best read from the bottom. Under isotropy min-norm doesn't recover much, and what it recovers disappears as $p$ grows: 0.26 at $p slash n = 2$, 0.04 at $p slash n = 20$. The variance collapses, but the fit, which finds roughly $n slash p$ of the signal, is pretty much useless. Going up, we can see that correlation changes this only when the signal is aligned with the factors: aligned columns improve as the spikes become fewer and stronger, while contrast columns fall to zero or even below#footnote[reminder: a negative recovered signal means that our prediction is worse than simply predicting 0].

What these cases have in common is where the signal is found. At $p slash n = 20$ and SNR 4, $R^2_"signal"$ correlates 0.94 with the share of the signal lying on the spikes (left panel of @fig-tradeoffs, excluding the isotropic rows, which have no spikes). @tab-headline shows the extremes.

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: 7,
    align: (left, left, left, right, right, right, right),
    stroke: none,
    inset: (x: 3pt, y: 2.5pt),
    table.hline(),
    table.header([*Spectrum*], [*Support*], [*Signs*], [*On spikes*], [*Min-norm*], [*Ridge*], [*Lasso*]),
    table.hline(stroke: 0.5pt),
    [$rho = 0.7, K = 5$], [dense], [aligned], [1.00], [0.975], [0.983], [0.922],
    [$rho = 0.7, K = 5$], [grouped], [aligned], [0.96], [0.932], [0.938], [0.919],
    [$rho = 0.7, K = 5$], [sparse], [aligned], [0.87], [0.830], [0.836], [0.818],
    [$rho = 0.7, K = 50$], [dense], [aligned], [1.00], [0.819], [0.819], [0.444],
    [$rho = 0.7, K = 5$], [sparse], [contrast], [0.32], [0.309], [0.306], [0.504],
    [isotropic], [sparse], [--], [--], [0.036], [0.035], [0.396],
    [$rho = 0.7, K = 5$], [dense], [contrast], [0.00], [-0.010], [0.000], [0.000],
    [$rho = 0.7, K = 50$], [dense], [contrast], [0.00], [-0.440], [0.000], [0.000],
    table.hline(),
  ),
  caption: [Share of the signal recovered at $p slash n = 20$ and SNR 4, medians over 20 seeds. "On spikes" is the share of the signal variance lying along the spikes.],
) <tab-headline>

These results are in line with the findings of @bartlett2020: min-norm works best with few factors relative to $n$, a signal aligned with them, and $p$ well above $n$, so that a large, flat tail can absorb the noise.

== Interpolation

Ridge contains min-norm as its limit, so the gap between the two is what choosing $lambda > 0$ causes. At $p slash n = 20$ that makes little difference: in 70 of the 90 scenarios, the $R^2_"signal"$ of min-norm is within 0.05 of tuned ridge's, and in none the former beats the latter by more (second panel of @fig-tradeoffs). Interpolation is costly in two situations. 
- Close to the threshold, with little signal, the variance is still large and ridge shrinks it away: at $p slash n = 2$ and SNR 1, ridge is ahead by a median of 0.70. 
- When the signal lies in the tail of a correlated design, ridge falls back to predicting zero, while min-norm cannot: 23 of the 90 scenarios at $p slash n = 20$ do worse than zero.

Lasso is a different matter. At $p slash n = 20$ it beats min-norm by more than 0.05 in the $R^2_"signal"$ in 57 of the 90 scenarios, and loses by as much in 12. Min-norm wins where the signal is dense and aligned (0.819 against 0.444 at $rho = 0.7, K = 50$), and lasso everywhere else, most clearly on sparse signals under isotropy (0.396 against 0.036). This is the effect of invariance w.r.t. rotation of min-norm: which coefficients are zero means very little to it, while it's what lasso looks for.

== Coefficients

#figure(
  placement: auto, scope: "parent",
  image("figures/coefficients.png"),
  caption: [Top: cosine between min-norm's coefficients and the true effects. Bottom: the same cosine on within-factor totals, undefined without correlation or when the true totals cancel. SNR 4, medians over 20 seeds.],
) <fig-coefficients>

Prediction and readability of the coefficients pull in opposite directions. Where prediction is best, individual coefficients are worst: with $rho = 0.7, K = 5$ and a grouped, aligned signal, min-norm recovers 0.932 of the signal, but its coefficients have a cosine of 0.115 with the truth, and only one of the ten largest is truly active. Min-norm spreads an effect evenly over correlated features, so ten active features out of a factor of 400 become 400 small coefficients. Under isotropy the cosine follows $sqrt((n slash p) dot "SNR" slash (1 + "SNR"))$ (0.20 at $p slash n = 20$, SNR 4). In short, the overparameterisation that removes the variance also scrambles the direction of the coefficients.

Three things remain readable. Factor totals are recovered almost perfectly with few factors (a cosine of 0.95 to 0.995 at $rho = 0.7, K = 5$), including where individual coefficients fail, and less well with many (0.78 to 0.91 at $rho = 0.7, K = 50$). Effects spread over whole factors are where min-norm's even spreading is correct: at $rho = 0.7, K = 50$ and $p slash n = 5$, the ten active features of a grouped signal are exactly one factor, and min-norm reaches a cosine of 0.594 with all ten largest coefficients active. This, however, is more of a match than a merit of min-norm: min-norm spreads the coefficients, but since they're already spread, that is not an issue. All 18 scenarios with both $R^2_"signal" >= 0.7$ and a cosine of at least 0.5 have aligned signs. Finally, signs are right on sparse signals (0.99 on average, against 0.68 on dense ones), since min-norm never sets an effect to zero.

For individual effects on sparse signals, lasso remains the better tool (a cosine of 0.87 against 0.40 under isotropy at SNR 4, median over $p slash n$). Min-norm is best read at the level of factors, and at the level of features only when effects plausibly spread over whole factors.

== Inference

#figure(
  placement: auto,
  scope: "parent",
  table(
    columns: 6,
    align: (left, right, right, right, right, right),
    stroke: none,
    inset: (x: 3pt, y: 2.5pt),
    table.hline(),
    table.header(
      [], table.cell(colspan: 2)[*Type I, $s = sigma$*], table.cell(colspan: 3)[*Scaled by the spread of $y$*],
    ),
    table.hline(stroke: 0.3pt, start: 1),
    [*Spectrum*], [SNR 4], [SNR 16], [Type I], [Power], [Coverage],
    table.hline(stroke: 0.5pt),
    [isotropic], [0.37], [0.63], [0.040], [0.55], [0.99],
    [$rho = 0.3, K = 50$], [0.32], [0.58], [0.031], [0.55], [0.85],
    [$rho = 0.7, K = 50$], [0.23], [0.45], [0.019], [0.42], [0.83],
    [$rho = 0.3, K = 5$], [0.28], [0.53], [0.021], [0.41], [0.99],
    [$rho = 0.7, K = 5$], [0.21], [0.40], [0.014], [0.26], [0.99],
    table.hline(),
  ),
  caption: [Per-coefficient 95% tests at $p slash n = 20$, means over supports and signs (type I excludes dense supports, which have no null features). The last three columns are at SNR 4. Nominal level 0.05.],
) <tab-inference>

Testing individual coefficients needs a scale for their noise.

Scaling by the true noise level $sigma$ ignores leakage, the effects of other features bleeding into each coefficient, and rejects far too often (@tab-inference), making it unfit for our purposes. Under isotropy the false rejection rate is 0.37 at SNR 4 and 0.63 at SNR 16, which is what leakage predicts: if it acts as extra noise of variance $"SNR" dot sigma^2$, the test statistic is $N(0, 1 + "SNR")$ instead of $N(0, 1)$, and $P(abs(N(0, 1 + "SNR")) > 1.96)$ is 0.38 and 0.64.

Scaling by the spread of $y$ charges the leakage as noise, and needs no estimate of $sigma$, which matters since an interpolating fit leaves no residuals to estimate it from. It holds the level in every one of the 270 scenarios (at most 0.047), and is conservative with correlated features. Power (rejecting truly active features), however, is highest where prediction is worst: 0.55 under isotropy against 0.26 at $rho = 0.7, K = 5$, where min-norm spreads each effect over a whole factor.

There's still two problems:
- The tests answer whether an effect is zero, but the intervals do not reliably say how large it is. Coverage falls to about 0.83 with many factors, and to 0.5 in the whole-factor case of the previous section: there the estimates are clearly away from zero, so the tests reject correctly (power 0.9, no false rejections), but they are systematically off, and the intervals around them miss the true value half the time.
- A 5% error rate per test still adds up over many tests. Under isotropy at $p slash n = 20$, a false rejection rate of 0.04 over 1,990 null features gives about 80 false discoveries, against about 8 true ones: nine in ten features flagged as significant would have no effect. Any practical use of these tests would need a multiple-testing correction on top.

= Conclusions

We investigated what structure in the data lets min-norm interpolate noisy data and still predict well, and how much its coefficients can then tell us.

For prediction, the answer is in the placement of the signal: overparameterisation makes the noise almost harmless in every design we tried, but it does nothing for the bias, and the bias depends on whether the signal lies along the few strong directions of the data. With a few strong factors and a signal aligned with them, min-norm recovers almost all of the signal at $p slash n = 20$, and interpolating costs almost nothing against tuned ridge. With the same factors and a contrast signal, or with no factors at all, it interpolates just as harmlessly and recovers next to nothing. Benign, in other words, is not the same as useful. Even where it works, lasso is usually the better predictor: min-norm wins only when the signal is dense and aligned, and lasso in most other scenarios.

For the coefficients, prediction and interpretation pull apart. Where min-norm predicts best, it spreads each effect evenly over a correlated factor, and individual coefficients say very little. Factor totals are recovered almost perfectly with few factors, signs are right on sparse signals, and individual coefficients are readable only when the true effect is itself spread over an entire factor. Min-norm is best read at the level of factors; for sparse individual effects, lasso remains the better tool.

For inference, using $sigma$ for scaling isn't sufficient: each coefficient picks up the effects of the others, and scaling by the noise alone ignores this. Scaling by the spread of $y$ accounts for it and holds the level in every scenario, without needing an estimate of the noise. It doesn't, however, make inference reliable: power is lowest where prediction is best, intervals can miss the true effect even when tests reject correctly, and with thousands of null features most discoveries are false.

These results hold for $n = 100$, with equal factor sizes and equal effect sizes. The theory suggests that what matters is the number of factors relative to $n$, not their absolute number, but we did not vary $n$.

Finally, the scaling by the spread of $y$ is exact only under isotropy. With correlated features it is conservative, because part of the signal is captured on the spikes instead of leaking into the coefficients, and the type I error falls as the signal concentrates. It may fail with small factors, where null features would pick up a systematic share of their factor's effect, a case our design, with large and equal factors, does not cover.




#bibliography("bib.yaml", title: "References")
