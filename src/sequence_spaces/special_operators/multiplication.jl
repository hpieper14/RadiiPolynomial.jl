"""
    Multiplication{T<:Sequence{<:SequenceSpace}} <: SpecialOperator

Multiplication operator associated with a given [`Sequence`](@ref).

Field:
- `sequence :: T`

Constructor:
- `Multiplication(::Sequence{<:SequenceSpace})`

See also: [`*(::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace})`](@ref),
[`mul!(::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace}, ::Number, ::Number)`](@ref),
[`^(::Sequence{<:SequenceSpace}, ::Int)`](@ref),
[`project(::Multiplication, ::SequenceSpace, ::SequenceSpace)`](@ref),
[`project!(::LinearOperator{<:SequenceSpace,<:SequenceSpace}, ::Multiplication)`](@ref)
and [`Multiplication`](@ref).
"""
struct Multiplication{T<:Sequence{<:SequenceSpace}} <: SpecialOperator
    sequence :: T
end

sequence(ℳ::Multiplication) = ℳ.sequence

"""
    *(ℳ::Multiplication, a::Sequence)

Compute the discrete convolution (associated with `space(sequence(ℳ))` and
`space(a)`) of `sequence(ℳ)` and `a`; equivalent to `sequence(ℳ) * a`.

See also: [`(::Multiplication)(::Sequence)`](@ref), [`Multiplication`](@ref),
[`*(::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace})`](@ref),
[`mul!(::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace}, ::Number, ::Number)`](@ref)
and [`^(::Sequence{<:SequenceSpace}, ::Int)`](@ref).
"""
Base.:*(ℳ::Multiplication, a::Sequence) = *(sequence(ℳ), a)

"""
    (ℳ::Multiplication)(a::Sequence)

Compute the discrete convolution (associated with `space(sequence(ℳ))` and
`space(a)`) of `sequence(ℳ)` and `a`; equivalent to `sequence(ℳ) * a`.

See also: [`*(::Multiplication, ::Sequence)`](@ref), [`Multiplication`](@ref),
[`*(::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace})`](@ref),
[`mul!(::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace}, ::Sequence{<:SequenceSpace}, ::Number, ::Number)`](@ref)
and [`^(::Sequence{<:SequenceSpace}, ::Int)`](@ref).
"""
(ℳ::Multiplication)(a::Sequence) = *(ℳ, a)

Base.:+(ℳ::Multiplication) = Multiplication(+(sequence(ℳ)))
Base.:-(ℳ::Multiplication) = Multiplication(-(sequence(ℳ)))
Base.:^(ℳ::Multiplication, n::Int) = Multiplication(sequence(ℳ) ^ n)

for f ∈ (:+, :-, :*)
    @eval begin
        Base.$f(ℳ₁::Multiplication, ℳ₂::Multiplication) = Multiplication($f(sequence(ℳ₁), sequence(ℳ₂)))
        Base.$f(a::Number, ℳ::Multiplication) = Multiplication($f(a, sequence(ℳ)))
        Base.$f(ℳ::Multiplication, a::Number) = Multiplication($f(sequence(ℳ), a))
    end
end

Base.:/(ℳ::Multiplication, a::Number) = Multiplication(/(sequence(ℳ), a))
Base.:\(a::Number, ℳ::Multiplication) = Multiplication(\(a, sequence(ℳ)))

opnorm(ℳ::Multiplication, X::BanachSpace) = norm(sequence(ℳ), X)

# for consistency with other SpecialOperator
image(ℳ::Multiplication, s::SequenceSpace) = image(*, space(sequence(ℳ)), s)
_coeftype(ℳ::Multiplication, ::SequenceSpace, ::Type{T}) where {T} =
    promote_type(eltype(sequence(ℳ)), T)

"""
    project(ℳ::Multiplication, domain::SequenceSpace, codomain::SequenceSpace, ::Type{T}=eltype(sequence(ℳ)))

Represent `ℳ` as a [`LinearOperator`](@ref) from `domain` to `codomain`.

See also: [`project!(::LinearOperator{<:SequenceSpace,<:SequenceSpace}, ::Multiplication)`](@ref)
and [`Multiplication`](@ref).
"""
function project(ℳ::Multiplication, domain::SequenceSpace, codomain::SequenceSpace, ::Type{T}=eltype(sequence(ℳ))) where {T}
    _iscompatible(domain, codomain) & _iscompatible(space(sequence(ℳ)), domain) || return throw(ArgumentError("spaces must be compatible"))
    C = LinearOperator(domain, codomain, zeros(T, dimension(codomain), dimension(domain)))
    _project!(C, ℳ)
    return C
end

