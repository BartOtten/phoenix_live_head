defmodule Phx.Live.MergeTest do
  use ExUnit.Case, async: true

  def push_or_merge_head_change(a1, a2, a3),
    do: Phx.Live.Head.pub_push_or_merge_head_change().(a1, a2, a3)

  @q1 "fav"
  @q2 ".class"

  @restore ["g", "*", "backup_name"]
  @restore_attr ["g", "class", "backup_name"]
  @backup ["b", "*", "backup_name"]
  @backup_attr ["b", "class", "backup_name"]
  @event1 [:set, "class", "some-class"]
  @event2 [:delete, "class", "some-class"]

  @reset ["i", "*", "i"]
  @reset_attr ["i", "class", "i"]

  test "First" do
    result = push_or_merge_head_change([[]], @q1, @event1)

    assert [["fav", [[:set, "class", "some-class"]]]] = result
  end

  test "Overwrite previous result" do
    result = push_or_merge_head_change([[]], @q1, @event1)
    assert [["fav", [[:set, "class", "some-class"]]]] = result

    result = push_or_merge_head_change(result, @q1, @event2)
    assert [["fav", [[:delete, "class", "some-class"]]]] = result
  end

  test "Merge q2" do
    result = push_or_merge_head_change([[]], @q1, @event1)
    assert [["fav", [[:set, "class", "some-class"]]]] = result

    result = push_or_merge_head_change(result, @q2, @event1)

    assert [[".class", [[:set, "class", "some-class"]]], ["fav", [[:set, "class", "some-class"]]]] =
             result
  end

  test "Reset clears all" do
    result =
      push_or_merge_head_change([[]], @q1, @event1)
      |> push_or_merge_head_change(@q1, @reset)

    assert [["fav", [["i", "*", "i"]]]] = result
  end

  test "Reset is cautious" do
    result = push_or_merge_head_change([[]], @q1, @event1)
    result = push_or_merge_head_change(result, @q1, @backup)
    assert [["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]] = result

    result_before_reset = push_or_merge_head_change(result, @q2, @event1)

    assert [
             [".class", [[:set, "class", "some-class"]]],
             ["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]
           ] = result_before_reset

    # when backup is in list, no actions are deleted
    result = push_or_merge_head_change(result_before_reset, @q1, @reset)

    assert [
             ["fav", [["i", "*", "i"]]],
             [".class", [[:set, "class", "some-class"]]],
             # class is changed before the backup
             ["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]
           ] = result

    # added due to backup
    result_before_reset = push_or_merge_head_change(result_before_reset, @q1, @event2)

    # backup attr
    result_before_reset = push_or_merge_head_change(result_before_reset, @q1, @backup_attr)

    assert [
             [
               "fav",
               [
                 ["b", "class", "backup_name"],
                 [:delete, "class", "some-class"]
               ]
             ],
             [".class", [[:set, "class", "some-class"]]],
             ["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]
           ] = result_before_reset

    # reset attr
    result = push_or_merge_head_change(result_before_reset, @q1, @reset_attr)
    # after reset, set this attr
    result = push_or_merge_head_change(result, @q1, @event1)
    # replaces revent1 in second change list
    result = push_or_merge_head_change(result, @q1, @event2)

    assert [
             [
               "fav",
               [
                 [:delete, "class", "some-class"],
                 ["i", "class", "i"],
                 ["b", "class", "backup_name"],
                 [:delete, "class", "some-class"]
               ]
             ],
             [".class", [[:set, "class", "some-class"]]],
             ["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]
           ] = result

    # restore
    result = push_or_merge_head_change(result, @q1, @restore)
    # do something after restore
    result = push_or_merge_head_change(result, @q1, @event2)

    assert [
             [
               "fav",
               [
                 [:delete, "class", "some-class"],
                 ["g", "*", "backup_name"],
                 ["i", "class", "i"],
                 ["b", "class", "backup_name"],
                 [:delete, "class", "some-class"]
               ]
             ],
             [".class", [[:set, "class", "some-class"]]],
             ["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]
           ] == result

    # restore attr (overriding earlier event)
    result = push_or_merge_head_change(result, @q1, @restore_attr)

    assert [
             [
               "fav",
               [
                 ["g", "class", "backup_name"],
                 ["g", "*", "backup_name"],
                 ["i", "class", "i"],
                 ["b", "class", "backup_name"],
                 [:delete, "class", "some-class"]
               ]
             ],
             [".class", [[:set, "class", "some-class"]]],
             ["fav", [["b", "*", "backup_name"], [:set, "class", "some-class"]]]
           ] == result
  end
end
