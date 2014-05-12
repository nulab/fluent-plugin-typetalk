# fluent-plugin-typetalk

## Overview

[Fluentd](http://fluentd.org) plugin to emit notifications to Typetalk.

## Installation

Install with gem or fluent-gem command as:

```
# for fluentd
$ gem install fluent-plugin-typetalk

# for td-agent
$ sudo /usr/lib64/fluent/ruby/bin/fluent-gem install fluent-plugin-typetalk
```

## Configuration

### Usage

This plugin uses client credentials for authentication. See [the developer document](http://developers.typetalk.in/oauth.html) how to get your own credential.
```
<match ...>
  type typetalk
  client_id YOUR_CLIENT_ID
  client_secret YOUR_CLIENT_SECRET
  topic_id YOUR_TOPIC_ID
</match>
```

The default output format is "<%= tag %> at <%= Time.at(time).localtime %>\n<%= record.to_json %>" and an example output is like this:
```
test at 2014-05-13 01:21:30  0900
{"message":"test1"}
```

To change output format, you can set "template" parameter as follows:
```
<match ...>
  type typetalk
  client_id YOUR_CLIENT_ID
  client_secret YOUR_CLIENT_SECRET
  topic_id YOUR_TOPIC_ID
  template "Check! <%= record.to_json %>"
</match>
```
Then you'll get the output like this:
```
Check! {"message":"test1"}
```

## TODO

Pull requests are very welcome!!

## For developers

To run tests, do the following.
```
$ VERBOSE=1 bundle exec rake test
```

## Copyright

Copyright :  Copyright (c) 2014- Takashi Someda (@tksmd)
License   :  Apache License, Version 2.0
