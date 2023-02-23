using Gadfly
using CSV
using DataFrames
using Pipe
using Compose

##

rawdatas::Vector{Tuple{String,DataFrame}} = @pipe readdir() |>
                                                  filter(endswith(".csv"), _) |>
                                                  map(x -> (x, CSV.read(x, DataFrame)), _)

for (name, frame::DataFrame) in rawdatas
    frame.locktype .= @pipe name |> replace(_, ".csv" => "")
end

lockdata = @pipe rawdatas |>
                 map(x -> x[2], _) |>
                 reduce(vcat, _)


lockdata.cpu = @pipe lockdata.locktype |>
                     filter.(isdigit, _) |>
                     map(x -> parse(Int, x), _)

lockdata.locktype = @pipe lockdata.locktype |>
                          filter.(x -> !isdigit(x) && x != '_', _)

grouped_data = @pipe lockdata |>
                     groupby(_, [:locktype, :cpu])

plots = Vector{Plot}()

for key in keys(grouped_data)
    locktype, cpu = key

    group = grouped_data[key]

    push!(plots, plot(group, x=:loop, Geom.histogram,
        Guide.xlabel("$(locktype): $(cpu)")
    ))
end

draw(SVG(6inch, 24inch), gridstack(reshape(plots, 10, 2)))

##