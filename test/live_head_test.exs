defmodule Phx.Live.HeadTest do
  use ExUnit.Case

  import Phoenix.LiveView, only: [push_event: 3]
  alias Phoenix.LiveView.Socket
  import Phx.Live.Head

  test "Events are merged" do
    result =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", ".class-of-99")
      |> push("a", :set, "id", "#privacy")
      |> push("p", :set, "class", ".paragraph")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 "a" => [[_, _, _] = _event3, [_, _, _] = _event2, [_, _, _] = _event1],
                 "p" => [[_, _, _]]
               }
             ]
           ] = result
  end

  test "Attribute minimizing" do
    result =
      %Socket{}
      |> push("link[other]", :set, "href", "favicon/test.png")
      |> push("link[other]", :set, "class", ".class-of-99")
      |> push("link[other]", :set, "id", "#privacy")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [["hd", %{"link[other]" => [[_, "id", _], [_, "c", _], [_, "h", _]]}]] = result
  end

  test "Query minimizing" do
    result =
      %Socket{}
      |> push("link[rel*='icon']", :set, "href", "favicon/test.png")
      |> push("link[other]", :set, "href", "favicon/test.png")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [["hd", %{"f" => [[_, _, _]], "link[other]" => [[_, _, _]]}]] = result
  end

  test "Action minimizing" do
    result =
      %Socket{}
      |> push("link[other]", :dynamic, "href", "build-error")
      |> push("link[other]", :set, "class", ".class-of-99")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [["hd", %{"link[other]" => [[:s, _, _], [:d, _, _]]}]] = result
  end

  test "Other events are not touched" do
    result =
      %Socket{}
      |> push_event("other", %{foo: :bar})
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", ".class-of-99")
      |> push("p", :set, "class", ".paragraph")
      |> push_event("p", %{bar: :baz})
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             ["other", %{foo: :bar}],
             _hed_events,
             ["p", %{bar: :baz}]
           ] = result
  end
end
