# Read the fixed snapshot, inspect missing values, and plot CPI transformations.
using CSV, DataFrames, CairoMakie, JSON, StringEncodings
using Dates, SHA, LinearAlgebra, Statistics

raw = joinpath(@__DIR__, "data", "raw")
provenance = JSON.parsefile(joinpath(raw, "provenance.json"))
for record in provenance["files"]
    @assert bytes2hex(sha256(read(joinpath(raw, record["file"])))) == record["sha256"]
end

# The first record after the header is metadata, not an observation.
path = joinpath(raw, "fred-md-2025-10.csv")
metadata = CSV.read(path, DataFrame; limit=1)
@assert metadata.sasdate[1] == "Transform:"
levels = CSV.read(path, DataFrame; skipto=3,
    types=Dict(:sasdate => Date), dateformat=dateformat"m/d/y", strict=true)
series = names(levels, Not(:sasdate))
codes = [Int(metadata[1, name]) for name in series]
@assert all(code -> 1 <= code <= 7, codes)
@assert levels.sasdate == collect(Date(1959, 1):Month(1):Date(2025, 9))
targets = ["CPIAUCSL", "UNRATE", "INDPRO", "RPI"]
@assert all(name -> name in series, targets)

# The March 2024 dictionary uses Windows-1252; the snapshot's own codes take priority.
dictionary = CSV.read(IOBuffer(decode(
    read(joinpath(raw, "FRED-MD_updated_appendix.csv")), "WINDOWS-1252")), DataFrame)
descriptions = Dict(row.fred => row.description for row in eachrow(dictionary))
summary = DataFrame(
    series=series,
    description=[get(descriptions, name, missing) for name in series],
    transformation_code=codes,
    missing_months=[count(ismissing, levels[!, name]) for name in series],
)
output = joinpath(@__DIR__, "outputs")
mkpath(output)
CSV.write(joinpath(output, "series_summary_julia.csv"), summary)
println("FRED-MD vintage $(provenance["vintage"]): $(nrow(levels)) months, $(length(series)) series")
println("Dates: $(first(levels.sasdate)) to $(last(levels.sasdate))")
show(stdout, MIME"text/plain"(), summary[in.(summary.series, Ref(targets)), :])
println("\nMissing values in the raw panel: $(sum(summary.missing_months))")

# CPI's first log difference is inflation; code 6 is a second log difference.
# No missing-value filling or model scaling is performed here.
cpi = levels.CPIAUCSL
@assert !any(ismissing, cpi) && all(>(0), cpi)
@assert codes[findfirst(==("CPIAUCSL"), series)] == 6
inflation = 100 .* diff(log.(cpi))
change_in_inflation = diff(inflation)
years = year.(levels.sasdate) .+ (month.(levels.sasdate) .- 1) ./ 12
fig = Figure(size=(1100, 650))
ax1 = Axis(fig[1, 1]; title="Monthly CPI inflation (log percent)", ylabel="100 × Δ log(CPI)")
ax2 = Axis(fig[2, 1]; title="Change in monthly inflation (FRED-MD code 6, ×100)",
    ylabel="100 × Δ² log(CPI)", xlabel="Year")
lines!(ax1, years[2:end], inflation)
lines!(ax2, years[3:end], change_in_inflation)
for ax in (ax1, ax2)
    hlines!(ax, [0]; color=:black, linewidth=0.5)
end
linkxaxes!(ax1, ax2)
save(joinpath(output, "cpi_transformations_julia.png"), fig; px_per_unit=1.5)

# One tiny check: the pseudoinverse interpolates and chooses the minimum norm.
# The third column is the sum of the first two; [1, 1, -1] is a null direction.
X_demo = [1.0 0.0 1.0; 0.0 1.0 1.0]
y_demo = [1.0, 2.0]
coef_demo = pinv(X_demo) * y_demo
@assert X_demo * coef_demo ≈ y_demo
@assert isapprox(dot(coef_demo, [1.0, 1.0, -1.0]), 0; atol=1e-12)
@assert norm(coef_demo) < norm(coef_demo + [1.0, 1.0, -1.0])
println("Minimum-norm check passed. Saved summary and CPI plot in $output")
