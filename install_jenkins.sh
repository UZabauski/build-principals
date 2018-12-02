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

#JENKINS PART
JENKINS_LINK="http://mirrors.jenkins.io/war-stable/latest/jenkins.war"
JENKINS_HOME="/opt/jenkins"

positive "Creating group jenkins"
getent group jenkins
rtrnCd="$?"
if [[ "$rtrnCd" -eq 0 ]]; then
    positive "Group jenkins already exist. Skipping step"
else
    positive "Creating group jenkins"
    sudo groupadd jenkins
    rtrnCd_paranoia "$?" "Group add was ok" "Group add failed"
fi

positive "Creating user jenkins"
id jenkins
rtrnCd="$?"
if [[ "$rtrnCd" -eq 0 ]]; then
    positive "User jenkins already exist. Skipping step"
else
    positive "Creating user jenkins"
    sudo useradd -M -s /bin/nologin -g jenkins -d "$JENKINS_HOME" jenkins
    rtrnCd_paranoia "$?" "User jenkins add was ok" "User add jenkins failed"
fi

positive "Creating /opt/jenkins folder"
sudo mkdir -p "$JENKINS_HOME"
rtrnCd_paranoia "$?" "Creating /opt/jenkins folder was OK" "Creating /opt/jenkins folder failed" 

positive "Downloading jenkins war"
ls -1 ./jenkins.war 
rtrnCd="$?"
if [[ "$rtrnCd" -eq 0 ]]; then
    positive "Jenkins war is already exist. Skipping step"
else
    positive "Downloading jenkins by $JENKINS_LINK"
    curl -L --remote-name "$JENKINS_LINK"
    rtrnCd_paranoia "$?" "Downloading jenkins was OK" "Downoloading jenkins failed" 
fi

sudo cp jenkins.war "$JENKINS_HOME"
rtrnCd_paranoia "$?" "Moving jenkins.war was OK" "Moving jenkins.war failed"

sudo chown -R jenkins:jenkins "$JENKINS_HOME"
sudo touch /etc/systemd/system/jenkins.service

JENKINS_SERVICE_OPTIONS="
[Unit]
Description=Jenkins Service
After=network.target

[Service]
Type=simple
User=jenkins

WorkingDirectory=$JENKINS_HOME
ExecStart=/usr/java/jdk1.8.0_192-amd64/jre/bin/java -Xms1500M -Xmx3000M -jar $JENKINS_HOME/jenkins.war
ExecStop=/bin/kill -15 $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
"
sudo echo "$JENKINS_SERVICE_OPTIONS" | sudo tee /etc/systemd/system/jenkins.service

sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo systemctl status jenkins

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
upstream jenkins {
  keepalive 32; # keepalive connections
  server 127.0.0.1:8080; # jenkins ip and port
}

server {
  listen          80;       # Listen on port 80 for IPv4 requests

  server_name     jenkins.example.com;

  #this is the jenkins web root directory (mentioned in the /etc/default/jenkins file)
  root            /opt/jenkins/.jenkins/war/;

  ignore_invalid_headers off; #pass through headers from Jenkins which are considered invalid by Nginx server.

  location ~ "^/static/[0-9a-fA-F]{8}\/(.*)$" {
    #rewrite all static files into requests to the root
    #E.g /static/12345678/css/something.css will become /css/something.css
    rewrite "^/static/[0-9a-fA-F]{8}\/(.*)" /$1 last;
  }

  location /userContent {
    #have nginx handle all the static requests to the userContent folder files
    #note : This is the $JENKINS_HOME dir
	root /var/lib/jenkins/;
    if (!-f $request_filename){
      #this file does not exist, might be a directory or a /**view** url
      rewrite (.*) /$1 last;
	  break;
    }
	sendfile on;
  }

  location / {
      sendfile off;
      proxy_pass         http://jenkins;
      proxy_redirect     default;
      proxy_http_version 1.1;

      proxy_set_header   Host              $host;
      proxy_set_header   X-Real-IP         $remote_addr;
      proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto $scheme;
      proxy_max_temp_file_size 0;

      #this is the maximum upload size
      client_max_body_size       10m;
      client_body_buffer_size    128k;

      proxy_connect_timeout      90;
      proxy_send_timeout         90;
      proxy_read_timeout         90;
      proxy_buffering            off;
      proxy_request_buffering    off; # Required for HTTP CLI commands in Jenkins > 2.54
      proxy_set_header Connection ""; # Clear for keepalive
    } 
   }
}'

sudo echo "$NGINX_CONF" | sudo tee /etc/nginx/nginx.conf

sudo systemctl daemon-reload
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx

