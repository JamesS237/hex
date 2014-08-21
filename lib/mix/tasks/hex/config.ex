defmodule Mix.Tasks.Hex.Config do
  use Mix.Task

  @shortdoc "Read or update hex config"

  @moduledoc """
  Reads or updates hex configuration file.

  `mix hex.config KEY [VALUE]`
  """

  def run(args) do
    Hex.Util.ensure_registry(fetch: false)

    case args do
      [key] ->
        case Keyword.fetch(Hex.Util.read_config, :"#{key}") do
          {:ok, value} -> Mix.shell.info(inspect(value, pretty: true))
          :error       -> Mix.raise "Config does not contain a key #{key}"
        end
      [key, value] ->
        Hex.Util.update_config([{:"#{key}", value}])
      _ ->
        Mix.raise "Invalid arguments, expected: mix hex.config KEY [VALUE]"
    end
  end
end
