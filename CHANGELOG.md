## v1.1.0, 13 October 2017

- Move `ping` call from `DockerRegistry2::Registry.new` to
  `DockerRegistry2.connect`, to allow a registry to be initialized without a
  ping.

