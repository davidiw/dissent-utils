#!/bin/bash
SUFFIX="Dissent-CS.SAFER.isi.deterlab.net"
CLIENT="client"
SERVER="server"
ON_SERVERS=1
SERVERS=24
CLIENTS=12
NODES=2
BASE_PATH="/local/logs/safetynet"
#BASE_PATH="/home/davidiw"
DISSENT_PATH="/users/davidiw/dissent"
DISSENT_BASE_PARAMS="--session_type=csbulk \
  --subgroup_policy=ManagedSubgroup \
  --auth_mode=null \
  --log=stderr"
BASE_PORT=33345
BASE_WEB_PORT=23345
RETURN=""

SERVER_MOD=$(expr $SERVERS / $ON_SERVERS)

which python &> /dev/null
if [[ $? -eq 0 ]]; then
  PYTHON="python"
else
  PYTHON="python2"
fi

ssh_exec()
{
  for (( m = 0 ; m < 5 ; m = m + 1 )); do
    result="$(ssh -f -o StrictHostKeyChecking=no -o HostbasedAuthentication=no -o CheckHostIP=no -o ConnectTimeout=10 -o ServerAliveInterval=30 -o BatchMode=yes -o UserKnownHostsFile=/dev/null $@ <&- 2>&1)"
    echo $result | grep Permanently &> /dev/null
    if [[ $? -eq 0 ]]; then
      return
    fi
    sleep 1
  done
  echo "Failed: "$result" for "$@
}

scp_exec()
{
  for (( m = 0 ; m < 5 ; m = m + 1 )); do
    result="$(scp -o StrictHostKeyChecking=no -o HostbasedAuthentication=no -o CheckHostIP=no -o ConnectTimeout=10 -o ServerAliveInterval=30 -o BatchMode=yes -o UserKnownHostsFile=/dev/null $@ <&- 2>&1)"
    echo $result | grep Permanently &> /dev/null
    if [[ $? -eq 0 ]]; then
      return
    fi
    sleep 1
  done
  echo "Failed: "$result" for "$@
}

logs()
{
  mkdir logs
  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    if [[ $(expr $i % $SERVER_MOD) -eq 0 ]]; then
      echo "$SERVER-$i"
      scp_exec "$SERVER-$i:/local/logs/safetynet/log.* logs/." &
    fi
  done
  scp_exec "$CLIENT-0-0:/local/logs/safetynet/log.* logs/." &
  wait
}

setup()
{
  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    echo "$SERVER-$i"
    ssh_exec $SERVER-$i "rm -rf $BASE_PATH; \
      mkdir -p $BASE_PATH; \
      cp $DISSENT_PATH/dissent $BASE_PATH/." &> /dev/null &
    for (( j = 0 ; j < $CLIENTS ; j = j + 1 )); do
      echo "$CLIENT-$i.$j"
      ssh_exec $CLIENT-$i-$j "rm -rf $BASE_PATH; \
        mkdir -p $BASE_PATH; \
        cp $DISSENT_PATH/dissent $BASE_PATH/." &> /dev/null &
    done
  done
  wait
}

gen_id()
{
  RETURN=$($PYTHON -c \
    "import hashlib, base64; \
    print base64.urlsafe_b64encode(hashlib.sha1('${@}').digest())" \
    )
}

