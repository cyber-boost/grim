# Grim Python API Documentation

## Module `config`

Configuration Management for Grim Core
Environment-aware configuration with validation and defaults

### `Any`

Special type indicating an unconstrained type.

- Any is compatible with every type.
- Any assumed to have all methods.
- All values assumed to be instances of Any.

Note that all the above statements are true from the point of view of
static type checkers. At runtime, Any should not be used with instance
checks.

### `BackupConfig`

Backup configuration settings

### `Config`

Main configuration class for Grim

### `DatabaseConfig`

Database configuration settings

### `LoggingConfig`

Logging configuration settings

### `MonitoringConfig`

Monitoring configuration settings

### `Path`

PurePath subclass that can make system calls.

Path represents a filesystem path but unlike PurePath, also offers
methods to do system calls on path objects. Depending on your system,
instantiating a Path will return either a PosixPath or a WindowsPath
object. You can also instantiate a PosixPath or WindowsPath directly,
but cannot instantiate a WindowsPath on a POSIX system or vice versa.

### `PerformanceConfig`

Performance configuration settings

### `SecurityConfig`

Security configuration settings

### `WebConfig`

Web server configuration settings

### `dataclass`

Add dunder methods based on the fields defined in the class.

Examines PEP 526 __annotations__ to determine fields.

If init is true, an __init__() method is added to the class. If repr
is true, a __repr__() method is added. If order is true, rich
comparison dunder methods are added. If unsafe_hash is true, a
__hash__() method is added. If frozen is true, fields may not be
assigned to after instance creation. If match_args is true, the
__match_args__ tuple is added. If kw_only is true, then by default
all fields are keyword-only. If slots is true, a new class with a
__slots__ attribute is returned.

### `field`

Return an object to identify dataclass fields.

default is the default value of the field.  default_factory is a
0-argument function called to initialize a field's value.  If init
is true, the field will be a parameter to the class's __init__()
function.  If repr is true, the field will be included in the
object's repr().  If hash is true, the field will be included in the
object's hash().  If compare is true, the field will be used in
comparison functions.  metadata, if specified, must be a mapping
which is stored but not otherwise examined by dataclass.  If kw_only
is true, the field will become a keyword-only parameter to
__init__().

It is an error to specify both default and default_factory.

### `get_config`

Get global configuration instance

### `set_config`

Set global configuration instance

## Module `generator`

Grim Documentation Generator

Scans all Python modules in py_grim, extracts docstrings, and generates Markdown and HTML documentation.
Also generates user guides, developer guides, and migration guides as stubs.

### `Path`

PurePath subclass that can make system calls.

Path represents a filesystem path but unlike PurePath, also offers
methods to do system calls on path objects. Depending on your system,
instantiating a Path will return either a PosixPath or a WindowsPath
object. You can also instantiate a PosixPath or WindowsPath directly,
but cannot instantiate a WindowsPath on a POSIX system or vice versa.

### `extract_module_doc`

Extract docstrings from a Python module.

### `generate_html`



### `generate_markdown`



### `main`



### `scan_modules`

Recursively find all .py files in base_dir.


---

# User Guide

How to use Grim system, CLI, and dashboard.

(Section to be completed.)

# Developer Guide

How to contribute, code structure, and best practices.

(Section to be completed.)

# Migration Guide

How to migrate from legacy systems to Grim Python/Go stack.

(Section to be completed.)

