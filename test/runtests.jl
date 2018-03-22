using WebAssembly
using WebAssembly.Instructions
using Base.Test

using Charlotte

@testset "WebAssembly" begin

b = Block([Nop(), Nop()]) |> WebAssembly.nops
@test isempty(b.body)

include("interpret.jl")

end

