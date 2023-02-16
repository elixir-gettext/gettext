defmodule GettextTest.CustomPlural do
  @behaviour Gettext.Plural
  def nplurals("elv"), do: 2
  def nplurals(other), do: Gettext.Plural.nplurals(other)
  # Opposite of Italian (where 1 is singular, everything else is plural)
  def plural("it", 1), do: 1
  def plural("it", _), do: 0
end

defmodule GettextTest.CustomCompiledPlural do
  @behaviour Gettext.Plural

  @impl Gettext.Plural
  def init(plural_info), do: plural_info

  @impl Gettext.Plural
  def nplurals(plural_info) do
    send(self(), {:nplurals_context, plural_info})

    plural_info
    |> Gettext.Plural.init()
    |> Gettext.Plural.nplurals()
  end

  @impl Gettext.Plural
  def plural(plural_info, count) do
    send(self(), {:plural_context, plural_info})

    plural_info
    |> Gettext.Plural.init()
    |> Gettext.Plural.plural(count)
  end
end

ExUnit.start()
