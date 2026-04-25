defmodule MonEx.Result do
  @moduledoc """
  A `Result` represents the outcome of an operation that can fail:

    * `ok(value)` — success, carrying a value
    * `error(reason)` — failure, carrying a reason

  The runtime representation is just an idiomatic Elixir tuple
  (`{:ok, value}` or `{:error, reason}`), so MonEx slots in on top of any
  function that already returns those.
  """

  alias MonEx.Option

  @doc """
  Constructor macro: `ok(res)` expands to `{:ok, res}`. Works in both
  expressions and patterns.
  """
  defmacro ok(res) do
    quote do
      {:ok, unquote(res)}
    end
  end

  @doc """
  Constructor macro: `error(err)` expands to `{:error, err}`. Works in
  both expressions and patterns.
  """
  defmacro error(err) do
    quote do
      {:error, unquote(err)}
    end
  end

  @typedoc """
  Result type.
  `ok(res)` and `error(err)` expand to `{:ok, res}` and `{:error, err}` respectively.
  """
  @type t(res, err) :: {:ok, res} | {:error, err}

  @doc """
  Returns `true` if the argument is `ok()`, `false` if `error()`.

  ## Examples
      iex> is_ok(ok(5))
      true

      iex> is_ok(error("Error"))
      false
  """
  @spec is_ok(t(any, any)) :: boolean
  def is_ok(ok(_)), do: true
  def is_ok(error(_)), do: false

  @doc """
  Returns `true` if the argument is `error()`, `false` if `ok()`.

  ## Examples
      iex> is_error(error("Error"))
      true

      iex> is_error(ok(5))
      false
  """
  @spec is_error(t(any, any)) :: boolean
  def is_error(x), do: !is_ok(x)

  @doc """
  Returns `x` if the argument is `ok(x)`. Otherwise consults the second
  argument:

    * a 1-arity function — called with the error term; its return is returned
    * any other non-`nil` value — returned as-is
    * `nil` (the default, when no fallback is supplied) — re-raises the error term

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
  Converts a `Result` into an `Option`: `ok(val)` becomes `some(val)`,
  `error(_)` becomes `none()`. Useful when you only care whether a value
  is present and want to drop the error reason.

  ## Examples
      iex> unwrap_option(ok(5))
      {:some, 5} # same as some(5)

      iex> unwrap_option(error(:uh_oh))
      {:none} # same as none()
  """
  @spec unwrap_option(t(res, any)) :: Option.t(res) when res: any
  def unwrap_option(ok(x)), do: {:some, x}
  def unwrap_option(error(_)), do: {:none}

  @doc """
  Returns the input as-is if it is `ok()`. If `error()`, returns the
  second argument — either a `Result` directly, or a 1-arity function
  receiving the error and returning a `Result`.

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
  Walks a list of `Result`s and returns the unwrapped success values,
  preserving order.

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
  Walks a list of `Result`s and returns the unwrapped error reasons,
  preserving order.

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
  Splits a list of `Result`s into a map with `:ok` and `:error` keys
  pointing at the unwrapped values. Both keys are always present, even
  when one bucket is empty.

  ## Examples
      iex> [ok(1), error("oops"), ok(2)] |> partition
      %{ok: [1, 2], error: ["oops"]}

      iex> [ok(1)] |> partition
      %{ok: [1], error: []}
  """
  @spec partition([t(res, err)]) :: %{ok: [res], error: [err]} when res: any, err: any
  def partition(results) when is_list(results) do
    base = %{ok: [], error: []}
    results = Enum.group_by(results, fn
      ok(_) -> :ok
      error(_) -> :error
    end, fn
      ok(res) -> res
      error(err) -> err
    end)
    Map.merge(base, results)
  end

  @doc """
  Re-runs the body block while it returns `error(_)`. The first `ok(_)`
  short-circuits and is returned; if every attempt fails, the last
  `error(_)` is returned.

  ## Options
    * `:n` — number of retries to attempt after the initial call (default: `5`)
    * `:delay` — milliseconds to sleep between attempts (default: `0`)

  ## Example
      result = retry n: 3, delay: 3000 do
        remote_service()
      end

  Calls `remote_service()` up to 4 times (1 initial + 3 retries) with a
  3-second pause between attempts.
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
  Evaluates `exp`, normalising the outcome into a `Result`:

    * a raised exception becomes `error(...)`,
    * a `Result` (`ok(_)` or `error(_)`) returned by `exp` is passed
      through unchanged,
    * any other value `x` becomes `ok(x)`.

  ## Modes
    * `:full` (default) — `error(...)` carries the exception struct
    * `:message` — `error(...)` carries the exception message string
    * `:module` — `error(...)` carries the exception module

  ## Examples
      iex> try_result do
      ...>   5 + 5
      ...> end
      ok(10)

      iex> try_result do
      ...>   raise ArithmeticError, message: "bad argument"
      ...> end
      error(%ArithmeticError{message: "bad argument"})

      iex> try_result :message do
      ...>   raise ArithmeticError, message: "bad argument"
      ...> end
      error("bad argument")

      iex> try_result :module do
      ...>   raise ArithmeticError, message: "bad argument"
      ...> end
      error(ArithmeticError)
  """

  defmacro try_result(mode \\ :full, do: exp) do
    error_handler = case mode do
      :message -> quote do e -> error(e.message) end
      :module -> quote do e -> error(e.__struct__) end
      _ -> quote do e -> error(e) end
    end

    quote do
      try do
        case unquote(exp) do
          ok(res) -> ok(res)
          error(e) -> error(e)
          x -> ok(x)
        end
      rescue
        unquote(error_handler)
      end
    end
  end
end
