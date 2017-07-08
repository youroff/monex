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

  defmacro error({e1, e2}) do
    quote do
      {:error, unquote(e1), unquote(e2)}
    end
  end

  defmacro error(err) do
    quote do
      {:error, unquote(err)}
    end
  end

  @typedoc """
  Result type.
  `ok(x)` or `error(err)` unwraps into `{:ok, x}` or `{:error, err}`
  """
  @type t :: {:ok, term} | {:error, term}

  @doc """
  Returns true if argument is `ok()`, false if `error()`
      is_ok(ok(5)) == true
  """
  @spec is_ok(t) :: boolean
  def is_ok(ok(_)), do: true
  def is_ok(error(_)), do: false

  @doc """
  Returns true if argument is `error()`, false if `ok()`
      is_error(error("Error")) == true
  """
  @spec is_error(t) :: boolean
  def is_error(x), do: !is_ok(x)

  @doc """
  Returns value `x` if argument is `ok(x)`, raises `e` if `error(e)`
      5 == unwrap(ok(5))
      10 == unwrap(error(:uh_oh), 10)
  """
  @spec unwrap(t, term) :: term
  def unwrap(result, fallback \\ nil)
  def unwrap(ok(x), _), do: x
  def unwrap(error(m), nil), do: raise m
  def unwrap(error(m), f) when is_function(f, 1), do: f.(m)
  def unwrap(error(m), fallback), do: fallback

  @doc """
  Returns monad if it is `ok()`, or evaluates supplied lambda that expected
  to return another `result`. Returns supplied fallback value, if it's not a function.
      ok(5) |> fallback(fn _ -> 1 end) == ok(5)
      error("WTF") |> fallback(fn m -> ok("\#{m}LOL") end) == ok("WTFLOL")
      error("WTF") |> fallback(ok(5)) == ok(5)
      error("WTF") |> fallback(5) == ok(5)
  """
  @spec fallback(t, term | (term -> t)) :: t
  def fallback(ok(x), _), do: ok(x)
  def fallback(error(m), f) when is_function(f, 1) do
    f.(m)
  end
  def fallback(error(m), ok(x)), do: ok(x)
  def fallback(error(m), x), do: ok(x)

  @doc """
  Filters collection of results, leaving only ok's
      [ok(1), error("oops")] |> collect_ok == [ok(1)]
  """
  @spec collect_ok([t]) :: [term]
  def collect_ok(results) when is_list(results) do
    results
    |> Enum.filter(&is_ok/1)
    |> Enum.map(&unwrap/1)
  end

  @doc """
  Filters collection of results, leaving only errors:
      [ok(1), error("oops")] |> collect_error == [error("oops")]
  """
  @spec collect_error([t]) :: [term]
  def collect_error(results) when is_list(results) do
    results
    |> Enum.filter(&is_error/1)
    |> Enum.map(fn error(m) -> m end)
  end

  @doc """
  Retry in case of error.

  Possible options:
    * `:n` - times to retry
    * `:delay` — delay between retries

  ##Example
      result = retry n: 3, delay: 3000 do
        remote_service()
      end

  This will call `remove_service()` 4 times (1 time + 3 retries) with an interval of 3 seconds.
  """

  defmacro retry(opts \\ [], do: exp) do
    quote do
      n = Keyword.get(unquote(opts), :n, 5)
      delay = Keyword.get(unquote(opts), :delay, 0)
      retry_rec(n, delay, fn -> unquote(exp) end)
    end
  end

  @doc false
  def retry_rec(0, _delay, lambda), do: lambda.()
  def retry_rec(n, delay, lambda) do
    case lambda.() do
      error(_) ->
        :timer.sleep(delay)
        retry_rec(n - 1, delay, lambda)
      ok -> ok
    end
  end

  @doc """
  Wraps expression and returns exception wrapped into `error()` if it happens,
  otherwise `ok(result of expression)`, in case if expression returns result
  type, it won't be wrapped.

  Possible modes:
    * `:full` - returns exception struct intact (default)
    * `:message` — returns error message only
    * `:module` — returns error module only

  ##Example
      try_result do
        5 + 5
      end == ok(10)

      try_result do
        5 / 0
      end == error(%ArithmeticError{message: "bad argument in arithmetic expression"})

      try_result :message do
        5 / 0
      end == error("bad argument in arithmetic expression")
  """

  # TODO: figure out @spec for this, if it's even possible
  defmacro try_result(mode \\ :full, do: exp) do
    quote do
      try do
        case unquote(exp) do
          ok(res) -> ok(res)
          error(e) -> error(e)
          x -> ok(x)
        end
      rescue
        e -> case unquote(mode) do
          :message -> error(e.message)
          :module -> error(e.__struct__)
          _ -> error(e)
        end
      end
    end
  end
end
