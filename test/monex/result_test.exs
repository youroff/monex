defmodule MonExResultTest do
  use ExUnit.Case
  doctest MonEx.Result
  import MonEx.Result
  import MonEx

  test "basic" do
    a = ok(5)
    b = error("WTF??")
    
    assert {:ok, 5} == a
    assert {:error, "WTF??"} == b
    
    ok(x) = a
    assert x == 5
  end

  test "is_ok" do
    assert is_ok(ok(5))
    refute is_ok(error("Error"))
  end

  test "is_error" do
    assert is_error(error("Error"))
    refute is_error(ok(5))
  end
  
  test "fallback" do
    assert ok(5) |> fallback(1) == 5
    assert error("WTF") |> fallback(1) == 1
  end

  test "map" do
    assert ok(5) |> map(&(&1 * 2)) == ok(10)
    assert error("Error") |> map(&(&1 * 2)) == error("Error")
  end

  test "flat_map" do
    assert ok(5) |> flat_map(&(ok(&1 * 2))) == ok(10)
    assert error("Error") |> flat_map(&(ok(&1 * 2))) == error("Error")
  end

  test "foreach" do
    me = self
    ok(5) |> foreach(&(send me, &1))
    error("Some err") |> foreach(fn -> send me, "WTF" end)
    :timer.sleep(1)
    assert_received 5
    refute_received "WTF"
  end
  
  test "unwrap" do
    assert 5 == unwrap(ok(5))
    assert_raise RuntimeError, "something bad happened", fn ->
      unwrap(error("something bad happened"))
    end
  end
  
  test "collect_ok" do
    assert [1, 2] == collect_ok [ok(1), ok(2), error("Err")]
  end

  test "collect_error" do
    assert ["Err"] == collect_error [ok(1), ok(2), error("Err")]
  end

  test "retry" do
    res = retry do
      error("Aw")
    end
    assert res == error("Aw")
    
    res = retry do
      ok("Yay")
    end
    assert res == ok("Yay")
  end

  test "retry non-idempotent" do
    ok(counter) = Agent.start_link fn -> 0 end
    task = fn ->
      Agent.update(counter, & &1 + 1)
      if Agent.get(counter, & &1) > 5 do
        ok("Yay")
      else
        error("Nay")
      end    
    end

    res = retry [n: 3], do: task.()
    assert res == error("Nay")

    res = retry [n: 3], do: task.()
    assert res == ok("Yay")
  end
end
