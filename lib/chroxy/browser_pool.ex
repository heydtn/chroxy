defmodule Chroxy.BrowserPool do
  @moduledoc """
  Provides connections to Browser instances, through the
  orchestration of proxied connections to processes managing
  the OS browser processes.

  Responisble for initialisation of the pool of browsers when
  the app starts.
  """
  use DynamicSupervisor

  require Logger

  defguardp is_supported(browser) when browser in [:chrome]

  def child_spec() do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :transient,
      shutdown: 5000,
      type: :supervisor
    }
  end

  @doc """
  Spawns #{__MODULE__} process and the browser processes.
  For each port in the range provided, an instance of chrome will
  be initialised.
  """
  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  ##
  # API

  @doc """
  Request new page websocket url.
  """
  def connection(browser) when is_supported(browser) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        __MODULE__,
        {Chroxy.BrowserPool.BrowserConnection, :ok}
      )

    GenServer.call(pid, {:connection, browser}, 60_000)
  end

  ##
  # Callbacks

  @doc false
  def init(args) do
    Logger.warn("ARGS: #{inspect(args)}")
    Process.flag(:trap_exit, true)
    Chroxy.BrowserPool.Chrome.start_link()

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc false
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info("BrowserPool link #{inspect(pid)} exited: #{inspect(reason)}")
    {:noreply, state}
  end
end
