#!/usr/bin/env bash
set -ex

PRIMARY=mongo-0

CMD_MONGO_NOAUTH="kubectl --context kube-aws-k8s-uat-context -n database exec -i $PRIMARY -- mongo --quiet"

CMD_MONGO_AUTH="kubectl --context kube-aws-k8s-uat-context -n database exec -i $PRIMARY -- mongo -u admin -p password --authenticationDatabase admin --quiet"

#Initiate replica set
INIT_RS(){
echo "initizate replica set"    
$CMD_MONGO_NOAUTH << EOF
    rs.initiate({
        _id: 'rs0',
        version: 1,
        members: [
            { _id: 0, host : 'mongo-0.mongod.database.svc.cluster.local:27017' },
            { _id: 1, host : 'mongo-1.mongod.database.svc.cluster.local:27017' },
            { _id: 2, host : 'mongo-2.mongod.database.svc.cluster.local:27017' }
        ]
    });
EOF
}

#Add a member to the replica set
#e.g. ADD_USER
ADD_USER(){
$CMD_MONGO_NOAUTH << EOF
    db.getSiblingDB("admin").createUser({
      user : "admin",
      pwd  : "password",
      roles: [ { role: "root", db: "admin" } ]
 });
EOF
}

#Add a member to the replica set
#e.g. ADD_NODE mongo-1.mongod.database.svc.cluster.local
ADD_NODE(){
$CMD_MONGO_AUTH << EOF
    rs.add({host: "$1:27017"});
EOF
}

#Re-configure replica set
RECONFIG_RS(){
echo "reconfig replica set"    
$CMD_MONGO_NOAUTH << EOF
    var cfg = rs.conf();
    cfg.members[0].host='mongo-0.mongod.database.svc.cluster.local:27017';
    cfg.members[1].host='mongo-1.mongod.database.svc.cluster.local:27017';
    cfg.members[2].host='mongo-2.mongod.database.svc.cluster.local:27017';

    rs.reconfig(cfg, {force : true});
EOF
}

