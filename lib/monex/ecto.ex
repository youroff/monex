defmodule MonEx.Ecto do
  @moduledoc """
  Ecto extensions for MonEx.

  `use MonEx.Ecto` inside an `Ecto.Repo` to add Option-returning lookups
  and a Multi result repacker. Requires the consumer app to depend on
  `:ecto`.

  ## Usage

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
        use MonEx.Ecto
      end

  This injects `one_option/2`, `get_option/3`, and `get_by_option/3` into
  the host Repo and exposes `repack_multi/1,2`. The `*_option` helpers
  wrap the standard `nil`-returning Repo callbacks into `MonEx.Option`:

      MyApp.Repo.get_option(User, user_id)
      |> map(&do_something/1)
      |> get_or_else(default_user())

  `repack_multi/2` normalises the outcome of `Repo.transaction/1` on an
  `Ecto.Multi` into a `MonEx.Result`, handling both the success shape
  (`{:ok, changes}`) and the failure shape
  (`{:error, operation, value, changes_so_far}`).
  """

  import MonEx.Result, only: [ok: 1, error: 1]

  @doc false
  defmacro __using__(_opts) do
    quote do
      @doc """
      Calls `c:Ecto.Repo.one/2` and lifts the result into `MonEx.Option`.
      `nil` becomes `none()`, a row becomes `some(row)`.
      """
      @spec one_option(Ecto.Queryable.t, Keyword.t) :: MonEx.Option.t(Ecto.Schema.t)
      def one_option(queryable, opts \\ []) do
        one(queryable, opts) |> MonEx.Option.to_option()
      end

      @doc """
      Calls `c:Ecto.Repo.get/3` and lifts the result into `MonEx.Option`.
      Short-circuits to `none()` when `id` itself is `nil`, without
      hitting the database.
      """
      @spec get_option(Ecto.Queryable.t, term, Keyword.t) :: MonEx.Option.t(Ecto.Schema.t)
      def get_option(queryable, id, opts \\ [])
      def get_option(_, nil, _), do: MonEx.Option.none()
      def get_option(queryable, id, opts) do
        get(queryable, id, opts) |> MonEx.Option.to_option()
      end

      @doc """
      Calls `c:Ecto.Repo.get_by/3` and lifts the result into `MonEx.Option`.
      `nil` becomes `none()`, a row becomes `some(row)`.
      """
      @spec get_by_option(Ecto.Queryable.t, Keyword.t | map, Keyword.t) :: MonEx.Option.t(Ecto.Schema.t)
      def get_by_option(queryable, clauses, opts \\ []) do
        get_by(queryable, clauses, opts) |> MonEx.Option.to_option()
      end

      defdelegate repack_multi(result), to: MonEx.Ecto
      defdelegate repack_multi(result, opts), to: MonEx.Ecto
    end
  end

  @doc """
  Repacks the result of `Repo.transaction/1` on an `Ecto.Multi` into a
  `MonEx.Result`.

  On success, the changes map is normalised: entries shaped as
  `{value, ret}` tuples (the convention used by `Ecto.Multi.run/3`
  callbacks) are unwrapped to either `value` or `ret` depending on
  whether `ret` is `nil`.

  ## Options

    * `:error` — what to surface when the Multi failed:
      * `:all` (default) — `{operation, value, changes_so_far}` tuple
      * `:operation` — just the failed operation's name
      * `:value` — just the failed operation's value (e.g. a changeset)
      * `:changes` — just the changes accumulated before the failure

    * `:result` — what to surface on success:
      * `:all` (default) — the full normalised changes map
      * an operation name — just that operation's value, looked up in
        the changes map (returns `ok(nil)` if absent)

  ## Examples
      iex> MonEx.Ecto.repack_multi({:ok, %{a: 1, b: 2}})
      {:ok, %{a: 1, b: 2}}

      iex> MonEx.Ecto.repack_multi({:ok, %{a: 1, b: 2}}, result: :a)
      {:ok, 1}

      iex> MonEx.Ecto.repack_multi({:error, :step, :boom, %{}})
      {:error, {:step, :boom, %{}}}

      iex> MonEx.Ecto.repack_multi({:error, :step, :boom, %{}}, error: :value)
      {:error, :boom}
  """
  @spec repack_multi(
          {:ok, map}
          | {:error, Ecto.Multi.name(), any, %{required(Ecto.Multi.name()) => any}},
          Keyword.t
        ) :: MonEx.Result.t(any, any)
  def repack_multi(result, opts \\ [])

  def repack_multi({:error, failed_operation, failed_value, changes_so_far}, opts) do
    case Keyword.get(opts, :error, :all) do
      :all       -> error({failed_operation, failed_value, changes_so_far})
      :operation -> error(failed_operation)
      :value     -> error(failed_value)
      :changes   -> error(changes_so_far)
    end
  end

  def repack_multi(ok(changes), opts) do
    results = Enum.map(changes, fn
      {key, {val, nil}} -> {key, val}
      {key, {_, ret}}   -> {key, ret}
      default           -> default
    end) |> Enum.into(%{})

    case Keyword.get(opts, :result, :all) do
      :all -> ok(results)
      key  -> ok(Map.get(results, key))
    end
  end
end
