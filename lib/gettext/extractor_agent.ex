defmodule Gettext.ExtractorAgent do
  @doc false

  @initial_state %{}

  def start_link do
    Agent.start_link(fn -> @initial_state end, name: __MODULE__)
  end

  def add_translation(backend, domain, translation) do
    Agent.cast __MODULE__, fn(state) ->
      state = Map.put_new(state, backend, %{})

      update_in state, [backend], fn(domains) ->
        Map.update domains, domain, [translation], fn(translations) ->
          add_translation_with_merge(translations, translation)
        end
      end
    end
  end

  def get_all do
    Agent.get __MODULE__, &(&1)
  end

  defp add_translation_with_merge(translations, translation) do
    existing = Enum.find(translations, &Gettext.PO.Translations.same?(&1, translation))

    if existing do
      [merge_same_translations(existing, translation)|List.delete(translations, existing)]
    else
      [translation|translations]
    end
  end

  defp merge_same_translations(t1, t2) do
    update_in t1.references, &(&1 ++ t2.references)
  end
end
