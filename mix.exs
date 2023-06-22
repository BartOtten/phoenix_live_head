defmodule Phx.Live.Head.MixProject do
  use Mix.Project

  def project do
    [
      name: "Phoenix Live Head",
      description: "HTML Head manipulation for Phoenix Live Views",
      app: :phoenix_live_head,
      version: "0.2.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      package: package(),
      aliases: aliases(),
      docs: docs(),
      deps: deps(),
      source_url: "https://github.com/BartOtten/phoenix_live_head",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, ">= 1.6.0"},
      {:phoenix_html, ">= 3.1.0"},
      {:phoenix_live_view, ">= 0.17.0"},
      {:esbuild, ">= 0.2.0", only: :dev},
      {:ex_doc, ">= 0.27.0", optional: true},
      {:jason, ">= 1.0.0", optional: true},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14", only: :test}
    ]
  end

  defp aliases do
    [
      "assets.build": [
        "esbuild module --log-level=debug",
        "esbuild cdn",
        "esbuild cdn_min",
        "esbuild main"
      ],
      "assets.watch": ["esbuild module --watch"]
    ]
  end

  defp package do
    [
      maintainers: ["Bart Otten"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/phoenix_live_head/changelog.html",
        GitHub: "https://github.com/BartOtten/phoenix_live_head"
      },
      files:
        ~w(assets/js lib priv) ++
          ~w(CHANGELOG.md LICENSE.md mix.exs package.json README.md CONTRIBUTING.md)
    ]
  end

  defp docs do
    [
      api_reference: false,
      authors: ["Bart Otten"],
      main: "Phx.Live.Head",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md": [filename: "contributing", title: "Contributing"],
        "LICENSE.md": [filename: "license", title: "License"]
      ]
    ]
  end
end
