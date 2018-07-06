##############################################################################
## 
## Type with stored qr
##
##############################################################################
struct DenseQRAllocatedSolver{Tqr <: StridedMatrix, Tu <: AbstractVector} <: AbstractAllocatedSolver
    qrm::Tqr
    u::Tu
    function DenseQRAllocatedSolver{Tqr, Tu}(qrm, u) where {Tqr <: StridedMatrix, Tu <: AbstractVector}
        length(u) == size(qrm, 1) || throw(DimensionMismatch("u must have length size(J, 1)"))
        new(qrm, u)
    end
end

function DenseQRAllocatedSolver(qrm::Tqr, u::Tu) where {Tqr <: StridedMatrix, Tu <: AbstractVector}
    DenseQRAllocatedSolver{Tqr, Tu}(qrm, u)
end

##############################################################################
## 
## solve J'J \ J'y by QR
##
##############################################################################

function AbstractAllocatedSolver(nls::LeastSquaresProblem{Tx, Ty, Tf, TJ, Tg}, optimizer::Dogleg, solver::QR) where {Tx, Ty, Tf, TJ <: StridedVecOrMat, Tg}
    return DenseQRAllocatedSolver(similar(nls.J), _zeros(nls.y))
end

function ldiv!(x::AbstractVector, J::StridedMatrix,  y::AbstractVector, A::DenseQRAllocatedSolver)
    u, qrm = A.u, A.qrm
    copyto!(qrm, J)
    copyto!(u, y)
    ldiv!(qr!(qrm, Val(true)), u)
    for i in 1:length(x)
        x[i] = u[i]
    end
    return x, 1
end

##############################################################################
## 
## solve (J'J + diagm(damp)) \ J'y by QR
##
##############################################################################

function AbstractAllocatedSolver(nls::LeastSquaresProblem{Tx, Ty, Tf, TJ, Tg}, optimizer::LevenbergMarquardt, solver::QR) where {Tx, Ty, Tf, TJ <: StridedVecOrMat, Tg}
    qrm = zeros(eltype(nls.J), length(nls.y) + length(nls.x), length(nls.x))
    u = zeros(length(nls.y) + length(nls.x))
    return DenseQRAllocatedSolver(qrm, u)
end

function ldiv!(x::AbstractVector, J::StridedMatrix, y::AbstractVector, 
                damp::AbstractVector, A::DenseQRAllocatedSolver, verbose::Bool = false)
    u, qrm = A.u, A.qrm
    
    # transform dammp
    length(u) ==  length(y) + length(x) || throw(DimensionMismatch("length(u) should equal length(x) + length(y)"))

    # update qr as |J; diagm(damp)|
    fill!(qrm, zero(eltype(qrm)))
    for j in 1:size(J, 2)
        for i in 1:size(J, 1)
            qrm[i, j] = J[i, j]
        end
    end

    leny = length(y)
    for i in 1:length(damp)
        qrm[leny + i, i] = sqrt(damp[i])
    end

    # update u as |J; 0|
    fill!(u, zero(eltype(u)))
    for i in 1:length(y)
        u[i] = y[i]
    end
    if verbose
        @show mean(u)
        sleep(1)
    end

    # solve
    ldiv!(qr!(qrm, Val(true)), u)
    if verbose
        @show mean(u)
        sleep(1)
    end
    for i in 1:length(x)
        x[i] = u[i]
    end
    return x, 1
end
