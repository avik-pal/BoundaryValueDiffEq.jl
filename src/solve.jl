using BandedMatrices

# The Solve Function
function solve(prob::BVProblem, alg::Shooting; kwargs...)
    bc = prob.bc
    u0 = deepcopy(prob.u0)
    # Form a root finding function.
    loss = function (minimizer,resid)
        uEltype = eltype(minimizer)
        tspan = (uEltype(prob.tspan[1]),uEltype(prob.tspan[2]))
        tmp_prob = ODEProblem(prob.f,minimizer,tspan)
        sol = solve(tmp_prob,alg.ode_alg;kwargs...)
        bc(resid,sol)
        nothing
    end
    opt = alg.nlsolve(loss, u0)
    sol_prob = ODEProblem(prob.f,opt[1],prob.tspan)
    sol = solve(sol_prob, alg.ode_alg;kwargs...)
    sol.retcode = opt[2] ? :Success : :Failure
    sol
end

function solve(prob::Union{BVProblem,TwoPointBVProblem}, alg::Union{GeneralMIRK,MIRK}; dt=0.0, kwargs...)
    if dt<=0
        error("dt must be positive")
    end
    n = Int(cld((prob.tspan[2]-prob.tspan[1]),dt))
    x = collect(linspace(prob.tspan..., n+1))
    S = BVPSystem(prob.f, prob.bc, x, length(prob.u0), alg_order(alg))
    if isa(prob.u0, Vector{<:Number})
        S.y[1] = prob.u0
    elseif isa(prob.u0, Vector{<:AbstractArray})
        copy!(S.y, prob.u0)
    else
        error("u0 must be a Vector or Vector of Arrays")
    end
    tableau = constructMIRK(S)
    cache = alg_cache(alg, S)
    # Upper-level iteration
    vec_y = Array{eltype(S.y[1])}(S.M*S.N)              # Vector
    reorder! = function (resid)
        # reorder the Jacobian matrix such that it is banded
        tmp_last = resid[end]
        for i in (length(resid)-1):-1:1
            resid[i+1] = resid[i]
        end
        resid[1], resid[end] = resid[end], tmp_last
    end        
    loss = function (minimizer, resid)
        nest_vector!(S.y, minimizer)
        Φ!(S, tableau, cache)
        isa(prob, TwoPointBVProblem) ? eval_bc_residual!(S) : general_eval_bc_residual!(S)
        flatten_vector!(resid, S.residual)
        reorder!(resid)
        nothing
    end

    jac_wrapper = BVPJacobianWrapper(loss, similar(vec_y), similar(vec_y))

    flatten_vector!(vec_y, S.y)
    opt = isa(prob, TwoPointBVProblem) ? alg.nlsolve(ConstructJacobian(jac_wrapper, S), vec_y) : alg.nlsolve(ConstructJacobian(jac_wrapper, S), vec_y) # Sparse matrix is broken
    nest_vector!(S.y, opt[1])

    retcode = opt[2] ? :Success : :Failure
    DiffEqBase.build_solution(prob, alg, x, S.y, retcode = retcode)
end

#=
function solve(prob::BVProblem, alg::GeneralMIRK; dt=0.0, kwargs...)
    n = Int(cld((prob.tspan[2]-prob.tspan[1]),dt))
    x = collect(linspace(prob.tspan..., n+1))
    S = BVPSystem(prob.f, prob.bc, x, length(prob.u0), alg_order(alg))
    S.y[1] = prob.u0
    tableau = constructMIRK(S)
    cache = alg_cache(alg, S)
    # Upper-level iteration
    vec_y = Array{eltype(S.y[1])}(S.M*S.N)              # Vector
    loss = function (minimizer, resid)
        nest_vector!(S.y, minimizer)
        Φ!(S, tableau, cache)
        general_eval_bc_residual!(S)
        flatten_vector!(resid, S.residual)
        nothing
    end
    flatten_vector!(vec_y, S.y)
    opt = alg.nlsolve(loss, vec_y)
    nest_vector!(S.y, opt[1])
    retcode = opt[2] ? :Success : :Failure
    DiffEqBase.build_solution(prob, alg, x, S.y, retcode = retcode)
end
=#
