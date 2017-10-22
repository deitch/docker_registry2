## v1.3.0, 22 October 2017

- Add basic tests
- Add support for both v1 and v2 schemas thanks to https://github.com/lehn-etracker

## v1.2.0, 15 October 2017

- Add shorter default timeouts. Previously, the RestClient default of 60 seconds
  was used for both open_timeout and read_timeout. Now, those values are set at
  2 seconds and 5 seconds, respectively.

## v1.1.0, 13 October 2017

- Move `ping` call from `DockerRegistry2::Registry.new` to
  `DockerRegistry2.connect`, to allow a registry to be initialized without a
  ping.

