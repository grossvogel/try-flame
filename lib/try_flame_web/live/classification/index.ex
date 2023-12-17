defmodule TryFlameWeb.ClassificationLive.Index do
  use TryFlameWeb, :live_view

  @form_types %{text: :string}

  @impl true
  def mount(_params, _session, socket) do
    :ok = Phoenix.PubSub.subscribe(TryFlame.PubSub, "activity_log")

    socket =
      socket
      |> assign(:page_title, "Testing FLAME")
      |> assign(:generating_for, nil)
      |> assign_form(changeset())
      |> stream(:activity_log, [])
      |> assign(:generated_any?, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"input" => params}, socket) do
    {:noreply, assign_form(socket, changeset(params))}
  end

  def handle_event("submit", %{"input" => %{"text" => text}}, socket) when text != "" do
    Task.Supervisor.async(TryFlame.TaskSupervisor, fn ->
      TryFlame.Classification.emojify_async(text, DateTime.utc_now())
    end)

    {:noreply, assign(socket, :generating_for, text)}
  end

  # no text supplied, ignore
  def handle_event("submit", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_emoji, payload}, socket) do
    mine? = payload.text == socket.assigns.generating_for

    socket =
      if mine? do
        socket
        |> assign(:generating_for, nil)
        |> assign(:generated_any?, true)
        |> assign_form(changeset())
      else
        socket
      end

    {:noreply, stream_insert(socket, :activity_log, Map.put(payload, :mine?, mine?))}
  end

  # ignore unexpected messages (e.g. child process shutdown)
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp format_source(source) do
    [_name, host] = String.split("#{source}", "@")
    host
  end

  defp changeset(params \\ %{}) do
    Ecto.Changeset.cast({%{}, @form_types}, params, Map.keys(@form_types))
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :input))
  end
end
