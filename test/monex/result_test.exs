defmodule MonExResultTest do
  use ExUnit.Case
  doctest MonEx.Result, import: true
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
    assert ok(5) |> fallback(fn _ -> 1 end) == ok(5)
    assert error("WTF") |> fallback(fn m -> ok("#{m}LOL") end) == ok("WTFLOL")
    assert error("WTF") |> fallback(ok(5)) == ok(5)
    assert error("WTF") |> fallback(error("OMG")) == error("OMG")
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
    me = self()
    res = ok(5) |> foreach(&(send me, &1))
    assert res == ok(5)
    res = error("Some err") |> foreach(fn -> send me, "WTF" end)
    assert res == error("Some err")
    :timer.sleep(1)
    assert_received 5
    refute_received "WTF"
  end

  test "unwrap" do
    assert 5 == unwrap(ok(5))
    assert_raise RuntimeError, "something bad happened", fn ->
      unwrap(error("something bad happened"))
    end
    assert 10 == unwrap(error(:uh_oh), 10)
    assert error("WTF") |> unwrap(fn m -> "#{m}LOL" end) == "WTFLOL"
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

    res = retry n: 3 do
      task.()
    end
    assert res == error("Nay")

    res = retry [n: 3], do: task.()
    assert res == ok("Yay")
    Agent.stop(counter)
  end

  test "try_result" do
    assert ok(10) == try_result(do: ok(10))
    assert error(:oh) == try_result(do: error(:oh))

    res = try_result do
      5 + 5
    end
    assert res == ok(10)

    failing = fn ->
      raise ArithmeticError, [message: "bad argument in arithmetic expression"]
    end

    res = try_result do
      failing.()
    end
    assert res == error(%ArithmeticError{message: "bad argument in arithmetic expression"})
    assert error("bad argument in arithmetic expression") == try_result :message, do: failing.()
    assert error(ArithmeticError) == try_result :module, do: failing.()
  end
end
