# Changelog
## v0.2.0
### Features
#### Create and restore snapshots
Store the result of multiple operations under a chosen `name` and restore it
at a later time using `snap` and `restore`.

* `snap` - Takes a snapshot of all attribute values.
* `restore` - Applies a snapshot to selected elements.

**Usage example**
In the Live Favicon Example application it is used to send all changes required to switch
between an dynamic SVG counter and static PNG message-icon once, and toggle the
state between them; creating a flashing notification. As it also makes a snapshot of the state
*before* the favicon begins to flash, the icon on the page can be restored to it's
value as soon as the user read the unread messages.

#### Use multiple placeholders
You can now use multiple custom named placeholders, instead of only one `{dynamic}` per attribute.

```diff
<link [...]
   data-dynamic-href="data:image/svg+xml,
     <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'>
       <circle cx='50' cy='50' r='50' fill='{counter_background}' />
       <text x='50%' y='50%' [...]>
         {counter}
       </text>
     </svg>
   "
>
```

### Fixes
* Unstable order of change execution when using multiple queries / libs.

### BREAKING
* the attribute value of `dynamic` is now used as name for the target placeholder. As a result, it is not
possible anymore to target a specific attribute. Migration is as easy as using different names per attribute
when necessary.

## v0.1.2
Discards previous changes put in events for given element or attribute when using `reset`.

* Fix: preserve event order
* Fix: predictable behavior when using `reset/1` or `reset/2`.
* Fix: undefined class name after reset

## v0.1.1
Fix: Loosen dependency versions

## v0.1.0
Release

## v0.0.1
Initial commit
