defmodule Phx.Live.HeadTest do
  use ExUnit.Case

  import Phoenix.LiveView, only: [push_event: 3]
  alias Phoenix.LiveView.Socket
  import Phx.Live.Head

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

    assert [["hd", %{"link[other]" => [[:d, _, _], [:s, _, _]]}]] = result
  end

  test "Attribute minimizing" do
    result =
      %Socket{}
      |> push("link[other]", :set, "href", "favicon/test.png")
      |> push("link[other]", :set, "class", ".class-of-99")
      |> push("link[other]", :set, "id", "#privacy")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [["hd", %{"link[other]" => [[_, "h", _], [_, "c", _], [_, "id", _]]}]] = result
  end

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
                 "a" => [[_, _, _] = _event1, [_, _, _] = _event2, [_, _, _] = _event3],
                 "p" => [[_, _, _]]
               }
             ]
           ] = result
  end

  test "Other events are left untouched" do
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
             _head_events,
             ["p", %{bar: :baz}]
           ] = result
  end

  test "Actions per element preserve order" do
    result =
      %Socket{}
      |> reset("a")
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", ".class-of-99")
      |> push("a", :set, "id", "#privacy")
      |> push("p", :set, "class", ".paragraph")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 "a" => [
                   "i",
                   [_, "h", _] = _event1,
                   [_, "c", _] = _event2,
                   [_, "id", _] = _event3
                 ],
                 "p" => [[_, "c", _]]
               }
             ]
           ] = result
  end

  test "There are no duplicate sets for an attribute" do
    result =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", ".class-of-99")
      |> push("a", :set, "href", "http:///www.updated.url/watch?none")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 "a" => [
                   [:s, "c", ".class-of-99"],
                   [:s, "h", "http:///www.updated.url/watch?none"]
                 ]
               }
             ]
           ] = result
  end

  test "Reset/1 removes pre-existing actions for the query" do
    socket =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", ".class-of-99")
      |> push("a", :set, "id", "#privacy")
      |> push("p", :set, "class", ".paragraph")
      |> push_event("other", %{foo: :bar})
      |> reset("a")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :bar}],
             [
               "hd",
               %{
                 "a" => ["i"],
                 "p" => [[:s, "c", ".paragraph"]]
               }
             ]
           ] = result

    socket =
      socket
      |> push("a", :set, "href", "http:///www.updated.url/watch?none")
      |> push("a", :set, "class", ".class-of-99")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :bar}],
             [
               "hd",
               %{
                 "a" => [
                   "i",
                   [:s, "h", "http:///www.updated.url/watch?none"],
                   [:s, "c", ".class-of-99"]
                 ],
                 "p" => [[:s, "c", ".paragraph"]]
               }
             ]
           ] = result
  end

  test "Reset/2 removes pre-existing actions for the query + attribute" do
    socket =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", ".class-of-99")
      |> push_event("other", %{foo: :bar})
      |> reset("a", "href")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :bar}],
             [
               "hd",
               %{
                 "a" => [
                   [:s, "c", ".class-of-99"],
                   [:i, "h", "i"]
                 ]
               }
             ]
           ] = result

    # href reset is overriden by set
    socket =
      socket
      |> push("a", :set, "href", "http:///www.updated.url/watch?none")
      |> push("a", :set, "class", ".class-of-67")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :bar}],
             [
               "hd",
               %{
                 "a" => [
                   [:s, "h", "http:///www.updated.url/watch?none"],
                   [:s, "c", ".class-of-67"]
                 ]
               }
             ]
           ] = result
  end
end
