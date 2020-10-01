# LiveReload.cr

This is a [LiveReload](https://github.com/livereload/livereload-js) server implementation in [Crystal](http://crystal-lang.org/).

It creates an HTTP server at `http://0.0.0.0:35729` that serves the `/livereload.js` script and handles [official-7 protocol](http://livereload.com/api/protocol/) via websocket.

Currently, it does not watch the filesystem for changes. You can use [bcardiff/crystal-fswatch](https://github.com/bcardiff/crystal-fswatch) or [petoem/inotify.cr](https://github.com/petoem/inotify.cr) and trigger a `LiveReload::Server#send_reload`.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     live_reload:
       github: bcardiff/live_reload.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "live_reload"
require "fswatch"

dir = Dir.current
live_reload = LiveReload::Server.new
FSWatch.watch dir do |event|
  live_reload.send_reload(path: event.path, liveCSS: event.path.ends_with?(".css"))
end

puts "Watching changes from #{dir}"
puts "LiveReload on http://#{live_reload.address}"

live_reload.listen
```

## Contributing

1. Fork it (<https://github.com/bcardiff/live_reload.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Brian J. Cardiff](https://github.com/bcardiff) - creator and maintainer