start()
{
  rm $BASE_PATH/ids &> /dev/null

  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    if [[ $(expr $i % $SERVER_MOD) -eq 0 ]]; then
      gen_id $i
      id=$RETURN
      ip="10.255.0.$((1 + $i))"

      if [[ $i -eq 0 ]]; then
        DISSENT_BASE_PARAMS=$DISSENT_BASE_PARAMS" \
          --leader_id=$id"
        leader="tcp://$ip:$BASE_PORT"
      fi

      server=$ip:$BASE_PORT
      params=$DISSENT_BASE_PARAMS" \
        --local_id=$id \
        --super_peer \
        --endpoints=tcp://$server \
        --remote_peers=$leader \
        --web_server_url=http://127.0.0.1:$BASE_WEB_PORT \
        "

      echo "$SERVER-$i"
      echo "$SERVER$i,$ip:$BASE_PORT,$id" >> $BASE_PATH/ids
      ssh_exec $SERVER-$i.$SUFFIX "sudo bash -c 'ulimit -n 65536;
        cd $BASE_PATH;\
        ((./dissent $params &> log.$SERVER.$i)&)'" &
      if [[ $i -eq 0 ]]; then
        wait
      fi
    fi
  done
  wait

  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    if [[ $(expr $i % $SERVER_MOD) -eq 0 ]]; then
      gen_id $i
      id=$RETURN
      ip="10.255.0.$((1 + $i))"
      server=$ip:$BASE_PORT
    fi
    for (( j = 0 ; j < $CLIENTS ; j = j + 1 )); do
      client_line=""
      ip="10.0.$i.$((1 + $j))"

      for (( k = 0 ; k < $NODES ; k = k + 1 )); do
        gen_id $i.$j.$k
        id=$RETURN
        port=$(($BASE_PORT + $k))
        web_port=$(($BASE_WEB_PORT + $k))

        params=$DISSENT_BASE_PARAMS" \
          --local_id=$id \
          --endpoints=tcp://$ip:$port \
          --remote_peers=tcp://$server \
          --web_server_url=http://127.0.0.1:$web_port \
          "

        echo "$CLIENT$i.$j.$k,$ip:$port,$id" >> $BASE_PATH/ids
        if [[ $i -eq 0 && $k -eq 0 ]]; then
          client_line=$client_line" (($BASE_PATH/dissent $params &> $BASE_PATH/log.$CLIENT.$i.$j.$k)&);"
        else
          client_line=$client_line" (($BASE_PATH/dissent $params &> /dev/null)&);"
        fi
      done

      echo "$CLIENT-$i.$j"
      ssh_exec $CLIENT-$i-$j "$client_line" &
    done
    #wait
#    sleep 10
  done
  wait
}

stop()
{
  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    echo "$SERVER-$i"
    ssh_exec $SERVER-$i "sudo bash -c 'pkill -KILL dissent'" &
    for (( j = 0 ; j < $CLIENTS ; j = j + 1 )); do
      echo "$CLIENT-$i-$j"
      ssh_exec $CLIENT-$i-$j "sudo bash -c 'pkill -KILL dissent'" &
    done
  done
  wait
}

start_twitter()
{
  prefix="((python $HOME/dissent-utils/twitter/twitter_sender.py"
  prefix_recv="((python $HOME/dissent-utils/twitter/twitter_receiver.py"
  postfix="&> /local/logs/safetynet/twitter.out)&)"
  postfix_recv="/local/logs/safetynet/twitter.results \
    &> /local/logs/safetynet/twitter.recv.out)&)"
  dataset="$HOME/dissent-utils/twitter/dataset"
  idx=0
  
  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    if [[ $(expr $i % $SERVER_MOD) -eq 0 ]]; then
      web_port=$BASE_WEB_PORT
      ssh_exec $SERVER-$i.$SUFFIX "$prefix $web_port 5000 $idx $dataset $postfix" &

      if [[ $idx -eq 0 ]]; then
        ssh_exec $SERVER-$i.$SUFFIX "$prefix_recv $web_port $postfix_recv" &
      fi

      idx=$(($idx + 1))
    fi
    for (( j = 0 ; j < $CLIENTS ; j = j + 1 )); do
      for (( k = 0 ; k < $NODES ; k = k + 1 )); do
        web_port=$(($BASE_WEB_PORT + $k))
        ssh_exec $CLIENT-$i-$j "$prefix $web_port 5000 $idx $dataset $postfix" &
        idx=$(($idx + 1))
      done
    done
  done
  wait
}

stop_twitter()
{
  for (( i = 0 ; i < $SERVERS ; i = i + 1 )); do
    if [[ $(expr $i % $SERVER_MOD) -eq 0 ]]; then
      ssh_exec $SERVER-$i.$SUFFIX "pkill -f 'twitter_.+.py'" &
    fi
    for (( j = 0 ; j < $CLIENTS ; j = j + 1 )); do
      ssh_exec $CLIENT-$i-$j "pkill -f 'twitter_.+.py'" &
    done
  done
  wait
}

funct=$1
$funct ${@:2}
