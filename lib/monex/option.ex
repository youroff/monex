defmodule MonEx.Option do
  @moduledoc """
  Option module provides Option type with utility functions.
  """
  
  defmacro some(val) do
    quote do
      {:some, unquote(val)}
    end
  end

  defmacro none do
    quote do
      {:none}
    end
  end

  @typedoc """
  Option type.
  `some(x)` or `none()` unwraps into `{:some, x}` or `{:none}`
  """
  @type t :: {:some, term} | {:none}

  @doc """
  Returns true if argument is `some()` false if `none()`
      is_some(some(5)) == true
  """
  @spec is_some(t) :: boolean
  def is_some(some(_)), do: true
  def is_some(none()), do: false

  @doc """
  Returns true if argument is `none()` false if `some()`
      is_none(none()) == true
  """
  @spec is_none(t) :: boolean
  def is_none(x), do: !is_some(x)

  @doc """
  Converts arbitrary term into option, `some(term)` if not nil, `none()` otherwise
      to_option(5) == some(5)
      to_option(nil) == none()
  """
  @spec to_option(term) :: t
  def to_option(nil), do: none()
  def to_option(x), do: some(x)

  @doc """
  Returns option if argument is `some()`, second argument wrapped in some otherwise.
  Executes function, if it's supplied.
      some(5) |> or_else(2) == some(5)
      none() |> or_else(2) == some(2)
      none() |> or_else(fn -> some(1)) == some(1)
  """
  @spec or_else(t, term | (() -> t)) :: t
  def or_else(some(_) = x, _), do: x
  def or_else(none(), f) when is_function(f, 0) do
    f.()
  end
  def or_else(none(), z), do: some(z)

  @doc """
  Returns content of option if argument is some(), raises otherwise
      some(5) |> get == 5
  """
  @spec get(t) :: term
  def get(some(x)), do: x
  def get(none()), do: raise "Can't get value of None"

  @doc """
  Returns content of option if argument is some(), second argument otherwise.
      some(5) |> get_or_else(2) == 5
      none() |> get_or_else(2) == 2
      none() |> get_or_else(fn -> 1) == 1
  """
  @spec get_or_else(t, term | (() -> term)) :: term
  def get_or_else(some(x), _), do: x
  def get_or_else(none(), f) when is_function(f, 0) do
    f.()
  end
  def get_or_else(none(), z), do: z
end
