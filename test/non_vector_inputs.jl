using BoundaryValueDiffEq, DiffEqBase, DiffEqDevTools, LinearAlgebra, OrdinaryDiffEq, Test

for order in (2, 3, 4, 5, 6)
    s = Symbol("MIRK$(order)")
    @eval mirk_solver(::Val{$order}) = $(s)()
end

function f1!(du, u, p, t)
    du[1, 1] = u[1, 2]
    du[1, 2] = 0
end

function f1(u, p, t)
    return [u[1, 2] 0]
end

function boundary!(residual, u, p, t)
    residual[1, 1] = u[1][1, 1] - 5
    residual[1, 2] = u[end][1, 1]
end

function boundary!((resida, residb), (ua, ub), p)
    resida[1, 1] = ua[1, 1] - 5
    residb[1, 1] = ub[1, 1]
end

function boundary(u, p, t)
    return [u[1][1, 1] - 5 u[end][1, 1]]
end

function boundary((ua, ub), p)
    return (reshape([ua[1, 1] - 5], (1, 1)), reshape([ub[1, 1]], (1, 1)))
end

tspan = (0.0, 5.0)
u0 = [5.0 -3.5]
probs = [
    BVProblem(f1!, boundary!, u0, tspan),
    TwoPointBVProblem(f1!, boundary!, u0, tspan;
        bcresid_prototype = (Array{Float64}(undef, 1, 1), Array{Float64}(undef, 1, 1))),
    BVProblem(f1, boundary, u0, tspan),
    TwoPointBVProblem(f1, boundary, u0, tspan),
];

@testset "Affineness" begin
    @testset "MIRK$order" for order in (2, 3, 4, 5, 6)
        for prob in probs
            @time sol = solve(prob, mirk_solver(Val(order)); dt = 0.2)
            @test norm(diff(first.(sol.u)) .+ 0.2, Inf) + abs(sol[1][1] - 5) < 0.01
        end
    end
end
