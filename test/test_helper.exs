# Loads the test application located in test/fixtures/test_application.
[__DIR__, "fixtures", "test_application", "ebin"]
|> Path.join()
|> Code.prepend_path()

ExUnit.start()
