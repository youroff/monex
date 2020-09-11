defmodule MonEx.Arrows do
  @moduledoc """
  Arrows module inroduces short syntax for MonEx.map/2 and MonEx.flat_map/2.
  """

  alias MonEx.{Option, Result}
  @typep m(a, b) :: Option.t(a) | Result.t(a, b)

  @doc """
  Alias for MonEx.map/2 to be used in infix position.

  Example:
      iex> f = fn (x) ->
      ...>   x * 2
      ...> end
      ...> some(5) ~> f
      some(10)

      ...> none() ~> f
      some(5)
  """
  @spec m(a, b) ~> (a -> c) :: m(c, b) when a: any, b: any, c: any
  def m ~> f, do: MonEx.map(m, f)

  @doc """
  Alias for MonEx.flat_map/2 to be used in infix position.

  Example:
      iex> f = fn (x) ->
      ...>   ok(x * 2)
      ...> end
      ...> ok(5) ~>> f
      ok(10)

      ...> error("Error") ~>> f
      error("Error")
  """
  @spec m(a, b) ~>> (a -> m(c, d)) :: m(c, d) when a: any, b: any, c: any, d: any
  def m ~>> f, do: MonEx.flat_map(m, f)
end
