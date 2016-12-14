defmodule HedwigPlusplus.Mixfile do
  use Mix.Project

  def project do
    [app: :hedwig_plusplus,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :hedwig]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [      
      {:hedwig, "~> 1.0"},
      #{:hedwig_brain, git: "git@github.com:labzero/hedwig_brain.git", only: :test}     
      {:hedwig_brain, path: "../hedwig_brain", only: :test}
    ]
  end
end
