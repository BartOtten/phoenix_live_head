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

  ### Nodes / Elements
    * `backup` - Takes s snapshot of all selected nodes.
    * `restore` - Restores a saved snapshot

  ### Attributes
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
  @backup "b"
  @restore "r"
  @all "*"

  @type action :: :add | :dynamic | :initial | :remove | :set | :toggle | :backup | :restore
  @type query :: String.t()
  @type attr :: String.t() | atom()
  @type value :: String.t() | atom() | integer()
  @typep reset :: String.t()
  @typep change :: [...] | reset
  @type key :: String.t() | atom() | integer()

  @doc """
  Reset all `attributes` of elements matching `query` to their initial value.
  """
  @spec reset(Socket.t(), query) :: Socket.t()
  def reset(socket, query) do
    query = maybe_min_query(query)
    push_or_merge_head_event(socket, query, [@initial, @all, @initial])
  end

  @doc """
  Reset an `attribute` of elements matching `query` to it's initial value
  """
  @spec reset(Socket.t(), query, attr) :: Socket.t()
  def reset(socket, query, attr), do: push(socket, query, :initial, attr, @initial)

  @doc """
  Backups the current values of elements matching `query` under `key`
  """
  @spec backup(Socket.t(), query, key, attr) :: Socket.t()
  def backup(socket, query, key, attr \\ @all) do
    query = maybe_min_query(query)
    push_or_merge_head_event(socket, query, [@backup, attr, key])
  end

  @doc """
  Restores the current values of elements matching `query` under `key`
  """
  @spec restore(Socket.t(), query, key, attr) :: Socket.t()
  def restore(socket, query, key, attr \\ @all) do
    query = maybe_min_query(query)
    push_or_merge_head_event(socket, query, [@restore, attr, key])
  end

  @doc """
  Pushes `action` to apply on `attribute` of elements matching `query`. See [Actions](#module-actions) for available actions.
  """
  @spec push(Socket.t(), query, action, attr, value | nil) :: Socket.t()
  def push(socket, query, action, attr, value \\ nil)
      when not (action != :remove and is_nil(value)) do
    query = maybe_min_query(query)
    action = min_action(action)
    attr = maybe_min_attr(attr)

    push_or_merge_head_event(socket, query, [action, attr, value])
  end

  @spec maybe_min_attr(attr) :: String.t()
  defp maybe_min_attr("class"), do: "c"
  defp maybe_min_attr("class-name"), do: "c"
  defp maybe_min_attr("href"), do: "h"
  defp maybe_min_attr(other) when is_binary(other), do: other
  defp maybe_min_attr(other) when is_atom(other), do: to_string(other) |> maybe_min_attr()

  @spec maybe_min_query(query) :: String.t()
  defp maybe_min_query("link[rel*='icon']"), do: "f"
  defp maybe_min_query(other) when is_binary(other), do: other

  @spec min_action(action) :: :a | :d | :i | :x | :s | :t | :b | :r
  defp min_action(:dynamic), do: :d
  defp min_action(:backup), do: @backup
  defp min_action(:restore), do: @restore
  defp min_action(:set), do: :s
  defp min_action(:remove), do: :x
  defp min_action(:add), do: :a
  defp min_action(:toggle), do: :t
  defp min_action(:initial), do: :i

  @spec push_or_merge_head_event(Socket.t(), query, change) :: Socket.t()
  defp push_or_merge_head_event(%Socket{} = socket, query, change)
       when is_binary(query) and (is_list(change) or change === @initial) do
    # use an accumulator to signal if head events were merged so
    # the list only has to be traversed once.
    {events, merged?} =
      socket
      |> Phoenix.LiveView.Utils.get_push_events()
      |> Enum.map_reduce(false, fn
        ["hd", %{c: changes}], _ ->
          {["hd", %{c: push_or_merge_head_change(changes, query, change)}], true}

        other, merged? ->
          {other, merged?}
      end)

    #  we either simply push a new event to the stack when their were no merged
    #  head events or we replace the whole list of events with our mapped variant
    #  including merged head events
    if merged? do
      put_in(socket.private.__changed__.push_events, events)
    else
      push_event(socket, "hd", %{c: [[query, [change]]]})
    end
  end

  # no changes
  defp push_or_merge_head_change([[] = rest], query, change), do: new_bucket(query, rest, change)

  # query matches query of last set of changes
  defp push_or_merge_head_change([[q, changes] | rest], q, [action, attr, _] = change) do
    cond do
      action == @initial ->
        changes = split_and_override(changes, attr, [@backup])
        prepend_to_bucket(q, changes, change, rest)

      action == @backup ->
        prepend_to_bucket(q, changes, change, rest)

      action == @restore and attr == @all ->
        changes = split_and_override(changes, attr, [@backup])
        prepend_to_bucket(q, changes, change, rest)

      true ->
        changes = split_and_override(changes, attr, [@backup, @initial, @restore])
        prepend_to_bucket(q, changes, change, rest)
    end
  end

  defp push_or_merge_head_change(rest, query, change), do: new_bucket(query, rest, change)

  defp split_and_override(changes, attr, splitters) do
    {overridable, to_keep} =
      Enum.split_while(changes, fn [action, _a, _v] -> action not in splitters end)

    Enum.reject(overridable, &match?([_, ^attr, _], &1)) ++ to_keep
  end

  defp new_bucket(query, rest, change), do: [[query, [change]] | rest]
  defp prepend_to_bucket(query, changes, change, rest), do: [[query, [change | changes]] | rest]
end
