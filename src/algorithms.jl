# Algorithms
abstract AbstractBoundaryValueAlgorithm # This will eventually move to DiffEqBase.jl
abstract BoundaryValueDiffEqAlgorithm <: AbstractBoundaryValueAlgorithm
immutable Shooting{T,F} <: BoundaryValueDiffEqAlgorithm
  ode_alg::T
  nlsolve::F
end
DEFAULT_NLSOLVE = (loss, u0) -> (res=NLsolve.nlsolve(loss, u0);res.zero)
Shooting(ode_alg;nlsolve=DEFAULT_NLSOLVE) = Shooting(ode_alg,nlsolve)

immutable MIRK{T,F} <: BoundaryValueDiffEqAlgorithm
    order::Int
    dt::T
    nlsolve::F
end

# Auxiliary functions for working with vector of vectors
function vector_alloc(T, M, N)
    v = Vector{Vector{T}}(N)
    for i in eachindex(v)
        v[i] = Vector{T}(M)
    end
    v
end

flatten_vector{T}(V::Vector{Vector{T}}) = vcat(V...)

function nest_vector{T}(v::Vector{T}, M, N)
    V = vector_alloc(T, M, N)
    for i in eachindex(V)
        copy!(V[i], v[(M*(i-1))+1:(M*i)])
    end
    V
end

function DEFAULT_NLSOLVE_MIRK(loss, u0, M, N)
    res = NLsolve.nlsolve(NLsolve.not_in_place(loss), flatten_vector(u0))
    opt = res.zero
    nest_vector(opt, M, N)
end
MIRK(order,dt;nlsolve=DEFAULT_NLSOLVE_MIRK) = MIRK(order,dt,nlsolve)

