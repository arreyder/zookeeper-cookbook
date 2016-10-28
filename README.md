# tgt-zookeeper
A very simple, proven zk cookbook.

Staticly defined safe zookeeper config with json logging to stdout.

Does not use search for zk node discovery, requires an attribute, zk.servers, to be defined that maps the ip to id and provides the list of servers.

Metrics will be found and submitted to graphite by the serverstats script.

Expectation is that this will be run from a role setting appropriate attributes.  Minimal config items are expose, will add as we need to move from defaults.

If you want more than a standalone zk server you must define zk.servers

If you want to open up ports for a clients that can be identified by a  recipe or role, you need to define zk.clients array.
They will be added as OR clauses to client search that is dc and environment specific.

Example Role:

```
{
  "name": "zk-stage-west-infra",
  "description": "zk-stage-west-infra",
  "json_class": "Chef::Role",
  "default_attributes": {
    "zk":{
      "servers": { "10.48.41.83": 1, "10.48.41.6": 2, "10.48.41.5": 3 },
      "version": "3.4.6",
      "clients": ["role:tgt-elk-wrapper", "role:kafka-wrapper"]
    }
  },
  "override_attributes": {

  },
  "chef_type": "role",
  "run_list": [
    "recipe[tgt-zookeeper]"
  ],
  "env_run_lists": {

  }
}
```
