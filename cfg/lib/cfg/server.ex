defmodule InfinityAPS.Configuration.Server do
  use GenServer
  require Logger
  alias InfinityAPS.Configuration.ConfigurationData

  def start_link(file) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, Path.expand(file), name: __MODULE__)
  end

  def init(file) do
    :ok = File.mkdir_p(Path.dirname(file))
    :ok = File.touch(file)
    read_config(file)
  end

  def get_config() do
    GenServer.call __MODULE__, {:get_config}
  end

  def get_config(key) do
    GenServer.call __MODULE__, {:get_config, key}
  end

  def set_config(config = %ConfigurationData{}) do
    GenServer.call __MODULE__, {:set_config, config}
  end

  def set_config(key, value) do
    GenServer.call __MODULE__, {:set_config, key, value}
  end

  def save_config() do
    GenServer.call __MODULE__, {:save_config}
  end

  def handle_call({:get_config}, _from, state = {_file, config_map}) do
    {:reply, config_map, state}
  end

  def handle_call({:get_config, key}, _from, state = {_file, config_map}) do
    {:reply, Map.get(config_map, key), state}
  end

  def handle_call({:set_config, new_config = %ConfigurationData{}}, _from, {file, _old_config}) do
    {:reply, :ok, {file, new_config}}
  end

  def handle_call({:set_config, key, value}, _from, {file, config_map}) do
    {:reply, :ok, {file, Map.put(config_map, key, value)}}
  end

  def handle_call({:save_config}, _from, state) do
    {:reply, write_config(state), state}
  end

  defp read_config(file) do
    with {:ok, config_data} <- File.read(file),
         {:ok, config_map} <- decode_config(config_data) do
      {:ok, {file, config_map}}
    else
      error -> {:error, "Unable to read configuration data: #{error}"}
    end
  end

  defp decode_config(<<>>), do: {:ok, %ConfigurationData{}}
  defp decode_config(config_data) when is_binary(config_data), do: Poison.decode(config_data, as: %ConfigurationData{})

  defp write_config({file, config_map}) do
    with {:ok, config_data} <- Poison.encode(config_map),
         :ok <- File.write(file, config_data) do

      # Temporary way to apply configuration
      Logger.info("Configuration saved, rebooting")
      Nerves.Runtime.reboot()
      :ok
    else
      error -> {:error, "Unable to write configuration data: #{error}"}
    end
  end
end
