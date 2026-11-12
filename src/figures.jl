const SURFACE = "#fcfcfb"
const INK = "#0b0b0b"
const LIGHT_INK = "#ffffff"
const GRID = "#e1e0d9"
const BASELINE = "#c3c2b7"
const SERIES = ("#2a78d6", "#eb6834", "#1baf7a")
const DIVERGING = cgrad(["#e34948", "#f0efec", "#2a78d6"])
const SEQUENTIAL = cgrad(["#cde2fb", "#256abf", "#0d366b"])
const CURVE_FLOOR = 1e-3

const CHROME = (;
    background_color=SURFACE, foreground_color_text=INK, foreground_color_border=BASELINE,
    foreground_color_axis=BASELINE, foreground_color_grid=GRID,
    gridalpha=1.0, gridlinewidth=0.5,
    fontfamily="sans-serif", titlefontsize=11, guidefontsize=10, tickfontsize=8,
    legendfontsize=8, legend_foreground_color=GRID, framestyle=:box,
)

const SIGNAL_ORDER = [(signal, signs) for signal in SIGNALS for signs in SIGN_PATTERNS]
signal_label((signal, signs)) = "$signal\n$signs"
level_label(value) = isinteger(value) ? Int(value) : value
"""Spectrum label as printed on figures: `rho=0.7 K=5` becomes `ρ = 0.7, K = 5`."""
spectrum_display(label) = replace(label, "rho=" => "ρ = ", " K=" => ", K = ")

"""Heatmap panel of `outcome` by spectrum and signal for one study slice, with labels."""
function heat_panel(table, outcome; title, limits, colours, light_ink_when, show_y,
    spectrum_labels)
    function cell(level, signal_and_signs)
        rows = filter(table) do row
            row.spectrum == level && (row.signal, row.signs) == signal_and_signs
        end
        return isempty(rows) ? NaN : mean(row[outcome] for row in rows)
    end
    cells = [cell(level, signal_and_signs)
             for level in spectrum_labels, signal_and_signs in SIGNAL_ORDER]
    xs, ys = eachindex(SIGNAL_ORDER), eachindex(spectrum_labels)
    y_labels = show_y ? spectrum_display.(spectrum_labels) : fill("", length(ys))
    panel = heatmap(xs, ys, cells; clims=limits, color=colours, colorbar=false, title,
        xticks=(xs, signal_label.(SIGNAL_ORDER)), yticks=(ys, y_labels), grid=false,
        CHROME...)
    for y in ys, x in xs
        isnan(cells[y, x]) && continue
        ink = light_ink_when(cells[y, x]) ? LIGHT_INK : INK
        label = string(round(cells[y, x]; digits=2))
        annotate!(panel, x, y, text(label, 8, ink, "sans-serif"))
    end
    return panel
end

function heat_figure(table, outcome, heading; limits, colours, light_ink_when, snr)
    slice(ratio) = filter(row -> row.overparam == ratio && row.snr == snr, table)
    ratios = sort(unique(row.overparam for row in table))
    # Bottom to top: isotropic first, then toward fewer and stronger spikes.
    spectrum_sort_key(row) = (iszero(row.rho) ? 0 : 1, -row.n_factors, row.rho)
    spectrum_labels = unique(row.spectrum for row in sort(table; by=spectrum_sort_key))
    panels = [heat_panel(slice(ratio), outcome; title="p/n = $(level_label(ratio))", limits,
                  colours, light_ink_when, show_y=i == 1, spectrum_labels)
              for (i, ratio) in enumerate(ratios)]
    return plot(panels...; layout=(1, length(panels)), size=(1500, 400),
        plot_title="$heading (SNR = $(level_label(snr)))", plot_titlefontsize=12,
        left_margin=6Plots.mm, bottom_margin=6Plots.mm, background_color=SURFACE)
end

function prediction_figure(table, snr)
    heading = "Min-norm prediction: share of the signal recovered"
    return heat_figure(table, :signal_r2, heading; limits=(-1, 1), colours=DIVERGING,
        light_ink_when=value -> abs(value) > 0.6, snr)
end

function coefficients_figure(table, snr)
    cosine_figure(outcome, heading) = heat_figure(table, outcome, heading;
        limits=(0, 1), colours=SEQUENTIAL, light_ink_when=value -> value > 0.45, snr)
    feature = cosine_figure(:cosine, "Min-norm coefficients: cosine with the true effects")
    factor = cosine_figure(:factor_cosine,
        "Min-norm factor totals: cosine with the true totals")
    return plot(feature, factor; layout=(2, 1), size=(1500, 800))
end

"""Whether `row` has every value in the named tuple `selection`."""
matches(row, selection) = all(row[key] == value for (key, value) in pairs(selection))

