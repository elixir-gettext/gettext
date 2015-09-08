defmodule Gettext.ExtractorAgent do
  @moduledoc false

  @initial_state %{}

  def start_link do
    Agent.start_link(fn -> @initial_state end, name: __MODULE__)
  end

  def add_translation(backend, domain, translation) do
    key = Gettext.PO.Translations.key(translation)

    Agent.cast __MODULE__, fn(state) ->
      # Initialize the given backend to an empty map if it wasn't there.
      state = Map.put_new(state, backend, %{})

      update_in state, [backend, domain], fn(translations) ->
        if is_nil(translations) do
          translations = %{}
        end

        Map.update(translations, key, translation, &merge_translations(&1, translation))
      end
    end
  end

  def get_all do
    Agent.get __MODULE__, &(&1)
  end

  defp merge_translations(t1, t2) do
    update_in t1.references, &(&1 ++ t2.references)
  end
end
