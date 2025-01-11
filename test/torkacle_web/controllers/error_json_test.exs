defmodule TorkacleWeb.ErrorJSONTest do
  use TorkacleWeb.ConnCase, async: true

  test "renders 404" do
    assert TorkacleWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert TorkacleWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
