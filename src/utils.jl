using MacroTools

struct Variable
  name::Symbol
  number::Int
end

Symbol(x::Variable) = Symbol(x.name, x.number)

Base.show(io::IO, x::Variable) = print(io, ":(", x.name, x.number, ")")

Base.print(io::IO, x::Variable) = Base.show_unquoted(io, x, 0, -1)
Base.show_unquoted(io::IO, x::Variable, ::Int, ::Int) =
  print(io, x.name, x.number)

struct Wengert
  variable::Symbol
  instructions::Vector{Any}
end

Wengert(; variable = :x) = Wengert(variable, [])

Base.keys(w::Wengert) = (Variable(w.variable, i) for i = 1:length(w.instructions))
Base.lastindex(w::Wengert) = Variable(w.variable, length(w.instructions))

Base.getindex(w::Wengert, v::Variable) = w.instructions[v.number]

function Base.show(io::IO, w::Wengert)
  println(io, "Wengert List")
  for (i, x) in enumerate(w.instructions)
    print(io, Variable(w.variable, i), " = ")
    Base.println(io, x)
  end
end

Base.push!(w::Wengert, x) = x

function Base.push!(w::Wengert, x::Expr)
  isexpr(x, :block) && return pushblock!(w, x)
  x = Expr(x.head, map(x -> x isa Expr ? push!(w, x) : x, x.args)...)
  push!(w.instructions, x)
  return lastindex(w)
end

function pushblock!(w::Wengert, x)
  bs = Dict()
  rename(ex) = Expr(ex.head, map(x -> get(bs, x, x), ex.args)...)
  for arg in MacroTools.striplines(x).args
    if @capture(arg, x_ = y_)
      bs[x] = push!(w, rename(y))
    else
      push!(w, rename(arg))
    end
  end
  return Variable(w.variable, length(w.instructions))
end

function Wengert(ex; variable = :x)
  w = Wengert(variable = variable)
  push!(w, ex)
  return w
end

function Expr(w::Wengert)
  cs = Dict()
  for x in w.instructions
    x isa Expr || continue
    for v in x.args
      v isa Variable || continue
      cs[v] = get(cs, v, 0) + 1
    end
  end
  bs = Dict()
  rename(ex::Expr) = Expr(ex.head, map(x -> get(bs, x, x), ex.args)...)
  rename(x) = x
  ex = :(;)
  for v in keys(w)
    if get(cs, v, 0) > 1
      push!(ex.args, :($(Symbol(v)) = $(rename(w[v]))))
      bs[v] = Symbol(v)
    else
      bs[v] = rename(w[v])
    end
  end
  push!(ex.args, rename(bs[lastindex(w)]))
  return unblock(ex)
end
