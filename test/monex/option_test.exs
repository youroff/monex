defmodule MonExOptionTest do
  use ExUnit.Case
  doctest MonEx.Option
  import MonEx.Option
  import MonEx

  test "basic" do
    a = some(5)
    b = none

    assert {:some, 5} == a
    assert {:none} == b

    some(x) = a
    assert x == 5
    assert none = b
  end
  
  test "is_some" do
    assert is_some(some(5))
    refute is_some(none)
  end
  
  test "is_none" do
    assert is_none(none)
    refute is_none(some(5))
  end
  
  test "to_option" do
    a = to_option(5)
    b = to_option(nil)
    assert some(5) == a
    assert none == b
  end

  test "get" do
    assert some(5) |> get == 5
    assert_raise RuntimeError, "Can't get value of None", fn ->
      get(none)
    end
  end

  test "get_or_else" do
    assert some(5) |> get_or_else(1) == 5
    assert none |> get_or_else(1) == 1
  end

  test "map" do
    assert some(5) |> map(&(&1 * 2)) == some(10)
    assert none |> map(&(&1 * 2)) == none
  end

  test "flat_map" do
    assert some(5) |> flat_map(&(some(&1 * 2))) == some(10)
    assert none |> flat_map(&(some(&1 * 2))) == none
  end

  test "foreach" do
    me = self
    some(5) |> foreach(&(send me, &1))
    none |> foreach(fn -> send me, "WTF" end)
    :timer.sleep(1)
    assert_received 5
    refute_received "WTF"
  end
end
