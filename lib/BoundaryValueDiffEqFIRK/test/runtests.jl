using ReTestItems, BoundaryValueDiffEqFIRK, InteractiveUtils

@info sprint(InteractiveUtils.versioninfo)

const GROUP = (get(ENV, "GROUP", "All"))

if GROUP == "All" || GROUP == "EXPANDED"
    @time "FIRK Expanded solvers" begin
        ReTestItems.runtests("/expanded/")
    end
end

if GROUP == "All" || GROUP == "NESTED"
    @time "FIRK Nested solvers" begin
        ReTestItems.runtests("/nested/")
    end
end
