defmodule Chroxy.BrowserPool.Chrome do
  use GenServer
  require Logger

  # API

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_browser(port) do
    {:ok, chrome} = Chroxy.ChromeServer.Supervisor.start_child(chrome_port: port)

    # Wait for chrome to init and enter a ready state for connections...
    case Chroxy.ChromeServer.ready(chrome) do
      :ready ->
        # when ready close the pages which are opened by default
        :ok = Chroxy.ChromeServer.close_all_pages(chrome)

      :timeout ->
        # failed to become ready in an acceptable timeframe
        Logger.error("Failed to start chrome on port #{port}")
    end

    :ok
  end

  @doc """
  Sequentially loop through processes on each call.
  Ordered access is not gauranteed as processes may crash and be restarted.
  """
  def get_browser(:next) do
    GenServer.call(__MODULE__, {:get_browser, :next})
  end

  @doc """
  Select a random browser from the pool.
  """
  def get_browser(:random) do
    pool()
    |> Enum.take_random(1)
    |> List.first()
  end

  def get_connection() do
    :next
    |> get_browser()
    |> get_connection()
  end

  def get_connection(chrome) do
    {:ok, pid} = Chroxy.ChromeProxy.start_link(chrome: chrome)
    Chroxy.ChromeProxy.chrome_connection(pid)
  end

  # Callbacks

  def init([]) do
    opts = Application.get_all_env(:chroxy)

    chrome_port_from =
      Keyword.get(opts, :chrome_remote_debug_port_from)
      |> String.to_integer()

    chrome_port_to =
      Keyword.get(opts, :chrome_remote_debug_port_to)
      |> String.to_integer()

    ports = Range.new(chrome_port_from, chrome_port_to)

    Task.async_stream(ports, &start_browser(&1))
    |> Stream.run()

    {:ok, %{browsers: [], access_count: 0}}
  end

  @doc false
  def handle_call({:get_browser, :next}, _from, state = %{access_count: access_count}) do
    browsers = pool()
    idx = Integer.mod(access_count, Enum.count(browsers))
    {:reply, Enum.at(browsers, idx), %{state | access_count: access_count + 1}}
  end

  @doc """
  List active worker processes in pool.
  """
  def pool() do
    Chroxy.ChromeServer.Supervisor.which_children()
    |> Enum.filter(fn
      {_, p, :worker, _} when is_pid(p) ->
        Chroxy.ChromeServer.ready(p) == :ready

      _ ->
        false
    end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.sort()
  end
end
