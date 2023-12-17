defmodule TryFlame.Classification do
  @moduledoc """
  This module contains the logic for classifying inputs
  """

  def load_serving do
    start_apps = [
      :inets,
      :ssl,
      :exla
    ]

    Application.load(:try_flame)
    Enum.each(start_apps, &Application.ensure_all_started/1)

    serving()
  end

  def serving() do
    {:ok, model_info} = Bumblebee.load_model({:hf, "cardiffnlp/twitter-roberta-base-emoji"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "roberta-base"})

    Bumblebee.Text.text_classification(model_info, tokenizer,
      top_k: 1,
      compile: [batch_size: 8, sequence_length: 100],
      defn_options: [compiler: EXLA]
    )
  end

  def emojify(text) do
    %{predictions: [%{label: emoji}]} =
      Nx.Serving.batched_run(TryFlame.ClassificationServing, text)

    emoji
  end

  def emojify_async(text, start_datetime) do
    FLAME.cast(TryFlame.ClassificationPool, fn ->
      startup_ms = DateTime.diff(DateTime.utc_now(), start_datetime, :millisecond)
      {inference_us, emoji} = :timer.tc(fn -> TryFlame.Classification.emojify(text) end)

      Phoenix.PubSub.broadcast(
        TryFlame.PubSub,
        "activity_log",
        {:new_emoji,
         %{
           text: text,
           emoji: emoji,
           source: Node.self(),
           startup_ms: startup_ms,
           inference_ms: div(inference_us, 1_000),
           id: Ecto.UUID.generate()
         }}
      )
    end)
  end
end
