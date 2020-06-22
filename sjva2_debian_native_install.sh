# made by jassmusic @20.06.22

echo "-- SJVA2 Install for Ubuntu Linux Native"
echo "   from nVidia Shield Cafe --"
echo ""

#echo " - Killing filebrowser process"
#pgrep -a filebrowser | awk '{ print $1 }' | xargs kill -9 >/dev/null 2>&1
#sleep 1
#echo " done"
#echo ""

echo "(Step1) dns setting.."
rm -f /etc/resolv.conf
cat >> /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
echo " done"
echo ""

echo "(Step2) Essential package setting.."
apt -y update && apt -y upgrade
apt -y install dialog apt-utils vim curl busybox
apt-get install tzdata locales
dpkg-reconfigure tzdata
dpkg-reconfigure locales
echo " done"
echo ""

echo "(Step3) Build Package setting.."
apt -y install python python-pip python-dev git libffi-dev libxml2-dev libxslt-dev zlib1g-dev
# Ubuntu
#apt -y install libjpeg62-dev
# Debian
apt -y install libjpeg62-turbo-dev
echo " done"
echo ""

#echo "(Optional) Java setting.."
# Ubuntu
#apt -y install openjdk-8-jdk
# Debian
#apt-get install default-jdk
#echo " done"
#echo ""

#echo "(Optional) Rclone setting.."
#curl https://rclone.org/install.sh | bash
#echo " done"
#echo ""

#echo "(Optional) filebrowser setting.."
#curl -fsSL https://filebrowser.xyz/get.sh | bash
#echo " done"
#echo ""

echo "(Step4) ffmpeg setting.."
apt -y install ffmpeg
echo " done"
echo ""

echo "(Step5) redis-server setting.."
apt -y install redis
echo " done"
echo ""

echo "(Step6) vnstat setting.."
apt -y install vnstat net-tools
echo " done"
echo ""

echo "(Step7) SJVA2 Downloading.." 
cd /home
git clone https://github.com/soju6jan/SJVA2.git
echo " done"
echo ""

echo "(Step8) SJVA2 pip setting.."
cd SJVA2
python -m pip install --upgrade pip
pip install --upgrade setuptools
pip install -r requirements.txt
echo " done"
echo ""

echo "(Step9) Running file modify.."
rm -f my_start.sh
cat >> my_start.sh << 'EOM'
#!/bin/bash

if [ ! -f "export.sh" ] ; then
cat <<EOF >export.sh
#!/bin/sh
export REDIS_PORT="46379"
export USE_CELERY="true"
export CELERY_WORKER_COUNT="2"
export RUN_FILEBROWSER="true"
export FILEBROWSER_PORT="9998"
export OS_PREFIX="Linux"
EOF
fi

if [ -f "export.sh" ] ; then
    echo "Run export.sh start"
    chmod 777 export.sh
    source export.sh
    echo "Run export.sh end"
fi

if [ -f "pre_start.sh" ] ; then
    echo "Run pre_start.sh start"
    chmod 777 pre_start.sh
    source pre_start.sh
    echo "Run pre_start.sh end"
fi

if [ "${USE_CELERY}" == "true" ] ; then
    nohup redis-server --port ${REDIS_PORT} &
    echo "Start redis-server port:${REDIS_PORT}"
fi

if [ "${RUN_FILEBROWSER}" == "true" ]; then
    chmod +x ./bin/${OS_PREFIX}/filebrowser
    nohup ./bin/${OS_PREFIX}/filebrowser -a 0.0.0.0 -p ${FILEBROWSER_PORT} -r / -d ./data/db/filebrowser.db &
    echo "Start Filebrowser. port:${FILEBROWSER_PORT}"
fi

