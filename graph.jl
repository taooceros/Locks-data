using Gadfly
using CSV
using DataFrames
using Pipe
using Hose
using Compose

##

rawdatas::Vector{Tuple{String,DataFrame}} = @hose readdir() |>
                                                  filter(endswith(".csv"), _) |>
                                                  map(x -> (x, CSV.read(x, DataFrame)), _)

for (name, frame::DataFrame) in rawdatas
    frame.locktype .= @hose name |> replace(_, ".csv" => "")
end

lockdata = @hose rawdatas |>
                 map(x -> x[2], _) |>
                 reduce(vcat, _)


lockdata.cpu = @hose lockdata.locktype |>
                     filter.(isdigit, _) |>
                     map(x -> parse(Int, x), _)

lockdata.locktype = @hose lockdata.locktype |>
                          filter.(x -> !isdigit(x) && x != '_', _)

grouped_data = @hose lockdata |>
                     groupby(_, [:locktype, :cpu])

plots = Vector{Plot}()

for key in keys(grouped_data)
    locktype, cpu = key

    group = grouped_data[key]

    push!(plots, plot(group, x=:loop, Geom.histogram,
        Guide.xlabel("$(locktype): $(cpu)")
    ))
end
>
draw(SVG(6inch, 24inch), gridstack(reshape(plots, 10, 2)))

## Plot Overall Iteration group by cpu

iteration_data = @hose lockdata |>
                     groupby([:locktype, :cpu]) |>
                     combine(:loop => sum => :iterations)


@hose iteration_data |>
      plot(x=:cpu, y=:iterations, color=:locktype, Geom.point, Geom.line) |>
      draw(SVG(6inch, 6inch), _)

## Plot Lock Acquire Time group by cpu

acquire_data = @hose lockdata |>
                     groupby([:locktype, :cpu]) |>
                     combine(:lock_acquires => sum => :all_acquire)

@hose acquire_data |>
    plot(x=:cpu, y=:all_acquire, color=:locktype, Geom.point, Geom.line) |>
    draw(SVG(6inch, 6inch), _)

## Plot overall lock acquire time group by cpu

overall_hold_data = @hose lockdata |>
                     groupby([:locktype, :cpu]) |>
                     combine("lock_hold(ms)" => sum => "lock_hold(ms)")

@hose overall_hold_data |>
    plot(x=:cpu, y=:"lock_hold(ms)", color=:locktype, Geom.point, Geom.line) |>
    draw(SVG(6inch, 6inch), _)


## Plot Individual Lock Acquire Time with x asix being the id, and stack the plot based on cpu

individual_hold_data = @hose lockdata |>
                     groupby([:cpu])

@hose keys(individual_hold_data) |>
    map(x -> individual_hold_data[x], _) |>
    map(x -> plot(x, x=:id, y=:"lock_hold(ms)", color=:locktype, Geom.point, Geom.line), _) |>
    vstack |>
    draw(SVG(6inch, 24inch), _)