defmodule Wallaby.Driver.ProcessWorkspaceTest do
  use ExUnit.Case, async: true

  alias Wallaby.Driver.ProcessWorkspace
  alias Wallaby.Driver.TemporaryPath

  defmodule TestServer do
    use GenServer

    def start_link, do: GenServer.start_link(__MODULE__, [])
    def stop(pid), do: GenServer.stop(pid)

    @impl GenServer
    def init([]), do: {:ok, []}
  end

  describe "create/2" do
    test "creates a workspace dir which is deleted after the process ends" do
      {:ok, test_server} = TestServer.start_link()
      {:ok, workspace_path} = ProcessWorkspace.create(test_server)

      assert File.exists?(workspace_path)

      TestServer.stop(test_server)

      with_timeout(fn ->
        refute File.exists?(workspace_path)
      end)
    end

    test "when workspace already exists" do
      workspace_path = gen_tmp_path()
      File.mkdir(workspace_path)
      {:ok, test_server} = TestServer.start_link()
      {:ok, ^workspace_path} = ProcessWorkspace.create(test_server, workspace_path)

      assert File.exists?(workspace_path)

      TestServer.stop(test_server)

      with_timeout(fn ->
        refute File.exists?(workspace_path)
      end)
    end

    test "creates a workspace dir using tmp_dir_prefix setting" do
      {:ok, test_server} = TestServer.start_link()
      {:ok, workspace_path} = ProcessWorkspace.create(test_server)

      expected_path_prefix =
        Path.join(System.tmp_dir!(), Application.get_env(:wallaby, :tmp_dir_prefix, ""))

      assert workspace_path =~ ~r(^#{expected_path_prefix})
    end
  end

  defp gen_tmp_path do
    base_dir =
      Path.join(
        System.tmp_dir!(),
        Application.get_env(:wallaby, :tmp_dir_prefix, "")
      )

    TemporaryPath.generate(base_dir)
  end

  defp now_in_milliseconds(), do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)

  defp with_timeout(doer, timeout \\ 100),
    do: with_timeout(doer, now_in_milliseconds(), timeout)

  defp with_timeout(doer, start, timeout) do
    doer.()
  rescue
    e ->
      passed_timeout? = now_in_milliseconds() - start >= timeout

      if passed_timeout? do
        reraise e, __STACKTRACE__
      else
        with_timeout(doer, start, timeout)
      end
  end
end
