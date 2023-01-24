defmodule Phx.Live.HeadTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView, only: [push_event: 3]
  alias Phoenix.LiveView.Socket
  import Phx.Live.Head

  test "Query minimizing" do
    result =
      %Socket{}
      |> push("link[rel*='icon']", :set, "href", "favicon/test.png")
      |> push("link[other]", :set, "href", "favicon/test.png")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [["hd", %{c: [["link[other]", [[_, "h", _]]], ["f", [[_, "h", _]]]]}]] = result
  end

  test "Action minimizing" do
    result =
      %Socket{}
      |> push("link[other]", :dynamic, "href", "build-error")
      |> push("link[other]", :set, "class", "class-of-99")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [["hd", %{c: [["link[other]", [[:s, "c", "class-of-99"], [:d, "h", "build-error"]]]]}]] =
             result
  end

  test "Attribute minimizing" do
    result =
      %Socket{}
      |> push("link[other]", :set, "href", "favicon/test.png")
      |> push("link[other]", :set, "class", "class-of-99")
      |> push("link[other]", :set, "id", "#privacy")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 c: [
                   [
                     "link[other]",
                     [
                       [:s, "id", "#privacy"],
                       [:s, "c", "class-of-99"],
                       [:s, "h", "favicon/test.png"]
                     ]
                   ]
                 ]
               }
             ]
           ] = result
  end

  test "Events are merged" do
    result =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", "class-of-99")
      |> push("a", :set, "id", "#privacy")
      |> push("p", :set, "class", "paragraph")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 c: [
                   ["p", [[:s, "c", "paragraph"]]],
                   [
                     "a",
                     [
                       [:s, "id", "#privacy"],
                       [:s, "c", "class-of-99"],
                       [:s, "h", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"]
                     ]
                   ]
                 ]
               }
             ]
           ] = result
  end

  test "Other events are left untouched" do
    result =
      %Socket{}
      |> push_event("other", %{foo: :bar})
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", "class-of-99")
      |> push("p", :set, "class", "paragraph")
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
      |> push("a", :set, "class", "class-of-99")
      |> push("a", :set, "id", "#privacy")
      |> push("p", :set, "class", "paragraph")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 c: [
                   ["p", [[:s, "c", "paragraph"]]],
                   [
                     "a",
                     [
                       [:s, "id", "#privacy"],
                       [:s, "c", "class-of-99"],
                       [:s, "h", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"],
                       ["i", "*", "i"]
                     ]
                   ]
                 ]
               }
             ]
           ] = result
  end

  test "There are no duplicate sets for an attribute" do
    result =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", "class-of-99")
      |> push("a", :set, "href", "http:///www.updated.url/watch?none")
      |> Phoenix.LiveView.Utils.get_push_events()

    assert [
             [
               "hd",
               %{
                 c: [
                   [
                     "a",
                     [[:s, "h", "http:///www.updated.url/watch?none"], [:s, "c", "class-of-99"]]
                   ]
                 ]
               }
             ]
           ] = result
  end

  test "Reset/1 removes previous consecutive actions for a query" do
    socket =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", "class-of-99")
      |> push("a", :set, "id", "#privacy")
      |> reset("a")
      |> push("p", :set, "class", "paragraph")
      |> push_event("other", %{foo: :bar})

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["hd", %{c: [["p", [[:s, "c", "paragraph"]]], ["a", [["i", "*", "i"]]]]}],
             ["other", %{foo: :bar}]
           ] = result

    # after reset, new values can be set
    socket =
      socket
      |> push("a", :set, "href", "http:///www.updated.url/watch?none")
      |> push("a", :set, "class", "class-of-99")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             [
               "hd",
               %{
                 c: [
                   [
                     "a",
                     [[:s, "c", "class-of-99"], [:s, "h", "http:///www.updated.url/watch?none"]]
                   ],
                   ["p", [[:s, "c", "paragraph"]]],
                   ["a", [["i", "*", "i"]]]
                 ]
               }
             ],
             ["other", %{foo: :bar}]
           ] = result

    # non-consecutive actions are not removed
    socket =
      socket
      |> push("p", :set, "class", "paragraph2")
      |> push_event("other", %{foo: :baz})
      |> reset("a")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :baz}],
             [
               "hd",
               %{
                 c: [
                   ["a", [["i", "*", "i"]]],
                   ["p", [[:s, "c", "paragraph2"]]],
                   [
                     "a",
                     [[:s, "c", "class-of-99"], [:s, "h", "http:///www.updated.url/watch?none"]]
                   ],
                   ["p", [[:s, "c", "paragraph"]]],
                   ["a", [["i", "*", "i"]]]
                 ]
               }
             ],
             ["other", %{foo: :bar}]
           ] = result
  end

  test "Reset/2 removes pre-existing actions for the query + attribute" do
    socket =
      %Socket{}
      |> push("a", :set, "href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      |> push("a", :set, "class", "class-of-99")
      |> push_event("other", %{foo: :bar})
      |> reset("a", "href")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :bar}],
             ["hd", %{c: [["a", [[:i, "h", "i"], [:s, "c", "class-of-99"]]]]}]
           ] = result

    # href reset is overriden by set
    socket =
      socket
      |> push("a", :set, "href", "http:///www.updated.url/watch?none")
      |> push("a", :set, "class", "class-of-67")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             ["other", %{foo: :bar}],
             [
               "hd",
               %{
                 c: [
                   [
                     "a",
                     [[:s, "c", "class-of-67"], [:s, "h", "http:///www.updated.url/watch?none"]]
                   ]
                 ]
               }
             ]
           ] = result
  end

  test "Remove does not need a value" do
    socket =
      %Socket{}
      |> push("a", :remove, "href")

    result = Phoenix.LiveView.Utils.get_push_events(socket)
    assert [["hd", %{c: [["a", [[:x, "h", nil]]]]}]] == result
  end

  test "Snap seperates merging" do
    socket =
      %Socket{}
      |> push("a", :set, "href", "http://some.url/")
      |> push("a", :set, "class-name", "my-class")
      |> snap("a", "snap_name")
      |> push("a", :set, "href", "http://other.url/")
      |> push("a", :set, "href", "http://last.url/")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [
             [
               "hd",
               %{
                 c: [
                   [
                     "a",
                     [
                       [:s, "h", "http://last.url/"],
                       ["b", "*", "snap_name"],
                       [:s, "c", "my-class"],
                       [:s, "h", "http://some.url/"]
                     ]
                   ]
                 ]
               }
             ]
           ] == result
  end

  test "Restore truncates" do
    socket =
      %Socket{}
      |> push("a", :set, "href", "http://some.url/")
      |> push("a", :toggle, "class-name", "checked")
      |> push("a", :add, "class-name", "my-class")
      |> restore("a", "snap_name")
      |> push("a", :set, "href", "http://other.url/")
      |> push("a", :set, "href", "http://last.url/")

    result = Phoenix.LiveView.Utils.get_push_events(socket)

    assert [["hd", %{c: [["a", [[:s, "h", "http://last.url/"], ["r", "*", "snap_name"]]]]}]] ==
             result
  end

  test "Unknown attributes are allowed" do
    socket =
      %Socket{}
      |> push("a", :set, :unknown, "value")

    result = Phoenix.LiveView.Utils.get_push_events(socket)
    [["hd", %{c: [["a", [[:s, "unknown", "value"]]]]}]] = result
  end
end
