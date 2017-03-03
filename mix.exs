defmodule Monex.Mixfile do
  use Mix.Project

  def project do
    [app: :monex,
     version: "0.1.4",
     elixir: "~> 1.4",
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application, do: []
  defp deps, do: [
    {:dialyxir, "~> 0.4", only: [:dev], runtime: false},
    {:ex_doc, "~> 0.14", only: :dev}
  ]

  defp description do
    """
    Monadic types collection
    Currently implemented:
    * Option
    * Result
    """
  end
  
  defp package, do: [
   files: ["lib", "mix.exs", "README*", "LICENSE*"],
   maintainers: ["Ivan Yurov"],
   licenses: ["Apache 2.0"],
   links: %{"GitHub" => "https://github.com/youroff/monex"}
  ]
end
