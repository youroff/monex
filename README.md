# Monex

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

See dosc per Result and Option modules for details. [docs](https://hexdocs.pm/monex/api-reference.html).

## Installation

The package can be installed as:

  1. Add `monex` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:monex, "~> 0.1.0"}]
    end
    ```
