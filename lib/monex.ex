defmodule MonEx do
  @moduledoc ~S"""
  MonEx implements two most common monadic data types:

    * `MonEx.Result` - container for a result of operation or error.
      Result can be created using a constructor macro: `ok(value)` or `error(e)`,
      where underlying structure is a tuple: `{:ok, value}` or `{:error, e}` respectively.

    * `MonEx.Option` - container for a value that might be present or missing.
      Use `some(value)` to create Option with value and `none()` to create an empty Option.
      Mind the parentheses, they are important when using it with pattern matching.

    * `MonEx` - collection of utility functions to work with both of these types.

  ## Result

  Result type fits perfectly with idiomatic Erlang/Elixir return values.
  When some library function returns either `{:ok, val}` or `{:error, err}`,
  you can use functions provided by MonEx right away. The most typical example,
  where MonEx shines, is a pipeline, where each operation can fail. Normally
  this would be organized in a form of nested case expressions:

      final = case op1(x) do
        {:ok, res1} ->
          case op2(res1) do
            {:ok, res2} -> op3(res2)
            {:error, e} -> {:error, e}
          end
        {:error, e} -> {:error, e}
      end

  With MonEx you can do the same using `flat_map` operation:

      final = op1(x) |> flat_map(&op2/1) |> flat_map(&op3/1)

  Once any of the operations returns `error(e)`, following operations
  are skipped and the error is returned. You can either do something
  based on pattern matching or provide a fallback (can be a function or a default value).

      case final do
        ok(value) -> IO.puts(value)
        error(e) -> IO.puts("Oh, no, the error occured!")
      end

      final |> fallback(ok("No problem, I got it"))

  ## Option

  Option type wraps the value. If value is present, it's `some(value)`,
  if it's missing, `none()` is used instead. With Option type, you can use the
  same set of functions, such as `map`, `flat_map`, etc.

      find_user(id)
      |> map(&find_posts_by_user/1)

  This will only request for posts if the user was found. Then content of `some()`
  will be transformed into posts, or `none()` will be returned.

  See docs per Result and Option modules for details.
  """
  import MonEx.{Option, Result}
  alias MonEx.{Option, Result}
  @typep m(a, b) :: Option.t(a) | Result.t(a, b)

  @doc """
  Transforms the content of monadic type.
  Function is applied only if it's `ok` or `some`.
  Otherwise value stays intact.

  Example:
      f = fn (x) ->
        x * 2
      end
      some(5) |> map(f) == some(10)
      none() |> map(f) == none()
  """
  @spec map(m(a, b), (a -> c)) :: m(c, b) when a: any, b: any, c: any
  def map(some(x), f) when is_function(f, 1), do: some(f.(x))
  def map(none(), f) when is_function(f, 1), do: none()

  def map(ok(x), f) when is_function(f, 1), do: ok(f.(x))
  def map(error(m), f) when is_function(f, 1), do: error(m)

  @doc """
  Applies function that returns monadic type itself to the content
  of the monadic type. This is useful in a chain of operations, where
  argument to the next op has to be unwrapped to proceed.

  Example:
      inverse = fn (x) ->
        if x == 0 do
          none()
        else
          some(1/x)
        end
      some(5) |> flat_map(f) == some(1/5)
      some(0) |> flat_map(f) == none()
  """
  @spec flat_map(m(a, b), (a -> m(c, b))) :: m(c, b) when a: any, b: any, c: any
  def flat_map(some(x), f) when is_function(f, 1), do: f.(x)
  def flat_map(none(), f) when is_function(f, 1), do: none()

  def flat_map(ok(x), f) when is_function(f, 1), do: f.(x)
  def flat_map(error(m), f) when is_function(f, 1), do: error(m)

  @doc """
  Performs a calculation with the content of monadic container and returns
  the argument intact. Even though the convention says to return nothing (Unit)
  this one passes value along for convenience — this way we can perform more
  than one operation.

      some(5)
      |> foreach(fn x -> IO.inspect(x) end)
      |> foreach(fn x -> IO.inspect(2 * x) end)

  This will print: 5 10
  """
  @spec foreach(m(a, b), (a -> no_return)) :: m(a, b) when a: any, b: any
  def foreach(some(x) = res, f) when is_function(f, 1), do: (f.(x); res)
  def foreach(none() = z, _), do: z

  def foreach(ok(x) = res, f) when is_function(f, 1), do: (f.(x); res)
  def foreach(error(_) = z, _), do: z
end
