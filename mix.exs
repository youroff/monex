defmodule Monex.Mixfile do
  use Mix.Project

  @version "0.2.1"
  @source_url "https://github.com/youroff/monex"

  def project do
    [app: :monex,
     version: @version,
     elixir: "~> 1.18",
     name: "MonEx",
     source_url: @source_url,
     description: description(),
     package: package(),
     deps: deps(),
     docs: docs()]
  end

  def application, do: []

  defp deps do
    [
      {:ecto, "~> 3.10", optional: true},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:lynx,
       git: "https://github.com/josevalim/lynx.git",
       ref: "e3d8c68281058d21a31aa5ac8e6a7e0b83db4aeb",
       only: :test}
    ]
  end

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
