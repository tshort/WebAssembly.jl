@enum WType i32 i64 f32 f64

WType(::Type{Int32}) = i32
WType(::Type{Int64}) = i64
WType(::Type{Float32}) = f32
WType(::Type{Float64}) = f64

WType(::Type{<:Union{Bool,UInt32}}) = i32
WType(::Type{UInt64}) = i64

jltype(x::WType) = [Int32, Int64, Float32, Float64][Int(x)+1]

abstract type Instruction end

struct Const <: Instruction
  typ::WType
  val::UInt64
end

Const(x::Union{UInt32,UInt64})   = Const(WType(typeof(x)), UInt64(x))
Const(x::Union{Int64,Int32})     = Const(WType(typeof(x)), reinterpret(UInt64, Int64(x)))
Const(x::Union{Float64,Float32}) = Const(WType(typeof(x)), reinterpret(UInt64, Float64(x)))
Const(x::Bool) = Const(Int32(x))

value(x::Const) = value(x, jltype(x.typ))
value(x::Const, T::Union{Type{Float64},Type{Int64}}) = reinterpret(T, x.val)
value(x::Const, T::Union{Type{Float32},Type{Int32}}) = T(value(x, widen(T)))

struct Nop <: Instruction end

const nop = Nop()

struct Local <: Instruction
  id::Int
end

struct SetLocal <: Instruction
  tee::Bool
  id::Int
end

struct Op <: Instruction
  typ::WType
  name::Symbol
end

struct Select <: Instruction end

struct Convert <: Instruction
  to::WType
  from::WType
  name::Symbol
end

struct Block <: Instruction
  body::Vector{Instruction}
end

struct If <: Instruction
  t::Vector{Instruction}
  f::Vector{Instruction}
end

struct Loop <: Instruction
  body::Vector{Instruction}
end

struct Branch <: Instruction
  cond::Bool
  level::Int
end

Branch(l::Integer) = Branch(false, l)

struct Return <: Instruction end

struct Unreachable <: Instruction end

const unreachable = Unreachable()

struct Func
  params::Vector{WType}
  returns::Vector{WType}
  locals::Vector{WType}
  body::Block
end

struct Module
  funcs::Vector{Func}
end

# Printing

Base.show(io::IO, i::Nop)      = print(io, "nop")
Base.show(io::IO, i::Const)    = print(io, i.typ, ".const ", value(i))
Base.show(io::IO, i::Local)    = print(io, "get_local ", i.id)
Base.show(io::IO, i::SetLocal) = print(io, i.tee ? "tee_local" : "set_local ", i.id)
Base.show(io::IO, i::Op)       = print(io, i.typ, ".", i.name)
Base.show(io::IO, i::Convert)  = print(io, i.to, ".", i.name, "/", i.from)
Base.show(io::IO, i::Select)   = print(io, "select")
Base.show(io::IO, i::Branch)   = print(io, i.cond ? "br_if " : "br ", i.level)
Base.show(io::IO, i::Return)   = print(io, "return")
Base.show(io::IO, i::Unreachable) = print(io, "unreachable")

printwasm(io, x, level) = show(io, x)

function printwasm_(io, xs, level)
  for x in xs
    print(io, "\n", "  "^(level))
    print(io, "(")
    printwasm(io, x, level)
    print(io, ")")
  end
end

function printwasm(io, x::If, level)
  level += 1
  print(io, "if")
  if !isempty(x.t)
    print(io, "\n", "  "^level, "(then")
    printwasm_(io, x.t, level+1)
  end
  if !isempty(x.f)
    print(io, ")\n", "  "^level, "(else")
    printwasm_(io, x.f, level+1)
  end
  print(io, ")")
end

function printwasm(io, x::Block, level)
  print(io, "block")
  printwasm_(io, x.body, level+1)
end

function printwasm(io, x::Loop, level)
  print(io, "loop")
  printwasm_(io, x.body, level+1)
end

Base.show(io::IO, i::Union{Block,Loop,If}) = printwasm(io, i, 0)

function Base.show(io::IO, f::Func)
  print(io, "(func")
  foreach(p -> print(io, " (param $p)"), f.params)
  foreach(p -> print(io, " (result $p)"), f.returns)
  if !isempty(f.locals)
    print(io, "\n ")
    foreach(p -> print(io, " (local $p)"), f.locals)
  end
  printwasm_(io, f.body.body, 1)
  print(io, ")")
end
