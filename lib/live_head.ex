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

  @type action :: :add | :dynamic | :initial | :remove | :set | :toggle
  @type query :: binary
  @type attr :: binary
  @type value :: binary
  @type changes :: [...]

  @doc """
  Reset all attributes of elements matching `query` to their initial value.
  """
  @spec reset(Socket.t(), query) :: Socket.t()
  def reset(socket, query),
    do: push_event(socket, "hd", Map.put(%{}, maybe_min_query(query), "i"))

  @doc """
  Pushes `action` to apply on `attr` of elements matching `query`. See [Actions](#module-actions) for available actions.
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

  @spec put_or_merge_head_events(Socket.t(), query, changes) :: Socket.t()
  defp put_or_merge_head_events(%Socket{} = socket, query, changes)
       when is_binary(query) and is_list(changes) do
    # use an accumulator to signal if head events are merged so
    # the list only has to be traversed once.
    {events, merged?} =
      socket
      |> Phoenix.LiveView.Utils.get_push_events()
      |> Enum.map_reduce(false, fn
        ["hd", details], _ when is_map_key(details, query) ->
          {["hd", Map.put(details, query, [changes | details[query]])], true}

        ["hd", details], _ ->
          {["hd", Map.put(details, query, [changes])], true}

        other, acc ->
          {other, acc}
      end)

    #  we either simply push a new event to the stack when their were no merged
    #  head events or we replace the whole list of events with our mapped variant
    #  including merged head events
    if merged? do
      socket
      |> Map.from_struct()
      |> put_in([:private, :__changed__, :push_events], events)
      |> then(&struct(Socket, &1))
    else
      push_event(socket, "hd", Map.put(%{}, query, [changes]))
    end
  end
end