"""Median risk, squared bias and variance along the prefix path of one scenario."""
function curve_panel(curve_summary, selection, title; legend)
    rows = filter(row -> matches(row, selection), curve_summary)
    k = [row.k for row in rows]
    n = first(rows).n
    panel = plot(; xscale=:log10, yscale=:log10, xlabel="features in the fit",
        ylabel="share of signal variance", title, legend, ylims=(CURVE_FLOOR, 1e2),
        CHROME...)
    vline!(panel, [n]; color=BASELINE, linewidth=1, label="p = n")
    risk_series = ((:excess_risk, "excess risk", SERIES[1]),
        (:bias2, "squared bias", SERIES[2]), (:variance, "variance", SERIES[3]))
    for (field, label, colour) in risk_series
        # A log axis cannot show zero, so values are floored at its lower limit.
        floored = [max(row[field], CURVE_FLOOR) for row in rows]
        plot!(panel, k, floored; color=colour, linewidth=2, label)
    end
    return panel
end

"""Curve panels for the example scenarios that the grid contains."""
function example_curve_panels(curve_summary, snr)
    example(spectrum, signal, signs) = (; overparam=20.0, spectrum, signal, signs, snr)
    examples = [
        (example("rho=0.7 K=5", :grouped, :aligned), "few factors, aligned signal"),
        (example("rho=0.7 K=5", :grouped, :contrast), "few factors, contrast signal"),
        (example("rho=0.7 K=50", :sparse, :aligned), "many factors, sparse signal"),
        (example("isotropic", :sparse, :aligned), "isotropic, sparse signal"),
    ]
    in_grid((selection, _)) = any(row -> matches(row, selection), curve_summary)
    legend_of(i) = i == 1 ? :bottomleft : false
    return [curve_panel(curve_summary, selection, title; legend=legend_of(i))
            for (i, (selection, title)) in enumerate(filter(in_grid, examples))]
end

function curves_figure(panels)
    return plot(panels...; layout=(1, length(panels)), size=(425 * length(panels), 460),
        left_margin=10Plots.mm, bottom_margin=10Plots.mm, top_margin=4Plots.mm,
        background_color=SURFACE)
end

function scatter_panel(table, outcome; xlabel, ylabel, title, x=:signal_r2,
    identity_line=false)
    panel = plot(; xlabel, ylabel, title, legend=:topleft, CHROME...)
    identity_line &&
        plot!(panel, [-1, 1], [-1, 1]; color=BASELINE, linewidth=1, label="equal")
    by_ratio = sort(group_rows(table, (:overparam,)); by=rows -> first(rows).overparam)
    for (colour, rows) in zip(SERIES, by_ratio)
        usable = filter(row -> isfinite(row[outcome]), rows)
        # Clipped at -1 so that a few very poor fits do not stretch the axes.
        xs = [max(row[x], -1) for row in usable]
        ys = [max(row[outcome], -1) for row in usable]
        scatter!(panel, xs, ys; color=colour, markersize=4, markerstrokecolor=SURFACE,
            markerstrokewidth=1, label="p/n = $(level_label(first(rows).overparam))")
    end
    return panel
end

function tradeoffs_figure(table)
    recovered = "share of the signal recovered"
    # Isotropic designs have no spikes, so their share on the spikes is undefined.
    alignment_panel = scatter_panel(filter(row -> row.rho > 0, table), :signal_r2;
        x=:signal_share,
        xlabel="share of the signal on the spikes", ylabel=recovered,
        title="Prediction")
    tuned_panel = scatter_panel(table, :signal_r2; x=:ridge_r2, identity_line=true,
        xlabel="tuned ridge: $recovered", ylabel="min-norm: $recovered",
        title="Interpolation")
    feature_panel = scatter_panel(table, :cosine; xlabel=recovered,
        ylabel="coefficient cosine", title="Individual coefficients")
    factor_panel = scatter_panel(table, :factor_cosine; xlabel=recovered,
        ylabel="factor-total cosine", title="Factor totals")
    return plot(alignment_panel, tuned_panel, feature_panel, factor_panel;
        layout=(1, 4), size=(1800, 460), left_margin=8Plots.mm, bottom_margin=8Plots.mm,
        top_margin=3Plots.mm, background_color=SURFACE)
end

"""
Write the figures, at the central SNR. Example curves absent from the grid are
skipped.
"""
function save_figures(output, table, curve_summary)
    levels = sort(unique(row.snr for row in table))
    snr = levels[(length(levels) + 1) ÷ 2]
    savefig(prediction_figure(table, snr), joinpath(output, "prediction.png"))
    savefig(coefficients_figure(table, snr), joinpath(output, "coefficients.png"))
    panels = example_curve_panels(curve_summary, snr)
    isempty(panels) || savefig(curves_figure(panels), joinpath(output, "curves.png"))
    savefig(tradeoffs_figure(table), joinpath(output, "tradeoffs.png"))
end
