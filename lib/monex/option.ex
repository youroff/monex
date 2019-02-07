defmodule MonEx.Option do
  @moduledoc """
  Option module provides Option type with utility functions.
  """

  alias MonEx.Result

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
  `some(a)` or `none()` unwraps into `{:some, a}` or `{:none}`
  """
  @type t(a) :: {:some, a} | {:none}

  @doc """
  Returns true if argument is `some()` false if `none()`

  ## Examples
      iex> is_some(some(5))
      true

      iex> is_some(none())
      false
  """
  @spec is_some(t(any)) :: boolean
  def is_some(some(_)), do: true
  def is_some(none()), do: false

  @doc """
  Returns true if argument is `none()` false if `some()`

  ## Examples
      iex> is_none(none())
      true

      iex> is_none(some(5))
      false
  """
  @spec is_none(t(any)) :: boolean
  def is_none(x), do: !is_some(x)

  @doc """
  Converts arbitrary term into option, `some(term)` if not nil, `none()` otherwise

  ## Examples
      iex> to_option(5)
      some(5)

      iex> to_option(nil)
      none()
  """
  @spec to_option(a) :: t(a) when a: any
  def to_option(nil), do: none()
  def to_option(x), do: some(x)

  @doc """
  Returns option if argument is `some()`, second argument which has to be option otherwise.
  Executes function, if it's supplied.

  ## Examples
      iex> some(5) |> or_else(some(2))
      some(5)

      iex> none() |> or_else(some(2))
      some(2)

      iex> none() |> or_else(fn -> some(1) end)
      some(1)
  """
  @spec or_else(t(a), t(a) | (() -> t(a))) :: t(a) when a: any
  def or_else(some(_) = x, _), do: x
  def or_else(none(), f) when is_function(f, 0) do
    f.()
  end
  def or_else(none(), z), do: z

  @doc """
  Returns content of option if argument is some(), raises otherwise

  ## Examples
      iex> some(5) |> get
      5
  """
  @spec get(t(a)) :: a when a: any
  def get(some(x)), do: x
  def get(none()), do: raise "Can't get value of None"

  @doc """
  Returns content of option if argument is some(), second argument otherwise.

  ## Examples
      iex> some(5) |> get_or_else(2)
      5

      iex> none() |> get_or_else(2)
      2

      iex> none() |> get_or_else(fn -> 1 end)
      1
  """
  @spec get_or_else(t(a), a | (() -> a)) :: a when a: any
  def get_or_else(some(x), _), do: x
  def get_or_else(none(), f) when is_function(f, 0) do
    f.()
  end
  def get_or_else(none(), z), do: z

  @doc """
  Converts an Option into Result if value is present, otherwise returns second argument wrapped in `error()`.

  ## Examples
      iex> some(5) |> ok_or_else(2)
      {:ok, 5} # Essentially ok(5)

      ...> none() |> ok_or_else(:missing_value)
      {:error, :missing_value} # Essentially error(:missing_value)

      ...> none() |> get_or_else(fn -> :oh_no end)
      {:error, :oh_no}
  """
  @spec ok_or_else(t(a), err | (() -> err)) :: Result.t(a, err) when a: any, err: any
  def ok_or_else(some(x), _), do: {:ok, x}
  def ok_or_else(none(), f) when is_function(f, 0) do
    {:error, f.()}
  end
  def ok_or_else(none(), z), do: {:error, z}
end
