defmodule SimpleStencilTest do
  use ExUnit.Case
  doctest SimpleStencil

  test "greets the world" do
    assert SimpleStencil.hello() == :world
  end
end
