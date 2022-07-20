defmodule GettextTest.CustomPlural do
  @behaviour Gettext.Plural
  def nplurals("elv"), do: 2
  def nplurals(other), do: Gettext.Plural.nplurals(other)
  # Opposite of Italian (where 1 is singular, everything else is plural)
  def plural("it", 1), do: 1
  def plural("it", _), do: 0
end

ExUnit.start()
