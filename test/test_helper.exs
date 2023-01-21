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
  def init(context), do: context

  @impl Gettext.Plural
  def nplurals(context) do
    send(self(), {:nplurals_context, context})

    2
  end

  @impl Gettext.Plural
  def plural(context, _count) do
    send(self(), {:plural_context, context})

    0
  end
end

ExUnit.start()
