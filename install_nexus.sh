#!/bin/bash

#functions for nice looging
function positive() {
    echo "+[$(date +'%Y-%m-%d:%H:%M:%S%z')]: $1 "
}

function err() {     
    echo "-[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $1 " >&2
}

# function for checking error codes
function rtrnCd_paranoia () {
rtrnCd="$1"
    if [[ $rtrnCd -eq 0 ]]; then
        positive "$2"
    else
        err "$3"
        exit 1
    fi
}
#JAVA PART
JAVA_DOWNLOAD_LINK="https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html"

#checking for installed java
java -version

rtrnCd="$?"

if [[ "$rtrnCd" -eq 0 ]]; then
    positive "Java is already instaled on box. Java version info is above"
else
    java_download="$(curl --silent $JAVA_DOWNLOAD_LINK | grep 'linux-x64.rpm' | sort -u | grep --extended-regexp --only-matching '(http|https)://[a-zA-Z0-9./?=_-]*' | tail -1)"
    if [ -z "$java_download" ]; then
        err "java download link is corrupted, please manually recheck it, Oracle changed the website - $JAVA_DOWNLOAD_LINK"
        exit 1
    fi
    positive "java_download link is - $java_download"
    java_download_filename="$(basename $java_download)"
    positive "java download filename - $java_download_filename"
    java_local_filename="$(find ./ -type f -name 'jdk*linux*rpm' -printf "%f\n")" 
    if [ "$java_download_filename" == "$java_local_filename" ]; then
        positive "Latest java already downloaded - $java_local_filename"
    else
        curl -L --header 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:62.0) Gecko/20100101 Firefox/62.0' --cookie "oraclelicense=accept-securebackup-cookie" --remote-name "$java_download"
        rtrnCd_paranoia "$?" "Dowloading of jdk from $java_download was successfull" "Dowloading of jdk from $java_download was unsuccessfull"
    fi
    sudo rpm --upgrade --verbose --hash "$java_download_filename"
    rtrnCd_paranoia "$?" "Installation of jdk from $java_download_filename was successfull" "Intalation of jdk from $java_download was unsuccessfull"    
fi 

#NEXUS PART

if [ -a nexus-3.14.0-04-unix.tar.gz ]; then
    positive "Skipping nexus step"
else
    wget https://sonatype-download.global.ssl.fastly.net/repository/repositoryManager/3/nexus-3.14.0-04-unix.tar.gz
    sudo tar -xvzf nexus-3.14.0-04-unix.tar.gz
    sudo mv nexus-3.14.0-04/ /opt/
    sudo mv /opt/nexus-3.14.0-04 /opt/nexus
    sudo mv sonatype-work/ /opt/
    positive "Creating group nexus"
    getent group nexus
    rtrnCd="$?"
    if [[ "$rtrnCd" -eq 0 ]]; then
        positive "Group nexus already exist. Skipping step"
    else
        positive "Creating group nexus"
        sudo groupadd nexus
        rtrnCd_paranoia "$?" "Group add was ok" "Group add failed"
    fi
    
    positive "Creating user nexus"
    id nexus
    rtrnCd="$?"
    if [[ "$rtrnCd" -eq 0 ]]; then
        positive "User nexus already exist. Skipping step"
    else
        positive "Creating user nexus"
        sudo useradd -M -s /bin/nologin -g nexus -d /opt/nexusqube/ nexus
        rtrnCd_paranoia "$?" "User nexus add was ok" "User add nexus failed"
    fi
    
    sudo chown -R nexus:nexus /opt/nexus/ 
    sudo chown -R nexus:nexus /opt/sonatype-work/

    sudo touch /etc/systemd/system/nexus.service
    
    sudo sysctl -w vm.max_map_count=262144
    sudo sysctl -w fs.file-max=65536
    
    nexus_CONFIG='
[Unit]
Description=nexus service
After=network.target
  
[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort
  
[Install]
WantedBy=multi-user.target'

    sudo echo "$nexus_CONFIG" | sudo tee /etc/systemd/system/nexus.service
    sudo systemctl daemon-reload
    sudo systemctl enable nexus.service
    sudo systemctl start nexus.service
fi 

#NGINX
positive "Creating group nginx"
getent group nginx
rtrnCd="$?"
if [[ "$rtrnCd" -eq 0 ]]; then
positive "Group nginx already exist. Skipping step"
else
    positive "Creating group nginx"
    sudo groupadd nginx
    rtrnCd_paranoia "$?" "Group add was ok" "Group add failed"
fi

positive "Creating user nginx"
id nginx
rtrnCd="$?"
if [[ "$rtrnCd" -eq 0 ]]; then
    positive "User nginx already exist. Skipping step"
else
    positive "Creating user nginx"
    sudo useradd -M -s /bin/nologin -g nginx -d /home/nginx nginx
    rtrnCd_paranoia "$?" "User nginx add was ok" "User add nginx failed"
fi

yum list installed | grep -i nginx
rtrnCd=$?
if [ $rtrnCd -ne 0 ]; then  
    positive "Installing nginx"
    sudo yum -y install epel-release
    positive "Add nginx user and group"
    rtrnCd_paranoia "$?" "nginx repo was added" "failed on nginx repo addition"
    sudo yum -y install nginx
    rtrnCd_paranoia "$?" "nginx was installed" "nginx installation failed"
fi 

NGINX_CONF='user nginx;
worker_processes  5;

events {
  worker_connections  1024;
}
http {
  
  proxy_send_timeout 120;
  proxy_read_timeout 300;
  proxy_buffering    off;
  keepalive_timeout  5 5;
  tcp_nodelay        on;
  
  server {
    listen   *:80;
    server_name  www.example.com;
  
    # allow large uploads of files
    client_max_body_size 1G;
  
    # optimize downloading files larger than 1G
    #proxy_max_temp_file_size 2G;
  
    location / {
      # Use IPv4 upstream address instead of DNS name to avoid attempts by nginx to use IPv6 DNS lookup
      proxy_pass http://127.0.0.1:8081/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  }
}'

sudo echo "$NGINX_CONF" | sudo tee /etc/nginx/nginx.conf

sudo systemctl daemon-reload
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx

