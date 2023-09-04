using BoundaryValueDiffEq, Random

function ode!(du, u, p, t)
    du[1] = u[2]
    du[2] = -p[1] * u[1]
end

function bc!(residual, u, p, t)
    residual[1] = u[1][1] - 1.0
    residual[2] = u[end][1]
end

function prob_func(prob, i, repeat)
    remake(prob, p = [rand()])
end

initial_guess = [0.0, 1.0]
tspan = (0, pi / 2)
p = [rand()]
bvp = BVProblem(ode!, bc!, initial_guess, tspan, p)
ensemble_prob = EnsembleProblem(bvp, prob_func = prob_func)

@testset "$(nameof(typeof(solver)))" for solver in (MIRK2, MIRK3, MIRK4, MIRK5, MIRK6)
    jac_algs = [MIRKJacobianComputationAlgorithm(),
        MIRKJacobianComputationAlgorithm(; bc_diffmode = AutoFiniteDiff(),
            collocation_diffmode = AutoSparseFiniteDiff())]
    for jac_alg in jac_algs
        sim = solve(ensemble_prob, solver(; jac_alg), trajectories = 10, dt = 0.1)
        @test SciMLBase.successful_retcode(sim)
    end
end
