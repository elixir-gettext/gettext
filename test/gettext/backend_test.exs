defmodule Gettext.BackendTest do
  use ExUnit.Case, async: true

  describe "use Gettext.Backend" do
    test "creates a backend" do
      body =
        quote do
          use Gettext.Backend,
            otp_app: :test_application
        end

      {:module, mod, _bytecode, :ok} = Module.create(TestBackend, body, __ENV__)

      assert mod.__gettext__(:otp_app) == :test_application
      assert mod.__info__(:attributes)[:behaviour] == [Gettext.Backend]
    end
  end
end
