Sycl - Simple YAML Config Library
=================================

**Sycl** is a gem that makes using [YAML](http://yaml.org/) for
configuration files convenient and easy. Hashes and arrays made from
parsing YAML via Sycl get helper methods that provide simple and natural
syntax for querying and setting values. YAML output through Sycl is
sorted, so configuration file versions can be compared consistently, and
Sycl has hooks to add output styles, so your configuration files stay
easy for humans to read and edit, even after being parsed and
re-emitted.

Getting Started
---------------

Install it:

    $ gem install sycl

Reference it in your [Bundler](http://gembundler.com/) Gemfile:

    gem 'sycl'

Use it in Ruby code as a YAML library replacement:

    require 'rubygems'
    require 'sycl'
    
    d = Sycl::load_file 'foo.yml'
    d.bar = 'baz'
    puts d.to_yaml

Run it from the command line to get `awk` style YAML processing:

    $ sycl 'puts d.foo' bar.yml

Description
-----------

Loading YAML text using Sycl should be familiar looking if you've used
YAML libraries in the past:

    # Parse YAML text from yaml_string
    data = Sycl::load yaml_string

    # Open and parse YAML from a file
    data = Sycl::load_file 'filename.yml'

    # Emit YAML from an object
    puts data.to_yaml

Accessing data from config files often involves multi-level hashes. If
you know beforehand the structure of the hashes, you can use method call
notation on Sycl hashes to get and set values:

    value = data.foo.bar.baz  # same as: data['foo']['bar']['baz']
    data.foo.bar.baz = 'qux'  # same as: data['foo']['bar']['baz'] = 'qux'

Sycl provides convenient methods to safely get and set values in
multi-level hashes, when you don't know whether intermediate keys in
multi-level hashes are always set:

    # These die if intermediate values are missing (data['foo']['bar'] == nil)
    value = data['foo']['bar']['baz']
    data['foo']['bar']['baz'] = 'qux'

    # This access is always safe, returns nil if data['foo']['bar'] == nil
    value = data.get 'foo.bar.baz'

    # Safe set auto-vivifies data['foo']['bar'] = {} if it does not exist
    data.set 'foo.bar.baz', 'qux'

Combining configuration data from multiple files is a common operation,
for example, to allow local settings to override base settings; so, deep
hash merge is a native operation for Sycl datasets:

    # config/foo.yml is shared, config/local/foo.yml different per host
    base_config = Sycl::load_file 'config/foo.yml'
    local_config = Sycl::load_file 'config/local/foo.yml'
    merged_config = base_config.deep_merge local_config

Finally, Sycl contains hooks to make YAML output consistent and
beautiful. When outputting YAML, Sycl datasets are always output with
arrays and hashes sorted, so different versions of configuration files
can be compared with a `diff` tool. Sycl also lets you mark nodes as
being rendered in inline (rather than block) format. For example,
imagine the following YAML defines a host in a datacenter, including a
list of users that can log in to it:

    hostname: dojo
    ip_address: 192.168.0.100
    users:
    - alice
    - bob
    - charlie

We might want to mark it up like the following example to indicate which
users have superuser privileges:

    hostname: dojo
    ip_address: 192.168.0.100
    users:
    - alice: {sudo: true}
    - bob: {sudo: true}
    - charlie

Normal YAML parsing and emitting will result unsorted, block formatted
output, as in the following example:

    ip_address: 192.168.0.100
    users:
    - alice:
        sudo: true
    - bob:
        sudo: true
    - charlie
    hostname: dojo

Sycl lets you style your YAML with inline blocks:

    host = Sycl::load_file 'hosts/dojo.yml'
    host.users.each { |u| u.render_inline! }
    puts host.to_yaml  # This is output with each user rendered inline

Calling `host.to_yaml` with the example code above above would result in
the expected, human-readable output with sorted values, and with users
rendered one per line.

### Command-Line Sycl Processing ###

Sycl includes a command line `sycl` tool which is like `awk`, but for
processing YAML files with Ruby, with Sycl syntax built in. You run it
on one or more YAML files like in the following example:

    $ sycl 'puts d.foo.bar.baz' foo.yml

The first required argument is Ruby code to run, which gets a few magic
variables that you can reference:

* `f` is the current YAML input file's filename
* `y` is the literal YAML text from that file (the file's raw contents)
* `d` is the Sycl object which is the data parsed from the current input file

Assuming the host file example above, here's how you might print out an
`/etc/hosts` file for your network:

    $ sycl 'puts "#{d.ip_address} #{d.hostname}"' hosts/*.yml

And here's how you might print out the hostnames of hosts that user
`bob` can access:

    $ sycl 'puts d.hostname if d.users.any? { |u| u == "bob" || (u.is_a?(Hash) && u.keys.first == "bob") }' hosts/*.yml

You can also make in-place edits to YAML files. For example, here's how
you'd delete user `charlie` from all hosts:

    $ sycl -i 'd.users.delete_if { |u| u == "charlie" || (u.is_a?(Hash) && u.keys.first == "charlie") }' hosts/*.yml

Meta
----

* Home: <https://github.com/groupon/sycl>
* Bugs: <https://github.com/groupon/sycl/issues>
* Authors: <https://github.com/andrewgho>

### Prior Art ###

There are a number of existing libraries that attempt to give easy
access to hash values, or merge YAML files across directories:

* [figgy](https://github.com/pd/figgy)
* [hashie](https://github.com/intridea/hashie)

Sycl is unique in its emphasis on sorted, comparable output; and its
ability to style YAML output by node, and in providing a `awk`-like
tool to directly manipulate YAML from the command line using the compact
Sycl syntax.
