defmodule Chroxy.BrowserPool do
  @moduledoc """
  Provides connections to Browser instances, through the
  orchestration of proxied connections to processes managing
  the OS browser processes.

  Responisble for initialisation of the pool of browsers when
  the app starts.
  """
  use GenServer

  require Logger

  defguardp is_supported(browser) when browser in [:chrome]

  def child_spec() do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      restart: :transient,
      shutdown: 5000,
      type: :worker
    }
  end

  @doc """
  Spawns #{__MODULE__} process and the browser processes.
  For each port in the range provided, an instance of chrome will
  be initialised.
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  ##
  # API

  @doc """
  Request new page websocket url.
  """
  def connection(browser) when is_supported(browser) do
    GenServer.call(__MODULE__, {:connection, browser}, 60_000)
  end

  ##
  # Callbacks

  @doc false
  def init(args) do
    Logger.warn("ARGS: #{inspect(args)}")
    Process.flag(:trap_exit, true)
    {:ok, chrome_pool} = Chroxy.BrowserPool.Chrome.start_link()
    {:ok, %{chrome_pool: chrome_pool}}
  end

  @doc false
  def handle_call({:connection, :chrome}, _from, state) do
    connection = Chroxy.BrowserPool.Chrome.get_connection()
    {:reply, connection, state}
  end

  @doc false
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.info("BrowserPool link #{inspect(pid)} exited: #{inspect(reason)}")
    {:noreply, state}
  end
end
