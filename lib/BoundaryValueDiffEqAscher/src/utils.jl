function build_almost_block_diagonals(
        zeta::Vector{T}, ncomp::I, mesh, ::Type{T}) where {T, I}
    lside = 0
    ncol = 2 * ncomp
    n = length(mesh) - 1
    # build integs (describing block structure of matrix)
    rows = Vector{I}(undef, n)
    cols = repeat([ncol], n)
    lasts = repeat([ncomp], n)
    let lside = 0
        for i in 1:(n - 1)
            lside = first(findall(x::Float64 -> x > mesh[i], zeta)) - 1
            rows[i] = ncomp + lside
        end
    end
    lasts[end] = ncol
    rows[end] = ncol
    g = IntermediateAlmostBlockDiagonal(
        [Matrix{T}(undef, rows[i], cols[i]) for i in 1:n], lasts)
    return g
end

# Custom pivot LU factorization and substitution for simple usage and
# customized array types
function __factorize!(a::Matrix{T}, ipvt::Vector) where {T}
    t = 0.0
    n = size(a, 1)
    if n - 1 >= 1
        for k in 1:(n - 1)
            kp1 = k + 1
            # find l = pivot index
            l = argmax(abs.(a[k:end, k])) + k - 1
            ipvt[k] = l
            # zero pivot implies this column already triangularized
            if a[l, k] !== 0
                # interchange if necessary
                if l !== k
                    t = a[l, k]
                    a[l, k] = a[k, k]
                    a[k, k] = t
                end
                # compute  multipliers
                t = -1.0 / a[k, k]
                @views a[(k + 1):end, k] .= a[(k + 1):end, k] .* t
                # row elimination with column indexing
                for j in kp1:n
                    t = a[l, j]
                    if l !== k
                        a[l, j] = a[k, j]
                        a[k, j] = t
                    end
                    @views __muladd!(t, a[(k + 1):end, k], a[(k + 1):end, j])
                end
            end
        end
    end
    ipvt[n] = n
end

function __substitute!(
        a::Matrix{T1}, ipvt::Vector{I}, vb::Vector{Vector{T2}}) where {T1, T2, I}
    n = size(a, 1)
    b = reduce(vcat, vb)
    if n - 1 >= 1
        for k in 1:(n - 1)
            l::I = ipvt[k]
            t = b[l]
            if l !== k
                b[l] = b[k]
                b[k] = t
            end
            @views __muladd!(t, a[(k + 1):end, k], b[(k + 1):end])
        end
    end
    for k in n:-1:1
        b[k] = b[k] / a[k, k]
        @views __muladd!(-b[k], a[1:(k - 1), k], b[1:(k - 1)])
    end
    recursive_unflatten!(vb, b)
end
function __substitute!(
        a::Matrix{T1}, ipvt::Vector{I}, b::AbstractVector{T2}) where {T1, T2 <: Real, I}
    n = size(a, 1)
    if n - 1 >= 1
        for k in 1:(n - 1)
            l::I = ipvt[k]
            t = b[l]
            if l !== k
                b[l] = b[k]
                b[k] = t
            end
            @views __muladd!(t, a[(k + 1):end, k], b[(k + 1):end])
        end
    end
    for k in n:-1:1
        b[k] = b[k] / a[k, k]
        @views __muladd!(-b[k], a[1:(k - 1), k], b[1:(k - 1)])
    end
end

@inline function __muladd!(a, x, y)
    y .= muladd(a, x, y)
end

@views function recursive_flatten!(y::Vector, x::Vector{Vector{Vector{T}}}) where {T}
    i = 0
    for xᵢ in x
        for xᵢᵢ in xᵢ
            copyto!(y[(i + 1):(i + length(xᵢᵢ))], xᵢᵢ)
            i += length(xᵢᵢ)
        end
    end
    return nothing
end

@views function recursive_flatten!(y::Vector, x::Vector{Vector{T}}) where {T}
    i = 0
    for xᵢ in x
        copyto!(y[(i + 1):(i + length(xᵢ))], xᵢ)
        i += length(xᵢ)
    end
    return nothing
end

@views function recursive_unflatten!(
        y::Vector{Vector{Vector{T}}}, x::AbstractArray) where {T}
    i = 0
    for yᵢ in y
        for yᵢᵢ in yᵢ
            copyto!(yᵢᵢ, x[(i + 1):(i + length(yᵢᵢ))])
            i += length(yᵢᵢ)
        end
    end
    return nothing
end
@views function recursive_unflatten!(y::Vector{Vector{T}}, x::AbstractArray) where {T}
    i = 0
    for yᵢ in y
        copyto!(yᵢ, x[(i + 1):(i + length(yᵢ))])
        i += length(yᵢ)
    end
    return nothing
end
@views function recursive_unflatten!(y::AbstractArray, x::AbstractArray{T}) where {T}
    i = 0
    for yᵢ in y
        copyto!(yᵢ, x[(i + 1):(i + length(yᵢ))])
        i += length(yᵢ)
    end
    return nothing
end
