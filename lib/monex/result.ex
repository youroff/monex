defmodule MonEx.Result do
  @moduledoc """
  Result module provides Result type with utility functions.
  """

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
  `ok(res)` or `error(err)` unwraps into `{:ok, res}` or `{:error, err}`
  """
  @type t(res, err) :: {:ok, res} | {:error, err}

  @doc """
  Returns true if argument is `ok()`, false if `error()`

  ## Examples
      iex> is_ok(ok(5))
      true

      iex> is_error(ok(5))
      false
  """
  @spec is_ok(t(any, any)) :: boolean
  def is_ok(ok(_)), do: true
  def is_ok(error(_)), do: false

  @doc """
  Returns true if argument is `error()`, false if `ok()`

  ## Examples
      iex> is_error(error("Error"))
      true

      iex> is_ok(error("Error"))
      false
  """
  @spec is_error(t(any, any)) :: boolean
  def is_error(x), do: !is_ok(x)

  @doc """
  Returns value `x` if argument is `ok(x)`, raises `e` if `error(e)`.
  Second argument is a fallback. It can by a lambda accepting error, or some precomputed default value.

  ## Examples
      iex> unwrap(ok(5))
      5

      iex> unwrap(error(:uh_oh), fn _ -> 10 end)
      10

      iex> unwrap(error(:uh_oh), 10)
      10
  """
  @spec unwrap(t(res, err), res | (err -> res)) :: res when res: any, err: any
  def unwrap(result, fallback \\ nil)
  def unwrap(ok(x), _), do: x
  def unwrap(error(m), nil), do: raise m
  def unwrap(error(m), f) when is_function(f, 1), do: f.(m)
  def unwrap(error(_), fallback), do: fallback

  @doc """
  Returns self if it is `ok(x)`, or evaluates supplied lambda that expected
  to return another `result`. Returns supplied fallback result, if second argument is not a function.

  ## Examples
      iex> ok(5) |> fallback(fn _ -> 1 end)
      ok(5)

      iex> error("WTF") |> fallback(fn m -> ok("\#{m}LOL") end)
      ok("WTFLOL")

      iex> error("WTF") |> fallback(ok(5))
      ok(5)
  """
  @spec fallback(t(res, err), t(res, err) | (err -> t(res, err))) :: t(res, err) when res: any, err: any
  def fallback(ok(x), _), do: ok(x)
  def fallback(error(m), f) when is_function(f, 1) do
    f.(m)
  end
  def fallback(error(_), any), do: any

  @doc """
  Filters and unwraps the collection of results, leaving only ok's

  ## Examples
      iex> [ok(1), error("oops")] |> collect_ok
      [1]
  """
  @spec collect_ok([t(res, any)]) :: [res] when res: any
  def collect_ok(results) when is_list(results) do
    Enum.reduce(results, [], fn
      ok(res), acc -> [res | acc]
      error(_), acc -> acc
    end) |> Enum.reverse
  end

  @doc """
  Filters and unwraps the collection of results, leaving only errors:

  ## Examples
      iex> [ok(1), error("oops")] |> collect_error
      ["oops"]
  """
  @spec collect_error([t(res, err)]) :: [err] when res: any, err: any
  def collect_error(results) when is_list(results) do
    Enum.reduce(results, [], fn
      ok(_), acc -> acc
      error(err), acc -> [err | acc]
    end) |> Enum.reverse
  end

  @doc """
  Groups and unwraps the collection of results, forming a Map with keys `:ok` and `:error`:

  ## Examples
      iex> [ok(1), error("oops"), ok(2)] |> partition
      %{ok: [1, 2], error: ["oops"]}
  """
  @spec partition([t(res, err)]) :: %{ok: [res], error: [err]} when res: any, err: any
  def partition(results) when is_list(results) do
    Enum.group_by(results, fn
      ok(_) -> :ok
      error(_) -> :error
    end, fn
      ok(res) -> res
      error(err) -> err
    end)
  end

  @doc """
  Retry in case of error.

  Possible options:
    * `:n` - times to retry
    * `:delay` — delay between retries

  ## Examples
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
  @spec retry_rec(integer, integer, (() -> t(res, err))) :: t(res, err) when res: any, err: any
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

  ## Examples
      iex> try_result do
      ...>   5 + 5
      ...> end
      ok(10)

      iex> try_result do
      ...>   5 / 0
      ...> end
      error(%ArithmeticError{message: "bad argument in arithmetic expression"})

      iex> try_result :message do
      ...>  5 / 0
      ...> end
      error("bad argument in arithmetic expression")
  """

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
