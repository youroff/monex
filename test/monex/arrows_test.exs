defmodule MonExArrowsTest do
  use ExUnit.Case
  import MonEx.{Result, Option, Arrows}

  test "map ~>" do
    f = fn (x) ->
      x * 2
    end

    assert some(5) ~> f == some(10)
    assert none() ~> f == none()
  end

  test "flat_map ~>>" do
    assert ok(5) ~>> &(ok(&1 * 2)) == ok(10)
    assert error("Error") ~>> &(ok(&1 * 2)) == error("Error")
  end
end
