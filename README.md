# Cove

[![Build](https://github.com/emanuele-em/cove/actions/workflows/build.yml/badge.svg)](https://github.com/emanuele-em/cove/actions/workflows/build.yml)
[![Download](https://img.shields.io/github/v/release/emanuele-em/cove?label=Download&style=flat)](https://github.com/emanuele-em/cove/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-000000.svg?logo=apple)](https://developer.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138.svg?logo=swift&logoColor=white)](https://swift.org)

A native macOS database client. Fast, lightweight, extensible.

![Cove demo](docs/hero.gif)

### Supported databases

<table>
  <tr>
    <td align="center"><img src="https://wiki.postgresql.org/images/a/a4/PostgreSQL_logo.3colors.svg" width="40"><br><b>PostgreSQL</b></td>
    <td align="center"><img src="https://labs.mysql.com/common/logos/mysql-logo.svg?v2" width="40"><br><b>MySQL</b></td>
    <td align="center"><img src="https://mariadb.com/wp-content/uploads/2019/11/mariadb-logo-vert_blue-transparent.png" width="40"><br><b>MariaDB</b></td>
    <td align="center"><img src="https://www.sqlite.org/images/sqlite370_banner.gif" width="60"><br><b>SQLite</b></td>
    <td align="center"><img src="https://www.mongodb.com/assets/images/global/favicon.ico" width="40"><br><b>MongoDB</b></td>
    <td align="center"><img src="https://redis.io/wp-content/uploads/2024/04/Logotype.svg" width="40"><br><b>Redis</b></td>
    <td align="center"><img src="https://upload.wikimedia.org/wikipedia/en/4/41/ScyllaDB_logo.png" width="40"><br><b>ScyllaDB</b></td>
    <td align="center"><img src="https://cassandra.apache.org/_/img/cassandra_logo.svg" width="40"><br><b>Cassandra</b></td>
    <td align="center"><img src="https://assets.streamlinehq.com/image/private/w_300,h_300,ar_1/f_auto/v1/icons/3/elasticsearch-rhi1c3ieeke9l2ht6jy755.png/elasticsearch-a2ax512pgkubl5gtrelkoc.png?_a=DATAiZAAZAA0" width="40"><br><b>Elasticsearch</b></td>
  </tr>
</table>

Adding a new backend requires zero changes to UI code — see [`DB/README.md`](Cove/DB/README.md).

## Features

- **Browse** schemas, tables, views, indexes, and keys in a sidebar tree
- **Edit rows** inline with SQL/CQL preview before commit
- **Run queries** with syntax highlighting and autocomplete
- **Multiple tabs** with independent connections (Cmd+T)
- **Connection environments** — local, dev, staging, production
- **SSH tunneling** — password or private key authentication
- **Session persistence** — connections and tabs restore across app relaunches
- **Encrypted credentials** — stored in macOS Keychain
- **Color-coded indicators** and connection tooltips
- Native macOS UI — no Electron, no web views

## Install

Download the latest `.dmg` from [Releases](https://github.com/emanuele-em/cove/releases/latest).

> On first launch, macOS may block the app. Right-click the app and select **Open** to bypass Gatekeeper.

Or build from source:

```
xcodebuild -scheme Cove -derivedDataPath .build build
open .build/Build/Products/Debug/Cove.app
```

Requires macOS 15+.

## Roadmap

Contributions welcome:

- Import/export (CSV, JSON, SQL)
- Data filtering and search
- Query history panel
- SSL/TLS certificate configuration UI
- Query explain/analyze visualization
- Homebrew cask

## Community

- [Bug reports](https://github.com/emanuele-em/cove/issues/new?template=bug_report.md)
- [Feature requests](https://github.com/emanuele-em/cove/issues/new?template=feature_request.md)
- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

## License

[MIT](LICENSE)
