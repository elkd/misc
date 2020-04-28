#!/bin/bash
#
#Using ps to monitor cpu of celery and kill it when enters dead loop of CPU consumption

#Can enter multiple strings but there should be no space on that string
PROCESS_TOCHECK='celery'

#Write the command in celery_worker without its arguments
COMMAND='/home/ec2-user/sd/sd/celery_worker.py'  

#Need to install mailx or similar linux package
EMAIL=""

#max cpu % load
MAX_CPU=90

#For how long should the process be tolerated to spend MAX_CPU before being restarted
#Do you know how long your normal tasks take? It should be *3 of that maybe?
MAX_SECONDS=10

#How often should the CPU usage be checked
#The number depends on the MAX_SECONDS maybe MAX_SECONDS/10?
#If so then CPU will be checked 10 times, if average > MAX_CPU; restart
SLEEP_INTERVAL=5

ROUNDS=`echo $MAX_SECONDS/$SLEEP_INTERVAL|bc -l`
ROUNDS=${ROUNDS%%[.,]*}

if ! [[ "$ROUNDS" =~ ^[0-9]+$ ]]
then
	echo "Sorry the value of MAX_SECONDS/SLEEP_INTERVAL is not an integer"
 	echo "The MAX_SECONDS/SLEEP_INTERVAL value is: $ROUNDS"	
	echo "The celery-cpu-watch.sh script will exit"
	exit 1
fi

[[ -z "$PROCESS_TOCHECK" ]] && { echo "The process to monitor is not specified, script will exit" ; exit 1; }
[[ -z "$COMMAND" ]] && { echo "The start command to monitor is not specified, script will exit" ; exit 1; }

#colors
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
NC=`tput sgr0` # No Color

#restarting or just testing?
if [ "$1" = "restart" ]; then
    RESTART=1
    echo "${RED}Process execute in 'restart' mode.${NC}"
else
    RESTART=0
    echo "Process execute in '${YELLOW}dry${NC}' mode (no kill)."
fi

#process Sort by
SORTBY=9

if [ "$2" = "always" ]; then
    LOOP=true
    echo "${RED}This process will always run unless it is stopped explicitly.${NC}"
fi

while $LOOP;
do
    echo ""
    echo "Check ${YELLOW}$PROCESS_TOCHECK${NC} process..."

    #CEL_CONTAINER_ID=$(sudo docker ps -aqf "name=celery")
    #PID=$(docker top CEL_CONTAINER_ID -eo pid,pcpu,cmd --sort -pcpu | grep $PROCESS_TOCHECK | head -n 1 | awk '{print $1}')

    PID=$(ps -eo pid,pcpu,command --sort -pcpu | grep $PROCESS_TOCHECK | head -n 1 | awk '{print $1}')

    if [ -z "$PID" ]; then
      echo "${GREEN}There isn't any matched process for $PROCESS_TOCHECK${NC}"
      continue
    fi

    #Fetch other process stats by pid
    #% CPU
    #CPU=$(top -p $PID -bcSH -n 1 | grep $PROCESS_TOCHECK | sort -k $SORTBY -r | head -n 1 | awk '{print $9}')
    CPU=$(ps -eo pid,pcpu,command --sort -pcpu | grep $PROCESS_TOCHECK | head -n 1 | awk '{print $2}')

    #format integer cpu
    CPU=${CPU%%[.,]*}

    #full process command
    P_COMMAND=$(ps -eo pid,pcpu,command --sort -pcpu | grep $PROCESS_TOCHECK | head -n 1 | awk '{print $4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15}')
    
    
    #check if need to restart process
    if [[ "$P_COMMAND" == *"$COMMAND"* ]] && [ $CPU -gt $MAX_CPU ];
    then
          #process summary
          echo "${YELLOW} $PROCESS_TOCHECK current usage information is:${NC}"

          echo "PID:$PID"
          echo "COMMAND:$P_COMMAND"
          echo "CPU:$CPU"

          CPU_SUM=0
          calc(){ awk "BEGIN { print $* }"; }

          for (( i=0; i<$ROUNDS; ++i));
          do
              CPU=$(ps -eo pid,pcpu,command --sort -pcpu | grep $PROCESS_TOCHECK | head -n 1 | awk '{print $2}')
              
              CPU=${CPU%%[.,]*}
              CPU_SUM=$(( $CPU_SUM + $CPU ))

              echo "${YELLOW} $PROCESS_TOCHECK current %CPU usage is: $CPU ${NC}"
              echo "${RED}The script is sleeping for $SLEEP_INTERVAL seconds...${NC}"
              sleep $SLEEP_INTERVAL
          done  
          
          AVERAGE_CPU=`echo $CPU_SUM/$ROUNDS|bc -l`

          AVERAGE_CPU=${AVERAGE_CPU%%[.,]*}

          if [ $AVERAGE_CPU -gt $MAX_CPU ];
          then
              echo "Process $PROCESS_TOCHECK has reached ${AVERAGE_CPU}% CPU usage for $MAX_SECONDS seconds it will be restarted" 
           
              if [ "$RESTART" = "1" ];
              then
                  echo "${RED}Politely restarting this process  $PID${NC}"
                  #kill -15 $PID
                  kill -HUP $PID
                  #sleep 3
                  #echo "Forcefully stopping the process $PID"
                  #echo "kill zombies"
                  #kill -HUP $(ps -A -ostat,ppid | grep -e '[zZ]'| awk '{ print $2 }')
                  
                  if [ ! -z $EMAIL ]; then
                      echo "Send Mail to $EMAIL"
                      #mail -s "SERVER: Process $PROCESS_TOCHECK reached ${CPU}% for $MAX_SECONDS Seconds. It was restarted." $EMAIL < .
                  fi

              else
                  echo "The script is in dry mode! The process $PROCESS_TOCHECK won't be killed"
              fi
              
              if [ "$2" = "always" ]; then
                  sleep $SLEEP_INTERVAL
              else
                  LOOP=false
              fi
         fi

    else      
	
	if [[ "$P_COMMAND" == *"$COMMAND"* ]];  then
	    echo "${GREEN}The script identified $PROCESS_TOCHECK process running as $P_COMMAND"
	    echo "Its CPU usage is $CPU , status: OK! ${NC}"
	else
	    echo "${GREEN} The $PROCESS_TOCHECK process running as $COMMAND wasn't found ${NC}"
	fi

        if [ "$2" = "always" ]; then
            sleep $SLEEP_INTERVAL
        else
            LOOP=false
        fi
    fi

done
