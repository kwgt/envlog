# envlog
A logger for environment data.

## Usage
### Logger process
This process is receiving data from a sensor and registering it in the database. Data can be received  input by serial device via  gateway device or by UDP available. You can choose to use either SQLite3 or MySQL(MariaDB) as the database.

```
envlog-logger [options]

options:
    -c, --config-file=FILE
    -s, --dump-config-template
```

#### options
<dl>
  <dt>-c, --config-file=FILE</dt>
  <dd>Specifies the configuration file to be used. This configuration file can use the same file as the envlog-viewer.</dd>

  <dt>-s, --dump-config-template</dt>
  <dd>Outputs the template of configuration file to the STDOUT. </dd>
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

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/kwgt/envlog

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