COUNT=0
while [ 1 ];
do
    find . -name "index.lock" -exec rm -f {} \;
    git reset --hard HEAD
    git pull
    chmod 777 .
    chmod -R 777 ./bin

    if [ ! -f "./data/db/sjva.db" ] ; then
        python -OO sjva.py 0 ${COUNT} init_db
    fi

    if [ "${USE_CELERY}" == "true" ] ; then
        sh worker_start.sh &
        echo "Run celery-worker.sh"
        python -OO sjva.py 0 ${COUNT}
    else
        python -OO sjva.py 0 ${COUNT} no_celery
    fi
    
    RESULT=$?
    echo "PYTHON EXIT CODE : ${RESULT}.............."
    if [ "$RESULT" = "0" ]; then
        echo 'FINISH....'
        break
    else
        echo 'REPEAT....'
    fi 
    COUNT=`expr $COUNT + 1`
done 

if [ "${RUN_FILEBROWSER}" == "true" ]; then
    ps -eo pid,args | grep filebrowser | grep -v grep | awk '{print $1}' | xargs -r kill -9
fi
EOM
chmod 777 my_start.sh
echo " done"

echo "(Step10) Register SJVA2 to system service.."
rm -f /etc/init.d/sjva2
cat >> /etc/init.d/sjva2 << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides: skeleton
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Example initscript
# Description: This file should be used to construct scripts to be
# placed in /etc/init.d.
# Modified by jassmusic
### END INIT INFO
sjva2_running=`pgrep -a my_start | awk '{ print $1 }'`
python_running=`pgrep -a python | grep sjva.py | awk '{ print $1 }'`
celery_running=`pgrep -a python | grep celery | awk '{ print $1 }'`
redis_running=`pgrep -a redis-server | awk '{ print $1 }'`
#filebrowser_running=`pgrep -a filebrowser | awk '{ print $1 }'`
case "$1" in
start)
if [ -z "$sjva2_running" ] || [ -z "$python_running" ]; then
echo -n "Starting sjva2: "
cd /home/SJVA2
su -c "nohup ./my_start.sh &" >/dev/null 2>&1
sleep 1
echo "done"
else
echo "sjva2 already running"
exit 0
fi
;;
stop)
if [ -z "$sjva2_running" ] || [ -z "$python_running" ] ; then
echo -n "Checking sjva2: "
"sjva2_running" | xargs kill -9 >/dev/null 2>&1
"python_running" | xargs kill -9 >/dev/null 2>&1
"celery_running" | xargs kill -9 >/dev/null 2>&1
"redis_running" | xargs kill -9 >/dev/null 2>&1
#"filebrowser_running" | xargs kill -9 >/dev/null 2>&1
sleep 1
echo "done"
echo "sjva2 is not running (no process found)..."
exit 0
fi
echo -n "Killing sjva2: "
"sjva2_running" | xargs kill -9 >/dev/null 2>&1
"python_running" | xargs kill -9 >/dev/null 2>&1
"celery_running" | xargs kill -9 >/dev/null 2>&1
"redis_running" | xargs kill -9 >/dev/null 2>&1
#"filebrowser_running" | xargs kill -9 >/dev/null 2>&1
sleep 1
echo "done"
;;
restart)
sh $0 stop
sh $0 start
;;
status)
if [ -z "$sjva2_running" ] && [ -z "$python_running" ]; then
echo "It seems that sjva isn't running (no process found)."
else
echo "sjva2 process running."
fi
;;
*)
echo "Usage: $0 {start|stop|restart|status}"
exit 1
;;
esac
exit 0
EOF
chmod +x /etc/init.d/sjva2
update-rc.d sjva2 defaults
cd /home/SJVA2
echo " done"
echo " : From now you can access as below,"
echo " : service sjva2 start"
echo " : service sjva2 stop"
echo " : service sjva2 restart"
echo " : service sjva2 status"
echo ""
echo "SJVA2 Installed finish."
echo "enjoy!"
echo ""
echo "※ Need To 1st Check ※"
echo " Run './my_start.sh' and check the SJVA2 running "
echo " - if you have an error of lxml,"
echo "   please try again as below"
echo "   'CFLAGS="-O0" pip install lxml==4.3.3'"
echo " - if you can't access 9997 port,"
echo "   check the celery version downgrade as below"
echo "   'pip install celery==3.1.15'"
echo " - if you want to use vnstat,"
echo "   check net-name of 'ifconfig'"
echo "   'vnstat -u -i net-name'"
echo "   'service vnstat start'"
echo ""