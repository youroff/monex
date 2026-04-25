defmodule Monex.Mixfile do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/youroff/monex"

  def project do
    [app: :monex,
     version: @version,
     elixir: "~> 1.15",
     name: "MonEx",
     source_url: @source_url,
     description: description(),
     package: package(),
     deps: deps(),
     docs: docs()]
  end

  def application, do: []

  defp deps, do: [
    {:ecto, "~> 3.10", optional: true},
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
    {:ex_doc, "~> 0.34", only: :dev, runtime: false}
  ]

  defp description do
    """
    Monadic types collection. Option (Maybe) - some(val)/none(). Result - ok(val)/error(err).
    """
  end

  defp package, do: [
   files: ["lib", "mix.exs", "README*", "LICENSE*"],
   maintainers: ["Ivan Yurov"],
   licenses: ["MIT"],
   links: %{"GitHub" => @source_url}
  ]

  defp docs, do: [
    main: "MonEx",
    source_ref: "v#{@version}",
    extras: ["README.md"]
  ]
end
