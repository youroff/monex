defmodule MonExEctoTest do
  @moduledoc """
  Tests for the pure parts of `MonEx.Ecto`. The `__using__` macro injects
  Repo wrappers that need a real Ecto.Repo + database to exercise; that
  surface is intentionally not covered here and is expected to be tested
  via integration in consumer applications.
  """

  use ExUnit.Case
  doctest MonEx.Ecto, import: true
  import MonEx.Result
  alias MonEx.Ecto, as: ME

  describe "repack_multi/2 on success" do
    test "default :all returns the changes map wrapped in ok" do
      assert ME.repack_multi({:ok, %{a: 1, b: 2}}) == ok(%{a: 1, b: 2})
    end

    test "explicit :all matches default" do
      assert ME.repack_multi({:ok, %{a: 1}}, result: :all) == ok(%{a: 1})
    end

    test "specific key extracts that op's value" do
      assert ME.repack_multi({:ok, %{a: 1, b: 2}}, result: :b) == ok(2)
    end

    test "missing key yields ok(nil)" do
      assert ME.repack_multi({:ok, %{a: 1}}, result: :missing) == ok(nil)
    end

    test "{val, nil} entry shape unwraps to val" do
      assert ME.repack_multi({:ok, %{a: {42, nil}}}) == ok(%{a: 42})
    end

    test "{_, ret} entry shape unwraps to ret" do
      assert ME.repack_multi({:ok, %{a: {:ignored, :returned}}}) == ok(%{a: :returned})
    end

    test "mixed entry shapes are normalized together" do
      changes = %{a: {1, nil}, b: {:_, :two}, c: 3}
      assert ME.repack_multi({:ok, changes}) == ok(%{a: 1, b: :two, c: 3})
    end
  end

  describe "repack_multi/2 on failure" do
    @failure {:error, :step, :boom, %{prev: 1}}

    test "default :all returns the {operation, value, changes} tuple" do
      assert ME.repack_multi(@failure) == error({:step, :boom, %{prev: 1}})
    end

    test ":operation returns just the failed operation name" do
      assert ME.repack_multi(@failure, error: :operation) == error(:step)
    end

    test ":value returns just the failed value" do
      assert ME.repack_multi(@failure, error: :value) == error(:boom)
    end

    test ":changes returns the changes accumulated so far" do
      assert ME.repack_multi(@failure, error: :changes) == error(%{prev: 1})
    end
  end
end
