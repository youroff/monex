defmodule MonEx do
  @moduledoc ~S"""
  MonEx implements two of the most common monadic data types:

    * `MonEx.Result` — container for either a successful result or an error.
      Build one with the constructor macros: `ok(value)` for success and
      `error(e)` for failure. Underneath it's a tuple — `{:ok, value}` or
      `{:error, e}` — which lines up cleanly with idiomatic Elixir return
      values.

    * `MonEx.Option` — container for a value that may or may not be present.
      Use `some(value)` to wrap a present value and `none()` to represent
      its absence. Mind the parentheses — they matter when pattern matching.

    * `MonEx` — utility functions (`map/2`, `flat_map/2`, `foreach/2`) that
      work uniformly on both types.

  ## Result

  `Result` fits naturally on top of Erlang/Elixir return conventions.
  Whenever a function returns `{:ok, val}` or `{:error, err}`, MonEx
  combinators apply directly. They shine in pipelines where each step
  may fail. Without MonEx that typically becomes a stack of nested
  `case` expressions:

  ```elixir
  final = case op1(x) do
    {:ok, res1} ->
      case op2(res1) do
        {:ok, res2} -> op3(res2)
        {:error, e} -> {:error, e}
      end
    {:error, e} -> {:error, e}
  end
  ```

  With `flat_map/2` it collapses to:

  ```elixir
  final = op1(x) |> flat_map(&op2/1) |> flat_map(&op3/1)
  ```

  As soon as one step returns `error(e)`, the rest are skipped and the
  error propagates. You can then either pattern match on the outcome or
  fall back to a default value or function:

  ```elixir
  case final do
    ok(value) -> IO.puts(value)
    error(_)  -> IO.puts("Oh no, an error occurred!")
  end

  final |> fallback(ok("No problem, I got it"))
  ```

  ## Option

  `Option` wraps a value: `some(value)` if it's there, `none()` if not.
  The same `map`, `flat_map`, etc. work uniformly:

  ```elixir
  find_user(id)
  |> map(&find_posts_by_user/1)
  ```

  Posts are only fetched when the user was found; otherwise `none()`
  short-circuits through.

  See `MonEx.Result` and `MonEx.Option` for the full surface.
  """
  import MonEx.{Option, Result}
  alias MonEx.{Option, Result}
  @typep m(a, b) :: Option.t(a) | Result.t(a, b)

  @doc """
  Applies `f` to the value inside `ok`/`some`. Returns `error`/`none`
  unchanged.

  ## Example
      f = fn x -> x * 2 end

      some(5)      |> map(f) == some(10)
      none()       |> map(f) == none()
      ok(5)        |> map(f) == ok(10)
      error(:oops) |> map(f) == error(:oops)
  """
  @spec map(m(a, b), (a -> c)) :: m(c, b) when a: any, b: any, c: any
  def map(some(x), f) when is_function(f, 1), do: some(f.(x))
  def map(none(), f) when is_function(f, 1), do: none()

  def map(ok(x), f) when is_function(f, 1), do: ok(f.(x))
  def map(error(m), f) when is_function(f, 1), do: error(m)

  @doc """
  Like `map/2`, but `f` itself returns a value of the same monadic type.
  Useful for chaining operations that each can fail or return nothing —
  the wrapper isn't doubled up.

  ## Example
      inverse = fn x ->
        if x == 0, do: none(), else: some(1 / x)
      end

      some(5) |> flat_map(inverse) == some(0.2)
      some(0) |> flat_map(inverse) == none()
  """
  @spec flat_map(m(a, b), (a -> m(c, b))) :: m(c, b) when a: any, b: any, c: any
  def flat_map(some(x), f) when is_function(f, 1), do: f.(x)
  def flat_map(none(), f) when is_function(f, 1), do: none()

  def flat_map(ok(x), f) when is_function(f, 1), do: f.(x)
  def flat_map(error(m), f) when is_function(f, 1), do: error(m)

  @doc """
  Calls `f` on the wrapped value for its side effects, then returns the
  original container unchanged. Unlike a typical `foreach` (which returns
  Unit), this one passes the input through, so calls can be chained.

  ## Example
      some(5)
      |> foreach(fn x -> IO.inspect(x) end)
      |> foreach(fn x -> IO.inspect(2 * x) end)

  Prints `5` and then `10` on separate lines and evaluates back to `some(5)`.
  """
  @spec foreach(m(a, b), (a -> any)) :: m(a, b) when a: any, b: any
  def foreach(some(x) = res, f) when is_function(f, 1), do: (f.(x); res)
  def foreach(none() = z, _), do: z

  def foreach(ok(x) = res, f) when is_function(f, 1), do: (f.(x); res)
  def foreach(error(_) = z, _), do: z
end
