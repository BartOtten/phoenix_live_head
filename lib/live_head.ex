defmodule Phx.Live.Head do
  @moduledoc """
  Provides commands for manipulating the HTML Head of Phoenix Live View applications
  while minimizing data over the wire.

  The available command actions support a variety of utility operations useful for
  HTML Head manipulation. Such as setting or removing tag attributes and
  adding or removing CSS classes for vector (SVG) favicons.

  > #### Note {: .info}
  > This lib is not meant to be used directly. Have a look at `Phx.Live.Favicon`
  > and `Phx.Live.Metadata`. Those libs provide a cleaner syntax and specific
  > documentation for their intended usage.

  ## Query
  The query is used by the the Javascript client to select HTML elements
  using `document.querySelectorAll(query)`.

  ## Actions
  The actions are applied to an attribute in all selected HTML elements.

  Supported actions on the "class" attribute:

    * `set` - Set class name(s)
    * `add` - Add to list of class names
    * `remove` - Remove from list of class names
    * `toggle` - Toggle class name
    * `initial` - Reset attribute to it's intial value

  Supported actions on other attributes:

    * `set` - Set value of attribute
    * `initial` - Reset attribute to it's intial value
    * `dynamic` - Set the value of a `{dynamic}` attribute

  ## Dynamic attributes

  To define a dynamic attribute, the element in the template must have a `data-dynamic-[attr]`
  attribute with a value containing the placeholder notation `{dynamic}`.

  **Example**
  ```html
  <link rel='icon' href="default_fav.png" data-dynamic-href="favs/{dynamic}/fav-16x16.png">
  ```

  When an event is pushed with `target = "link[rel*=icon]"`, `action = :dynamic` and
  `value = "new_message"` the result wil look like:

  ```html
  <link rel='icon' href="favs/new_message/fav-16x16.png">
  ```
  """

  import Phoenix.LiveView, only: [push_event: 3]
  alias Phoenix.LiveView.Socket

  @initial "i"

  @type action :: :add | :dynamic | :initial | :remove | :set | :toggle
  @type query :: String.t()
  @type attr :: String.t()
  @type value :: String.t()
  @typep reset :: String.t()
  @typep change :: [...] | reset
  @typep details :: map()

  @doc """
  Reset all `attributes` of elements matching `query` to their initial value.
  """
  @spec reset(Socket.t(), query) :: Socket.t()
  def reset(socket, query) do
    query = maybe_min_query(query)
    put_or_merge_head_events(socket, query, @initial)
  end

  @doc """
  Reset an `attribute` of elements matching `query` to it's initial value
  """
  @spec reset(Socket.t(), query, attr) :: Socket.t()
  def reset(socket, query, attr), do: push(socket, query, :initial, attr, @initial)

  @doc """
  Pushes `action` to apply on `attribute` of elements matching `query`. See [Actions](#module-actions) for available actions.
  """
  @spec push(Socket.t(), query, action, attr, value) :: Socket.t()
  def push(socket, query, action, attr, value) do
    query = maybe_min_query(query)
    action = min_action(action)
    attr = maybe_min_attr(attr)

    socket |> put_or_merge_head_events(query, [action, attr, value])
  end

  @spec maybe_min_attr(attr) :: binary
  defp maybe_min_attr("class"), do: "c"
  defp maybe_min_attr("class-name"), do: "c"
  defp maybe_min_attr("href"), do: "h"
  defp maybe_min_attr(other) when is_binary(other), do: other
  defp maybe_min_attr(other) when is_atom(other), do: to_string(other) |> maybe_min_attr()

  @spec maybe_min_query(query) :: binary
  defp maybe_min_query("link[rel*='icon']"), do: "f"
  defp maybe_min_query(other) when is_binary(other), do: other

  @spec min_action(action) :: :a | :d | :i | :r | :s | :t
  defp min_action(:dynamic), do: :d
  defp min_action(:set), do: :s
  defp min_action(:remove), do: :r
  defp min_action(:add), do: :a
  defp min_action(:toggle), do: :t
  defp min_action(:initial), do: :i

  @spec reject_previous_attr_changes(previous_changes :: [change], attr) :: [change]
  defp reject_previous_attr_changes(previous_changes, attr) do
    Enum.reject(previous_changes, fn
      [_, attr2, _] -> attr2 == attr
      @initial -> false
    end)
  end

  @spec put_query_change(details, query, change) :: [change]
  defp put_query_change(details, query, change) do
    ["hd", Map.put(details, query, [change])]
  end

  @spec merge_query_change(details, query, change) :: [change]
  defp merge_query_change(details, query, change) do
    [_action, attr, _value] = change

    previous_changes =
      details[query]
      |> reject_previous_attr_changes(attr)

    combined_changes = previous_changes ++ [change]
    ["hd", Map.put(details, query, combined_changes)]
  end

  @spec put_or_merge_head_events(Socket.t(), query, change) :: Socket.t()
  defp put_or_merge_head_events(%Socket{} = socket, query, change)
       when is_binary(query) and (is_list(change) or change === @initial) do
    # use an accumulator to signal if head events were merged so
    # the list only has to be traversed once.
    {events, merged?} =
      socket
      |> Phoenix.LiveView.Utils.get_push_events()
      |> Enum.map_reduce(false, fn
        ["hd", details], _ when change == @initial or not is_map_key(details, query) ->
          {put_query_change(details, query, change), true}

        ["hd", details], _ when is_map_key(details, query) ->
          {merge_query_change(details, query, change), true}

        other, acc ->
          {other, acc}
      end)

    #  we either simply push a new event to the stack when their were no merged
    #  head events or we replace the whole list of events with our mapped variant
    #  including merged head events
    if merged? do
      put_in(socket.private.__changed__.push_events, events)
    else
      push_event(socket, "hd", Map.put(%{}, query, [change]))
    end
  end
end