"""
    project!(C::LinearOperator{<:SequenceSpace,<:SequenceSpace}, ℳ::Multiplication)

Represent `ℳ` as a [`LinearOperator`](@ref) from `domain(C)` to `codomain(C)`.
The result is stored in `C` by overwriting it.

See also: [`project(::Multiplication, ::SequenceSpace, ::SequenceSpace)`](@ref)
and [`Multiplication`](@ref).
"""
function project!(C::LinearOperator{<:SequenceSpace,<:SequenceSpace}, ℳ::Multiplication)
    domain_C = domain(C)
    _iscompatible(domain_C, codomain(C)) & _iscompatible(space(sequence(ℳ)), domain_C) || return throw(ArgumentError("spaces must be compatible"))
    coefficients(C) .= zero(eltype(C))
    _project!(C, ℳ)
    return C
end

#

function _project!(C::LinearOperator{<:TensorSpace,<:TensorSpace}, ℳ::Multiplication)
    space_ℳ = space(sequence(ℳ))
    @inbounds for β ∈ _mult_domain_indices(domain(C)), α ∈ indices(codomain(C))
        if _isvalid(space_ℳ, α, β)
            C[α,_extract_valid_index(space_ℳ, β, zero.(α))] += sequence(ℳ)[_extract_valid_index(space_ℳ, α, β)]
        end
    end
    return C
end

_mult_domain_indices(s::TensorSpace) = TensorIndices(map(_mult_domain_indices, spaces(s)))

_isvalid(s::TensorSpace{<:NTuple{N,BaseSpace}}, α::NTuple{N,Int}, β::NTuple{N,Int}) where {N} =
    @inbounds _isvalid(s[1], α[1], β[1]) & _isvalid(Base.tail(s), Base.tail(α), Base.tail(β))
_isvalid(s::TensorSpace{<:Tuple{BaseSpace}}, α::Tuple{Int}, β::Tuple{Int}) =
    @inbounds _isvalid(s[1], α[1], β[1])

_extract_valid_index(s::TensorSpace{<:NTuple{N,BaseSpace}}, α::NTuple{N,Int}, β::NTuple{N,Int}) where {N} =
    @inbounds (_extract_valid_index(s[1], α[1], β[1]), _extract_valid_index(Base.tail(s), Base.tail(α), Base.tail(β))...)
_extract_valid_index(s::TensorSpace{<:Tuple{BaseSpace}}, α::Tuple{Int}, β::Tuple{Int}) =
    @inbounds (_extract_valid_index(s[1], α[1], β[1]),)

# Taylor

function _project!(C::LinearOperator{Taylor,Taylor}, ℳ::Multiplication)
    order_codomain = order(codomain(C))
    ord = order(sequence(ℳ))
    @inbounds for j ∈ indices(domain(C)), i ∈ j:min(order_codomain, ord+j)
        C[i,j] = sequence(ℳ)[i-j]
    end
    return C
end

_mult_domain_indices(s::Taylor) = indices(s)
_isvalid(s::Taylor, i::Int, j::Int) = 0 ≤ i-j ≤ order(s)
_extract_valid_index(::Taylor, i::Int, j::Int) = i-j

# Fourier

function _project!(C::LinearOperator{<:Fourier,<:Fourier}, ℳ::Multiplication)
    order_codomain = order(codomain(C))
    ord = order(sequence(ℳ))
    @inbounds for j ∈ indices(domain(C)), i ∈ max(-order_codomain, -ord+j):min(order_codomain, ord+j)
        C[i,j] = sequence(ℳ)[i-j]
    end
    return C
end

_mult_domain_indices(s::Fourier) = indices(s)
_isvalid(s::Fourier, i::Int, j::Int) = abs(i-j) ≤ order(s)
_extract_valid_index(::Fourier, i::Int, j::Int) = i-j

# Chebyshev

function _project!(C::LinearOperator{Chebyshev,Chebyshev}, ℳ::Multiplication)
    ord = order(sequence(ℳ))
    @inbounds for j ∈ indices(domain(C)), i ∈ indices(codomain(C))
        if abs(i-j) ≤ ord
            if j == 0
                C[i,j] = sequence(ℳ)[i]
            else
                C[i,j] = sequence(ℳ)[abs(i-j)]
                idx2 = i+j
                if idx2 ≤ ord
                    C[i,j] += sequence(ℳ)[idx2]
                end
            end
        end
    end
    return C
end

_mult_domain_indices(s::Chebyshev) = -order(s):order(s)
_isvalid(s::Chebyshev, i::Int, j::Int) = abs(i-j) ≤ order(s)
_extract_valid_index(::Chebyshev, i::Int, j::Int) = abs(i-j)
