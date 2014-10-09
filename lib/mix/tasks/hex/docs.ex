defmodule Mix.Tasks.Hex.Docs do
  use Mix.Task
  alias Mix.Tasks.Hex.Util

  @shortdoc "Publish docs for package"

  @moduledoc """
  Publishes documentation for the current project and version.

  The documentation will be accessible at `http://hexdocs.pm/my_package/1.0.0`,
  `http://hexdocs.pm/my_package` will always redirect to the latest published
  version.

  Documentation will be generated by running the `mix docs` task. `ex_doc`
  provides this task by default, but any library can be used. Or an alias can be
  used to extend the documentation generation. The expected result of the task
  is the generated documentation located in the `docs/` directory with an
  `index.html` file.

  ## Command line options

    * `--revert VERSION` - Revert given version
  """

  @switches [revert: :string, progress: :boolean]

  def run(args) do
    Hex.start

    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    auth = Util.auth_info()

    Mix.Project.get!
    config  = Mix.Project.config
    app     = config[:app]
    version = config[:version]

    if revert = opts[:revert] do
      revert(app, revert, auth)
    else
      Mix.Task.run("docs", args)

      unless File.exists?("docs/index.html") do
        Mix.raise "File not found: docs/index.html"
      end

      progress? = Keyword.get(opts, :progress, true)
      tarball = build_tarball(app, version)
      send_tarball(app, version, tarball, auth, progress?)
    end
  end

  defp build_tarball(app, version) do
    tarball = "#{app}-#{version}-docs.tar.gz"
    files = files()
    :ok = :erl_tar.create(tarball, files, [:compressed])
    data = File.read!(tarball)

    File.rm!(tarball)
    data
  end

  defp send_tarball(app, version, tarball, auth, progress?) do
    if progress? do
      progress = Util.progress(byte_size(tarball))
    else
      progress = Util.progress(nil)
    end

    case Hex.API.Release.new_docs(app, version, tarball, auth, progress) do
      {code, _} when code in [200, 201] ->
        Mix.shell.info("")
        Mix.shell.info("Published docs for #{app} v#{version}")
        Mix.shell.info("Hosted at #{Hex.Util.hexdocs_url(app, version)}")
      {code, body} ->
        Mix.shell.error("Pushing docs for #{app} v#{version} failed (#{code})")
        Hex.Util.print_error_result(code, body)
    end
  end

  defp revert(app, version, auth) do
    version = Util.clean_version(version)

    case Hex.API.Release.delete_docs(app, version, auth) do
      {204, _} ->
        Mix.shell.info("Reverted docs for #{app} v#{version}")
      {code, body} ->
        Mix.shell.error("Reverting docs for #{app} v#{version} failed! (#{code})")
        Hex.Util.print_error_result(code, body)
    end
  end

  defp files do
    "docs/**"
    |> Path.wildcard
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&{relative_path(&1, "docs"), File.read!(&1)})
  end

  defp relative_path(file, dir) do
    Path.relative_to(file, dir)
    |> String.to_char_list
  end
end
