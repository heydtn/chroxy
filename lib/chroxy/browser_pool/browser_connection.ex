defmodule Chroxy.BrowserPool.BrowserConnection do
  use GenServer, restart: :temporary

  require Logger

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(arg) do
    Process.flag(:trap_exit, true)

    {:ok, arg}
  end

  def handle_call({:connection, :chrome}, _from, state) do
    connection = Chroxy.BrowserPool.Chrome.get_connection()
    {:reply, connection, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info("BrowserPool link #{inspect(pid)} exited: #{inspect(reason)}")
    {:stop, reason, state}
  end
end
