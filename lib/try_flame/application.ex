defmodule TryFlame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    flame_parent = FLAME.Parent.get()
    flame_local? = Application.get_env(:flame, :backend) == FLAME.LocalBackend

    children =
      [
        TryFlameWeb.Telemetry,
        # don't need this
        # TryFlame.Repo,
        {DNSCluster, query: Application.get_env(:try_flame, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: TryFlame.PubSub},
        {Finch, name: TryFlame.Finch},
        {Task.Supervisor, name: TryFlame.TaskSupervisor},
        flame_pool(),
        (flame_local? || flame_parent) && inference_serving(),
        !flame_parent && TryFlameWeb.Endpoint
      ]
      |> Enum.filter(& &1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TryFlame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TryFlameWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp flame_pool do
    {FLAME.Pool,
     name: TryFlame.ClassificationPool,
     timeout: 90_000,
     boot_timeout: 90_000,
     min: 0,
     max: 2,
     max_concurrency: 10,
     idle_shutdown_after: 30_000}
  end

  defp inference_serving do
    {Nx.Serving,
     serving: TryFlame.Classification.serving(),
     name: TryFlame.ClassificationServing,
     batch_size: 8,
     batch_timeout: 100}
  end
end
