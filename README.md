# Phoenix Live Head

  Provides commands for manipulating the HTML Head of Phoenix Live View applications
  while minimizing data over the wire.

  The available command actions support a variety of utility operations useful for
  HTML Head manipulation. Such as setting or removing tag attributes and
  adding or removing CSS classes. 

  > #### Note {: .info}
  > When using this lib directly, consider publishing a high-level lib
  > like [Phx.Live.Favicon](https://hexdocs.pm/phoenix_live_favicon/). 
  > High-level libs provide a cleaner syntax and specific documentation
  > for their intended usage.

## Documentation
Documentation can be found at [HexDocs](https://hexdocs.pm/phoenix_live_head).

## Support, Feature Requests and Contributing
See [CONTRIBUTING](CONTRIBUTING.md)


## Installation

The package can be installed by adding `phoenix_live_head` to your list of 
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_live_head, "~> 0.1.2"}
  ]
end
```

To include the necessary client side Javascript, import the module in `assets/js/app.js`

```javascript
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "../vendor/phoenix_live_view/"
import topbar from "../vendor/topbar"
import "phoenix_live_head" // <-- ADD HERE.
```

## Development

- Assets can be build using `mix assets.build`
- Override `:phoenix_live_head` in your test application with a local path:
```elixir
# example
def deps do
  [
    {:phoenix_live_head, path: "../phoenix_live_head", override: true}
  ]
end
```
