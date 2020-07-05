# envlog
A logger for environment data.

## Installation
### gems
I am not registered gem file to gem.org at the moment, so build  a gem file by yourself.

```
$ bundle install
$ rake build
```

Use the file to install it with the gem command.

```
$ gem install pkg/envlog-0.x.x.gem
```

This gem also uses MySQL (or MariaDB) and SQLite3 as its choice. for this reason, dependencies for the database interface are not specified in gemspec . Please install one of the gems beforehand.

```
$ gem install sqlite3
```
or
```
$ gem install mysql2
```

### sensor and gateway devices
Both can be built using [PlatformIO](https://platformio.org/). Edit the source "src/main.ino" and change the settings, and then build it as follows.

```
$ pio run
```

If you want to upload to your device, do the following：
```
$ pio run -t upload
```

## Usage
### Logger process
This process is receiving data from a sensor and registering it in the database. Data can be received  input by serial device via  gateway device or by UDP available. You can choose to use either SQLite3 or MySQL(MariaDB) as the database.

```
envlog-logger [options]

options:
    -c, --config-file=FILE
    -s, --dump-config-template
    -l, --list-device
    -a, --add-device=ADDR,POWER-SOURCE,DESCR
    -r, --remove-device=ADDR
```

#### options
<dl>
  <dt>-c, --config-file=FILE</dt>
  <dd>Specifies the configuration file to be used. This configuration file can use the same file as the envlog-viewer.</dd>

  <dt>-s, --dump-config-template</dt>
  <dd>Outputs the template of configuration file to the STDOUT. </dd>

  <dt>-l, --list-device</dt>
  <dd>Show a list of currently registered sensor devices.</dd>

  <dt>-a, --add-device=ADDR,POWER-SOURCE,DESCR</dt>
  <dd>Register a sensor device. In order to receive the data, the sensor device must be activated with this option It is. The same goes for sensor devices that are automatically registered as unknown devices.</dd>

  <dt>-r, --remove-device=ADDR</dt>
  <dd>De-register the sensor device.</dd>
</dl>


### Viewer process
It works as an HTTP server for referencing stored data.

```
envlog-viewer [options]

options:
    -c, --config-file=FILE
    -s, --dump-config-template
    -A, --add-user
        --develop-mode
```

#### options
<dl>
  <dt>-c, --config-file=FILE</dt>
  <dd>Specifies the configuration file to be used. This configuration file can use the same file as the envlog-logger.</dd>

  <dt>-s, --dump-config-template</dt>
  <dd>Outputs the template of configuration file to the STDOUT. </dd>

  <dt>-A, --add-user</dt>
  <dd>User registration for digest authentication is performed (Digest authentication settings (e.g., enable/disable, path for password file, etc.) are specified in the configurationpecify this option, shall add your username and password to the addtional arguments.
file). </dd>
</dl>

## How to bootstrap
T.B.D

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/kwgt/envlog

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
