defmodule MonEx.Result do
  @moduledoc """
  Result module provides Result type with utility functions.
  """
  require Record

  defmacro ok(res) do
    quote do
      {:ok, unquote(res)}
    end
  end

  defmacro error(err) do
    quote do
      {:error, unquote(err)}
    end
  end

  @typedoc """
  Result type.
  ok(x) or error(err) unwraps into {:ok, x} or {:error, err}
  """
  @type t :: {:ok, term} | {:error, term}

  @doc """
  Returns true if argument is ok(), false if error()
  """
  @spec is_ok(t) :: boolean
  def is_ok(ok(_)), do: true
  def is_ok(error(_)), do: false

  @doc """
  Returns true if argument is error(), false if ok()
  """
  @spec is_error(t) :: boolean
  def is_error(x), do: !is_ok(x)

  @doc """
  Returns value x if argument is ok(x), raises err if error(err)
  """
  @spec unwrap(t) :: term
  def unwrap(ok(x)), do: x
  def unwrap(error(m)), do: raise m

  @doc """
  Returns value x if argument is ok(x), second argument z if error.
  """
  @spec fallback(t, term) :: term
  def fallback(ok(x), _), do: x
  def fallback(error(_), z), do: z

  @doc """
  Filters collection or results so that only oks left
  """
  @spec collect_ok([t]) :: [term]
  def collect_ok(results) do
    results
    |> Enum.filter(&is_ok/1)
    |> Enum.map(&unwrap/1)
  end

  @doc """
  Filters collection or results so that only errors left
  """
  @spec collect_error([t]) :: [term]
  def collect_error(results) do
    results
    |> Enum.filter(&is_error/1)
    |> Enum.map(fn error(m) -> m end)
  end
end
