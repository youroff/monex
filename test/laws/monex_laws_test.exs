defmodule MonexLawsTest do
  use ExUnit.Case, async: true
  use Lynx.Case

  import MonEx.Arrows
  import MonEx.Result, only: :macros
  import MonEx.Option, only: :macros

  def result?(ok(_)), do: true
  def result?(error(_)), do: true
  def result?(_), do: false

  def option?(some(_)), do: true
  def option?(none()), do: true
  def option?(_), do: false

  def identity(x), do: x
  def tag(x), do: {:tagged, x}
  def stay_ok(x), do: ok(x)
  def stay_error(_), do: error(:e)
  def stay_some(x), do: some(x)
  def stay_none(_), do: none()
  def recover(_), do: ok(:recovered)
  def some_default, do: some(:default)
  def default, do: :default
  def missing, do: :missing

  def map_fun?(f), do: f in [&identity/1, &tag/1]

  def result_fun?(f), do: f in [&identity/1, &tag/1, &stay_ok/1, &stay_error/1]

  def option_fun?(f), do: f in [&identity/1, &tag/1, &stay_some/1, &stay_none/1]

  def result_arrow?(f), do: f in [&stay_ok/1, &stay_error/1]

  def option_arrow?(f), do: f in [&stay_some/1, &stay_none/1]

  laws "shapes" do
    law(is_ok_matches(term),
      requires: result?(term),
      expects: MonEx.Result.is_ok(term) == match?(ok(_), term),
      proof: ~LEAN"""
      simp [«is_ok_matches:requires/1», «result?/1»] at requires
      split at requires <;>
        simp_all [«is_ok_matches:ensures/1», Elixir.MonEx.Result.«is_ok/1», Erlang.erlang.«==/2»]
      """
    )

    law(is_error_is_not_ok(term),
      requires: result?(term),
      expects: MonEx.Result.is_error(term) == not MonEx.Result.is_ok(term),
      proof: ~LEAN"""
      simp [«is_error_is_not_ok:requires/1», «result?/1»] at requires
      split at requires <;>
        simp_all [«is_error_is_not_ok:ensures/1», Elixir.MonEx.Result.«is_error/1»,
          Elixir.MonEx.Result.«is_ok/1», Erlang.erlang.«not/1», Erlang.erlang.«==/2»]
      """
    )

    law(is_some_matches(term),
      requires: option?(term),
      expects: MonEx.Option.is_some(term) == match?(some(_), term),
      proof: ~LEAN"""
      simp [«is_some_matches:requires/1», «option?/1»] at requires
      split at requires <;>
        simp_all [«is_some_matches:ensures/1», Elixir.MonEx.Option.«is_some/1», Erlang.erlang.«==/2»]
      """
    )

    law(is_none_is_not_some(term),
      requires: option?(term),
      expects: MonEx.Option.is_none(term) == not MonEx.Option.is_some(term),
      proof: ~LEAN"""
      simp [«is_none_is_not_some:requires/1», «option?/1»] at requires
      split at requires <;>
        simp_all [«is_none_is_not_some:ensures/1», Elixir.MonEx.Option.«is_none/1»,
          Elixir.MonEx.Option.«is_some/1», Erlang.erlang.«not/1», Erlang.erlang.«==/2»]
      """
    )

    law(to_option_nil,
      expects: MonEx.Option.to_option(nil) == none(),
      proof: ~LEAN"""
      simp [«to_option_nil:ensures/0», Elixir.MonEx.Option.«to_option/1», Erlang.erlang.«==/2»]
      """
    )

    law(to_option_value(x),
      requires: x != nil,
      expects: MonEx.Option.to_option(x) == some(x),
      proof: ~LEAN"""
      by_cases nil : x = Lynx.Term.atom "nil"
      · simp [nil, «to_option_value:requires/1», Erlang.erlang.«/=/2»] at requires
      · simp [nil, «to_option_value:ensures/1», Elixir.MonEx.Option.«to_option/1», Erlang.erlang.«==/2»]
      """
    )

    law(unwrap_option_ok(v),
      expects: MonEx.Result.unwrap_option(ok(v)) == some(v),
      proof: ~LEAN"""
      simp [«unwrap_option_ok:ensures/1», Elixir.MonEx.Result.«unwrap_option/1»,
        Erlang.erlang.«==/2»]
      """
    )

    law(unwrap_option_error(e),
      expects: MonEx.Result.unwrap_option(error(e)) == none(),
      proof: ~LEAN"""
      simp [«unwrap_option_error:ensures/1», Elixir.MonEx.Result.«unwrap_option/1»,
        Erlang.erlang.«==/2»]
      """
    )
  end

  laws "map and flat_map" do
    law(map_error_ignores(reason, f),
      requires: map_fun?(f),
      expects: MonEx.map(error(reason), f) == error(reason),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«map_error_ignores:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «map_error_ignores:ensures/2», Elixir.MonEx.«map/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(map_none_ignores(f),
      requires: map_fun?(f),
      expects: MonEx.map(none(), f) == none(),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«map_none_ignores:requires/1», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «map_none_ignores:ensures/1», Elixir.MonEx.«map/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(flat_map_error_ignores(reason, f),
      requires: map_fun?(f),
      expects: MonEx.flat_map(error(reason), f) == error(reason),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«flat_map_error_ignores:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «flat_map_error_ignores:ensures/2», Elixir.MonEx.«flat_map/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(flat_map_none_ignores(f),
      requires: map_fun?(f),
      expects: MonEx.flat_map(none(), f) == none(),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«flat_map_none_ignores:requires/1», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «flat_map_none_ignores:ensures/1», Elixir.MonEx.«flat_map/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(map_ok(value, f),
      requires: map_fun?(f),
      expects: MonEx.map(ok(value), f) == ok(f.(value)),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«map_ok:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «map_ok:ensures/2», Elixir.MonEx.«map/2», «identity/1», «tag/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(map_some(value, f),
      requires: map_fun?(f),
      expects: MonEx.map(some(value), f) == some(f.(value)),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«map_some:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «map_some:ensures/2», Elixir.MonEx.«map/2», «identity/1», «tag/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(result_left_id(value, f),
      requires: result_fun?(f),
      expects: MonEx.flat_map(ok(value), f) == f.(value),
      proof: ~LEAN"""
      have allowed :
          f = .function 0 1 #[] ∨ f = .function 1 1 #[] ∨
          f = .function 2 1 #[] ∨ f = .function 3 1 #[] := by
        simp [«result_left_id:requires/2», «result_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h0 : f = .function 0 1 #[]
        · exact Or.inl h0
        · by_cases h1 : f = .function 1 1 #[]
          · exact Or.inr (Or.inl h1)
          · by_cases h2 : f = .function 2 1 #[]
            · exact Or.inr (Or.inr (Or.inl h2))
            · exact Or.inr (Or.inr (Or.inr (requires h0 h1 h2)))
      rcases allowed with rfl | rfl | rfl | rfl <;>
        simp [Lynx.apply_eq, «result_left_id:ensures/2», Elixir.MonEx.«flat_map/2»,
          «identity/1», «tag/1», «stay_ok/1», «stay_error/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(option_left_id(value, f),
      requires: option_fun?(f),
      expects: MonEx.flat_map(some(value), f) == f.(value),
      proof: ~LEAN"""
      have allowed :
          f = .function 0 1 #[] ∨ f = .function 1 1 #[] ∨
          f = .function 4 1 #[] ∨ f = .function 5 1 #[] := by
        simp [«option_left_id:requires/2», «option_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h0 : f = .function 0 1 #[]
        · exact Or.inl h0
        · by_cases h1 : f = .function 1 1 #[]
          · exact Or.inr (Or.inl h1)
          · by_cases h2 : f = .function 4 1 #[]
            · exact Or.inr (Or.inr (Or.inl h2))
            · exact Or.inr (Or.inr (Or.inr (requires h0 h1 h2)))
      rcases allowed with rfl | rfl | rfl | rfl <;>
        simp [Lynx.apply_eq, «option_left_id:ensures/2», Elixir.MonEx.«flat_map/2»,
          «identity/1», «tag/1», «stay_some/1», «stay_none/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(result_right_id(container),
      requires: result?(container),
      expects: MonEx.flat_map(container, &stay_ok/1) == container,
      proof: ~LEAN"""
      simp [«result_right_id:requires/1», «result?/1»] at requires
      split at requires <;>
        simp_all [Lynx.apply_eq, «result_right_id:ensures/1», Elixir.MonEx.«flat_map/2»,
          «stay_ok/1», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(option_right_id(container),
      requires: option?(container),
      expects: MonEx.flat_map(container, &stay_some/1) == container,
      proof: ~LEAN"""
      simp [«option_right_id:requires/1», «option?/1»] at requires
      split at requires <;>
        simp_all [Lynx.apply_eq, «option_right_id:ensures/1», Elixir.MonEx.«flat_map/2»,
          «stay_some/1», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(result_assoc_error(reason, f, g),
      requires: result_fun?(f) and result_fun?(g),
      expects:
        MonEx.flat_map(MonEx.flat_map(error(reason), f), g) == error(reason) and
          MonEx.flat_map(error(reason), fn x -> MonEx.flat_map(f.(x), g) end) ==
            error(reason),
      proof: ~LEAN"""
      have mem (x : Lynx.Term) (h : «result_fun?/1» x = Except.ok (Lynx.Term.atom "true")) :
          x = .function 0 1 #[] ∨ x = .function 1 1 #[] ∨
          x = .function 2 1 #[] ∨ x = .function 3 1 #[] := by
        simp [«result_fun?/1», Erlang.lists.«member/2»] at h
        by_cases h0 : x = .function 0 1 #[]
        · exact Or.inl h0
        · by_cases h1 : x = .function 1 1 #[]
          · exact Or.inr (Or.inl h1)
          · by_cases h2 : x = .function 2 1 #[]
            · exact Or.inr (Or.inr (Or.inl h2))
            · exact Or.inr (Or.inr (Or.inr (h h0 h1 h2)))
      simp [«result_assoc_error:requires/3», Lynx.Except.andAlso_eq_true] at requires
      rcases mem f requires.1 with rfl | rfl | rfl | rfl <;>
        rcases mem g requires.2 with rfl | rfl | rfl | rfl <;>
        simp [Lynx.apply_eq, «result_assoc_error:ensures/3», Elixir.MonEx.«flat_map/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2», Lynx.Except.andAlso]
      """
    )

    law(option_assoc_none(f, g),
      requires: option_fun?(f) and option_fun?(g),
      expects:
        MonEx.flat_map(MonEx.flat_map(none(), f), g) == none() and
          MonEx.flat_map(none(), fn x -> MonEx.flat_map(f.(x), g) end) == none(),
      proof: ~LEAN"""
      have mem (x : Lynx.Term) (h : «option_fun?/1» x = Except.ok (Lynx.Term.atom "true")) :
          x = .function 0 1 #[] ∨ x = .function 1 1 #[] ∨
          x = .function 4 1 #[] ∨ x = .function 5 1 #[] := by
        simp [«option_fun?/1», Erlang.lists.«member/2»] at h
        by_cases h0 : x = .function 0 1 #[]
        · exact Or.inl h0
        · by_cases h1 : x = .function 1 1 #[]
          · exact Or.inr (Or.inl h1)
          · by_cases h2 : x = .function 4 1 #[]
            · exact Or.inr (Or.inr (Or.inl h2))
            · exact Or.inr (Or.inr (Or.inr (h h0 h1 h2)))
      simp [«option_assoc_none:requires/2», Lynx.Except.andAlso_eq_true] at requires
      rcases mem f requires.1 with rfl | rfl | rfl | rfl <;>
        rcases mem g requires.2 with rfl | rfl | rfl | rfl <;>
        simp [Lynx.apply_eq, «option_assoc_none:ensures/2», Elixir.MonEx.«flat_map/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2», Lynx.Except.andAlso]
      """
    )

    law(result_assoc_ok(value, f, g),
      requires: result_arrow?(f) and result_arrow?(g),
      expects:
        MonEx.flat_map(MonEx.flat_map(ok(value), f), g) ==
          MonEx.flat_map(ok(value), fn x -> MonEx.flat_map(f.(x), g) end),
      proof: ~LEAN"""
      have mem (x : Lynx.Term) (h : «result_arrow?/1» x = Except.ok (Lynx.Term.atom "true")) :
          x = .function 2 1 #[] ∨ x = .function 3 1 #[] := by
        simp [«result_arrow?/1», Erlang.lists.«member/2»] at h
        by_cases h0 : x = .function 2 1 #[]
        · exact Or.inl h0
        · exact Or.inr (h h0)
      simp [«result_assoc_ok:requires/3», Lynx.Except.andAlso_eq_true] at requires
      rcases mem f requires.1 with rfl | rfl <;>
        rcases mem g requires.2 with rfl | rfl <;>
        simp [Lynx.apply_eq, «result_assoc_ok:ensures/3», Elixir.MonEx.«flat_map/2»,
          «$lynx_fun_8/3», «stay_ok/1», «stay_error/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(option_assoc_some(value, f, g),
      requires: option_arrow?(f) and option_arrow?(g),
      expects:
        MonEx.flat_map(MonEx.flat_map(some(value), f), g) ==
          MonEx.flat_map(some(value), fn x -> MonEx.flat_map(f.(x), g) end),
      proof: ~LEAN"""
      have mem (x : Lynx.Term) (h : «option_arrow?/1» x = Except.ok (Lynx.Term.atom "true")) :
          x = .function 4 1 #[] ∨ x = .function 5 1 #[] := by
        simp [«option_arrow?/1», Erlang.lists.«member/2»] at h
        by_cases h0 : x = .function 4 1 #[]
        · exact Or.inl h0
        · exact Or.inr (h h0)
      simp [«option_assoc_some:requires/3», Lynx.Except.andAlso_eq_true] at requires
      rcases mem f requires.1 with rfl | rfl <;>
        rcases mem g requires.2 with rfl | rfl <;>
        simp [Lynx.apply_eq, «option_assoc_some:ensures/3», Elixir.MonEx.«flat_map/2»,
          «$lynx_fun_9/3», «stay_some/1», «stay_none/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )
  end

  laws "fallbacks" do
    law(fallback_ok(value, other),
      expects: MonEx.Result.fallback(ok(value), other) == ok(value),
      proof: ~LEAN"""
      simp [«fallback_ok:ensures/2», Elixir.MonEx.Result.«fallback/2», Erlang.erlang.«==/2»]
      """
    )

    law(fallback_error_value(reason, other),
      requires: not is_function(other, 1),
      expects: MonEx.Result.fallback(error(reason), other) == other,
      proof: ~LEAN"""
      cases other with
      | function id arity captures =>
        by_cases arityOne : (arity : Int) = 1
        · simp [arityOne, «fallback_error_value:requires/2», Erlang.erlang.«is_function/2»,
            Erlang.erlang.«not/1»] at requires
        · simp [arityOne, Lynx.apply_eq, «fallback_error_value:ensures/2»,
            Elixir.MonEx.Result.«fallback/2», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      | _ =>
        simp [Lynx.apply_eq, «fallback_error_value:ensures/2», Elixir.MonEx.Result.«fallback/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(or_else_some(value, other),
      expects: MonEx.Option.or_else(some(value), other) == some(value),
      proof: ~LEAN"""
      simp [«or_else_some:ensures/2», Elixir.MonEx.Option.«or_else/2», Erlang.erlang.«==/2»]
      """
    )

    law(or_else_none_value(other),
      requires: not is_function(other, 0),
      expects: MonEx.Option.or_else(none(), other) == other,
      proof: ~LEAN"""
      cases other with
      | function id arity captures =>
        by_cases arityZero : arity = 0
        · simp [arityZero, «or_else_none_value:requires/1», Erlang.erlang.«is_function/2»,
            Erlang.erlang.«not/1»] at requires
        · simp [arityZero, Lynx.apply_eq, «or_else_none_value:ensures/1»,
            Elixir.MonEx.Option.«or_else/2», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      | _ =>
        simp [Lynx.apply_eq, «or_else_none_value:ensures/1», Elixir.MonEx.Option.«or_else/2»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(get_or_else_some(value, other),
      expects: MonEx.Option.get_or_else(some(value), other) == value,
      proof: ~LEAN"""
      simp [«get_or_else_some:ensures/2», Elixir.MonEx.Option.«get_or_else/2»,
        Erlang.erlang.«==/2»]
      """
    )

    law(get_or_else_none_value(other),
      requires: not is_function(other, 0),
      expects: MonEx.Option.get_or_else(none(), other) == other,
      proof: ~LEAN"""
      cases other with
      | function id arity captures =>
        by_cases arityZero : arity = 0
        · simp [arityZero, «get_or_else_none_value:requires/1», Erlang.erlang.«is_function/2»,
            Erlang.erlang.«not/1»] at requires
        · simp [arityZero, Lynx.apply_eq, «get_or_else_none_value:ensures/1»,
            Elixir.MonEx.Option.«get_or_else/2», Erlang.erlang.«is_function/2»,
            Erlang.erlang.«==/2»]
      | _ =>
        simp [Lynx.apply_eq, «get_or_else_none_value:ensures/1»,
          Elixir.MonEx.Option.«get_or_else/2», Erlang.erlang.«is_function/2»,
          Erlang.erlang.«==/2»]
      """
    )

    law(ok_or_else_some(value, err),
      expects: MonEx.Option.ok_or_else(some(value), err) == ok(value),
      proof: ~LEAN"""
      simp [«ok_or_else_some:ensures/2», Elixir.MonEx.Option.«ok_or_else/2»,
        Erlang.erlang.«==/2»]
      """
    )

    law(ok_or_else_none_value(err),
      requires: not is_function(err, 0),
      expects: MonEx.Option.ok_or_else(none(), err) == error(err),
      proof: ~LEAN"""
      cases err with
      | function id arity captures =>
        by_cases arityZero : arity = 0
        · simp [arityZero, «ok_or_else_none_value:requires/1», Erlang.erlang.«is_function/2»,
            Erlang.erlang.«not/1»] at requires
        · simp [arityZero, Lynx.apply_eq, «ok_or_else_none_value:ensures/1»,
            Elixir.MonEx.Option.«ok_or_else/2», Erlang.erlang.«is_function/2»,
            Erlang.erlang.«==/2»]
      | _ =>
        simp [Lynx.apply_eq, «ok_or_else_none_value:ensures/1»,
          Elixir.MonEx.Option.«ok_or_else/2», Erlang.erlang.«is_function/2»,
          Erlang.erlang.«==/2»]
      """
    )
  end

  laws "fallback functions" do
    law(fallback_error_fun(reason),
      expects: MonEx.Result.fallback(error(reason), &recover/1) == ok(:recovered),
      proof: ~LEAN"""
      simp [Lynx.apply_eq, «fallback_error_fun:ensures/1», Elixir.MonEx.Result.«fallback/2»,
        «recover/1», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(or_else_none_fun,
      expects: MonEx.Option.or_else(none(), &some_default/0) == some(:default),
      proof: ~LEAN"""
      simp [Lynx.apply_eq, «or_else_none_fun:ensures/0», Elixir.MonEx.Option.«or_else/2»,
        «some_default/0», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(get_or_else_none_fun,
      expects: MonEx.Option.get_or_else(none(), &default/0) == :default,
      proof: ~LEAN"""
      simp [Lynx.apply_eq, «get_or_else_none_fun:ensures/0», Elixir.MonEx.Option.«get_or_else/2»,
        «default/0», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(ok_or_else_none_fun,
      expects: MonEx.Option.ok_or_else(none(), &missing/0) == error(:missing),
      proof: ~LEAN"""
      simp [Lynx.apply_eq, «ok_or_else_none_fun:ensures/0», Elixir.MonEx.Option.«ok_or_else/2»,
        «missing/0», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )
  end

  laws "arrows" do
    law(arrow_map_ok(value, f),
      requires: map_fun?(f),
      expects: ok(value) ~> f == MonEx.map(ok(value), f),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«arrow_map_ok:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_map_ok:ensures/2», Elixir.MonEx.Arrows.«~>/2»,
          Elixir.MonEx.«map/2», «identity/1», «tag/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_map_some(value, f),
      requires: map_fun?(f),
      expects: some(value) ~> f == MonEx.map(some(value), f),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«arrow_map_some:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_map_some:ensures/2», Elixir.MonEx.Arrows.«~>/2»,
          Elixir.MonEx.«map/2», «identity/1», «tag/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_map_error(reason, f),
      requires: map_fun?(f),
      expects: error(reason) ~> f == MonEx.map(error(reason), f),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«arrow_map_error:requires/2», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_map_error:ensures/2», Elixir.MonEx.Arrows.«~>/2»,
          Elixir.MonEx.«map/2», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_map_none(f),
      requires: map_fun?(f),
      expects: none() ~> f == MonEx.map(none(), f),
      proof: ~LEAN"""
      have allowed : f = .function 0 1 #[] ∨ f = .function 1 1 #[] := by
        simp [«arrow_map_none:requires/1», «map_fun?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 0 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_map_none:ensures/1», Elixir.MonEx.Arrows.«~>/2»,
          Elixir.MonEx.«map/2», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_flat_ok(value, f),
      requires: result_arrow?(f),
      expects: ok(value) ~>> f == MonEx.flat_map(ok(value), f),
      proof: ~LEAN"""
      have allowed : f = .function 2 1 #[] ∨ f = .function 3 1 #[] := by
        simp [«arrow_flat_ok:requires/2», «result_arrow?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 2 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_flat_ok:ensures/2», Elixir.MonEx.Arrows.«~>>/2»,
          Elixir.MonEx.«flat_map/2», «stay_ok/1», «stay_error/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_flat_error(reason, f),
      requires: result_arrow?(f),
      expects: error(reason) ~>> f == MonEx.flat_map(error(reason), f),
      proof: ~LEAN"""
      have allowed : f = .function 2 1 #[] ∨ f = .function 3 1 #[] := by
        simp [«arrow_flat_error:requires/2», «result_arrow?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 2 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_flat_error:ensures/2», Elixir.MonEx.Arrows.«~>>/2»,
          Elixir.MonEx.«flat_map/2», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_flat_some(value, f),
      requires: option_arrow?(f),
      expects: some(value) ~>> f == MonEx.flat_map(some(value), f),
      proof: ~LEAN"""
      have allowed : f = .function 4 1 #[] ∨ f = .function 5 1 #[] := by
        simp [«arrow_flat_some:requires/2», «option_arrow?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 4 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_flat_some:ensures/2», Elixir.MonEx.Arrows.«~>>/2»,
          Elixir.MonEx.«flat_map/2», «stay_some/1», «stay_none/1»,
          Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )

    law(arrow_flat_none(f),
      requires: option_arrow?(f),
      expects: none() ~>> f == MonEx.flat_map(none(), f),
      proof: ~LEAN"""
      have allowed : f = .function 4 1 #[] ∨ f = .function 5 1 #[] := by
        simp [«arrow_flat_none:requires/1», «option_arrow?/1», Erlang.lists.«member/2»] at requires
        by_cases h : f = .function 4 1 #[]
        · exact Or.inl h
        · exact Or.inr (requires h)
      rcases allowed with rfl | rfl <;>
        simp [Lynx.apply_eq, «arrow_flat_none:ensures/1», Elixir.MonEx.Arrows.«~>>/2»,
          Elixir.MonEx.«flat_map/2», Erlang.erlang.«is_function/2», Erlang.erlang.«==/2»]
      """
    )
  end
end
