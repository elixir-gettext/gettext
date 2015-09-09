defmodule Gettext.ExtractorAgent do
  @moduledoc false

  @name __MODULE__

  # :translations is a map where keys are Gettext backends and values
  # are maps. In these maps, keys are domains and values are maps of
  # translation_id => translation.
  # :backends is just a list of backends that call `use Gettext`.
  @initial_state %{
    translations: %{},
    backends: [],
  }

  def start_link do
    Agent.start_link(fn -> @initial_state end, name: @name)
  end

  def alive? do
    !!Process.whereis(@name)
  end

  def add_translation(backend, domain, translation) do
    key = Gettext.PO.Translations.key(translation)

    Agent.cast @name, fn(state) ->
      # Initialize the given backend to an empty map if it wasn't there.
      state = update_in state.translations, &Map.put_new(&1, backend, %{})

      update_in state, [:translations, backend, domain], fn(translations) ->
        Map.update(translations || %{}, key, translation, &merge_translations(&1, translation))
      end
    end
  end

  def add_backend(backend) do
    Agent.cast @name, fn(state) ->
      update_in state.backends, &[backend|&1]
    end
  end

  def stop do
    Agent.stop @name
  end

  def get_translations do
    Agent.get @name, &(&1.translations)
  end

  def get_backends do
    Agent.get @name, &(&1.backends)
  end

  defp merge_translations(t1, t2) do
    update_in t1.references, &(&1 ++ t2.references)
  end
end
