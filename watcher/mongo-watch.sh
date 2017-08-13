#!/usr/bin/env bash
set -ex

NAME_POD=${MONGO_POD_NAME:=mongo}
NAME_PORT=${MONGO_PORT:=mongo}
NAME_RS=${MONGO_RS_NAME:=rs0}

CMD_MONGO='mongo --quiet'
CMD_KUBE='kubectl --context kube-aws-k8s-uat-context' 

isMongoReady=0
isRsInited=0
isScaled=0
continue=1

#### FUNC
CHECK_INIT_RS(){
    data=`$CMD_KUBE -n database get pod -l "app=$NAME_POD,replicaset=$NAME_RS" \
                -o jsonpath='{.items..metadata.name}'`            
    members=($data)

    if [[ -z $members ]]; then
        echo 0
    else  
        echo ${#members[@]}
    fi
}

CHECK_DEFAULT_RS_STATUS(){
    echo "Checking default replicate set status"

    #Assume 0, 1, 2 take majority of the RS
    ready=0
    members=(0 1 2)
    for i in "${members[@]}"
    do
        status=`CHECK_MONGO_STATUS $NAME_POD-$i`
        if [[ "$status" -eq 0 ]]; then
            ((ready++))
            status=`CHECK_RS_STATUS $NAME_POD-$i`
            if [[ $status -eq 0 ]]; then 
                isRsInited=1
                break
            fi
        fi    
    done
    echo "default replicate set is not initilizaed"
    if [[ ready -eq 3 ]]; then
        CONFIG_INIT_RS
    else
        continue=0
    fi    
}

CONFIG_INIT_RS(){
    echo "initizate replicate set"

    RUN_MONGO_CMD $NAME_POD-0 'rs.initiate()'
	RUN_MONGO_CMD $NAME_POD-0 "var cfg = rs.conf();cfg.members[0].host='$NAME_POD-0:27017';rs.reconfig(cfg)"
	RUN_MONGO_CMD $NAME_POD-0 "rs.add('$NAME_POD-1:27017')"
	RUN_MONGO_CMD $NAME_POD-0 "rs.add('$NAME_POD-2:27017')"
	
    sleep 5

	members=`RUN_MONGO_CMD $NAME_POD-0 'rs.status().members.length'`
	if [[ "$members" -eq 3 ]]; then
		echo "Replica set configured successfully."
		isRsInited=1
		echo 0
	else
		echo "Replica set not fully configured."
		echo 1
	fi
}

SCALE_REPLICA_SET(){
    #Assume 0, 1, 2 take majority of the RS
    members=(0 1 2)
    primary=-1
    for i in "${members[@]}"
    do
        isMaster=`RUN_MONGO_CMD $NAME_POD-$i 'db.isMaster().ismaster'`
        if [[ "$isMaster" == "true" ]]; then
            primary=i
            break
        fi    
    done

    if [[ "$primary" -lt 0 ]]; then
        echo 'no primary found in the replica set in nodes [0, 1, 2]'
        isScaled=1
    else
        members=`RUN_MONGO_CMD $NAME_POD-$primary 'rs.status().members.length'`
		new_member="$NAME_POD-$members"

		status=`CHECK_MONGO_STATUS $new_member`
        if [[ "$status" -eq 0 ]]; then
            status=`CHECK_RS_STATUS $new_member`
            if [[ "$status" -eq 0 ]]; then
                echo "Adding $new_member to the replica set."
                RUN_MONGO_CMD $new_member "rs.add('$new_member:27017')"
            fi 
        fi   
    fi
}

RUN_MONGO_CMD(){
    $CMD_KUBE -n database exec -it $1 -- $CMD_MONGO --eval $2 
}

CHECK_MONGO_STATUS(){
    alive=`RUN_MONGO_CMD $1 'db.isMaster().ok'`
        
    if [[ "$alive" == "1" ]]; then 
        echo 0
    else 
        echo 1
    fi
}

CHECK_RS_STATUS(){
	echo "Checking replicate set status"
	isMaster=`RUN_MONGO_CMD $1 'db.isMaster().ismaster'`
	isSecondary=`RUN_MONGO_CMD $1 'db.isMaster().secondary'`
	if [[ "$isMaster" == "false" ]] && [[ "$isSecondary" == "false" ]]; then
        echo "$1 is not yet initilizaed" 
        echo 1
    else
        echo "$1 is initilizaed" 
        echo 0   
    fi
}

#### MAIN LOGIC
echo "Check RS init status..."
members=$(CHECK_INIT_RS)

if [[ $members -lt 3 ]]; then
    exit 0
fi    

echo "Searching for initial replica set..."
while [[ "$continue" -eq 1 ]] && [[ "$isRsInited" -eq 0 ]]
do
	CHECK_DEFAULT_RS_STATUS
	
    echo "Still inside config loop"
	sleep 5
done

echo "Monitoring MongoDB replica set to scale..."
while  [[ "$continue" -eq 1 ]] && [[ $isScaled -eq 0 ]]
do
	SCALE_REPLICA_SET

	echo "Still inside scaling loop"
	sleep 5
done

