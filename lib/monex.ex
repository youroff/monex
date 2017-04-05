defmodule MonEx do
  @moduledoc """
  A collection of simple monadic types: Option, Result.
  """
  import MonEx.{Option, Result}
  @type monadic :: MonEx.Option.t | MonEx.Result.t

  @doc """
  Applies function to content of monadic type:

  Example:
    f = fn (x) -> x * 2 end
    some(5) |> map(f) == some(10)
    none() |> map(f) == none()
  """
  @spec map(monadic, (term -> term)) :: monadic
  def map(some(x), f) when is_function(f, 1), do: some(f.(x))
  def map(none(), f) when is_function(f, 1), do: none()

  def map(ok(x), f) when is_function(f, 1), do: ok(f.(x))
  def map(error(m), f) when is_function(f, 1), do: error(m)

  @doc """
  Applies function returning to content of monadic type:

  Example:
    inverse = fn (x) -> if x == 0, do: none(), else: some(1/x) end
    some(5) |> flat_map(f) == some(1/5)
    some(0) |> flat_map(f) == none()
  """
  @spec flat_map(monadic, (term -> monadic)) :: monadic
  def flat_map(some(x), f) when is_function(f, 1), do: f.(x)
  def flat_map(none(), f) when is_function(f, 1), do: none()

  def flat_map(ok(x), f) when is_function(f, 1), do: f.(x)
  def flat_map(error(m), f) when is_function(f, 1), do: error(m)

  @doc """
  Calls supplied function with content of monadic type as an argument, returns argument intact
  """
  @spec foreach(monadic, (term -> no_return)) :: monadic
  def foreach(some(x) = res, f) when is_function(f, 1), do: (f.(x); res)
  def foreach(none() = z, _), do: z

  def foreach(ok(x) = res, f) when is_function(f, 1), do: (f.(x); res)
  def foreach(error(_) = z, _), do: z
end
