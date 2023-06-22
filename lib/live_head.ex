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
    * `snap` - Takes a snapshot of all selected nodes.
    * `restore` - Restores a saved snapshot.
    * `dynamic` - Set the value of a `{placeholder}`.

  ### Attributes
  The actions are applied to an attribute in all selected HTML elements.

  Supported actions on the "class" attribute:

    * `set` - Set class name(s).
    * `add` - Add to list of class names.
    * `remove` - Remove from list of class names.
    * `toggle` - Toggle class name.
    * `initial` - Reset attribute to it's intial value.

  Supported actions on other attributes:

    * `set` - Set value of attribute.
    * `initial` - Reset attribute to it's intial value.
    * `snap` - Take a snapshot of all selected nodes.
    * `restore` - Restore attributes using a saved snapshot

  ## Dynamic attributes / placeholders

  To use a dynamic value for an attribute, the element must have an additional
  `data-dynamic-[attribute]` attribute with a value containing a named
  placeholder. For example: `{sub}`.

  **Example**
  ```html
    <!-- data-dynamic-href is set -->
    <!-- {sub} is used in it's value -->
  <link rel='icon' href="default_fav.png" data-dynamic-href="favs/{sub}/fav-16x16.png">
  ```

  When an event is pushed with `target = "link[rel*=icon]"`, `action = :dynamic`, `attr = "sub"`, and
  `value = "new_message"` the result will look like:

  ```html
  <link rel='icon' href="favs/new_message/fav-16x16.png" [...]>
  ```
  """

  import Phoenix.LiveView, only: [push_event: 3]

  alias Phoenix.LiveView.Socket
  alias Phoenix.LiveView.Utils

  @initial "i"
  @snap "b"
  @restore "r"
  @all "*"

  @type action :: :add | :dynamic | :initial | :remove | :set | :toggle | :snap | :restore
  @type query :: String.t()
  @type attr :: String.t() | atom()
  @type value :: String.t() | atom() | integer()
  @type name :: String.t() | atom()
  @type change :: [...]

  @doc """
  Reset all `attributes` of elements matching `query` to their initial value.
  """
  @spec reset(Socket.t(), query) :: Socket.t()
  def reset(socket, query) do
    query = maybe_min_query(query)
    push_or_merge_head_event(socket, query, [@initial, @all, @initial])
  end

  @doc """
  Reset an `attribute` of elements matching `query` to it's initial value.
  """
  @spec reset(Socket.t(), query, attr) :: Socket.t()
  def reset(socket, query, attr), do: push(socket, query, :initial, attr, @initial)

  @doc """
   Create a snapshot named `name` of an `attribute` from all favicon link element
  """
  @spec snap(Socket.t(), query, name, attr) :: Socket.t()
  def snap(socket, query, name, attr \\ @all) do
    query = maybe_min_query(query)
    push_or_merge_head_event(socket, query, [@snap, attr, name])
  end

  @doc """
   Restore an `attribute` from snapshot with named `name`.
  """
  @spec restore(Socket.t(), query, name, attr) :: Socket.t()
  def restore(socket, query, name, attr \\ @all) do
    query = maybe_min_query(query)
    push_or_merge_head_event(socket, query, [@restore, attr, name])
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
  defp maybe_min_attr(other) when is_atom(other), do: other |> to_string() |> maybe_min_attr()

  @spec maybe_min_query(query) :: String.t()
  defp maybe_min_query("link[rel*='icon']"), do: "f"
  defp maybe_min_query(other) when is_binary(other), do: other

  @spec min_action(action) :: :a | :d | :i | :x | :s | :t
  defp min_action(:dynamic), do: :d
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
      |> Utils.get_push_events()
      |> Enum.map_reduce(false, fn
        ["hd", %{c: changes}], _ ->
          {["hd", %{c: push_or_merge_head_change(changes, query, change)}], true}

        other, merged? ->
          {other, merged?}
      end)

    cond do
      # Phoenix LiveView < 0.19
      merged? && Map.has_key?(socket.private, :__changed__) ->
        put_in(socket.private.__changed__.push_events, events)

      # Phoenix LiveView >= 0.19
      merged? ->
        put_in(socket.private.__temp__.push_events, events)

      # simply push a new event to the stack when there are no merged head events
      true ->
        push_event(socket, "hd", %{c: [[query, [change]]]})
    end
  end

  # no previous changes
  defp push_or_merge_head_change([[] = rest], query, change), do: new_bucket(query, rest, change)

  # query matches query of last set of changes
  defp push_or_merge_head_change([[q, changes] | rest], q, [@initial, attr, _] = change) do
    changes = split_and_override_attr(changes, attr, [@snap])
    prepend_to_bucket(q, changes, change, rest)
  end

  defp push_or_merge_head_change([[q, changes] | rest], q, [@snap, _, _] = change) do
    prepend_to_bucket(q, changes, change, rest)
  end

  defp push_or_merge_head_change([[q, changes] | rest], q, [@restore, attr, _] = change) do
    changes = split_and_override_attr(changes, attr, [@snap])
    prepend_to_bucket(q, changes, change, rest)
  end

  defp push_or_merge_head_change([[q, changes] | rest], q, [_, attr, _] = change) do
    changes = split_and_override_attr(changes, attr, [@snap, @initial, @restore])
    prepend_to_bucket(q, changes, change, rest)
  end

  # query does not match query of last set of changes
  defp push_or_merge_head_change(rest, query, change), do: new_bucket(query, rest, change)

  defp split_and_override_attr(changes, attr, splitters) do
    {overridable, to_keep} =
      Enum.split_while(changes, fn [action, _a, _v] -> action not in splitters end)

    if attr == @all do
      to_keep
    else
      Enum.reject(overridable, &match?([_, ^attr, _], &1)) ++ to_keep
    end
  end

  defp new_bucket(query, rest, change), do: [[query, [change]] | rest]
  defp prepend_to_bucket(query, changes, change, rest), do: [[query, [change | changes]] | rest]

  @doc false
  def pub_push_or_merge_head_change, do: &push_or_merge_head_change/3
end
