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

#POSTGRES PART

yum list installed | grep -i "postgresql"
rtrnCd=$?

if [ $rtrnCd -ne 0 ]; then
    positive "Installing PostgreSQL"
    sudo yum -y install postgresql-server postgresql-contrib 
    rtrnCd_paranoia "$?" "Postgress server was successfully installed" "Postgress server was not installed"
    sudo postgresql-setup initdb
    rtrnCd_paranoia "$?" "Postgress setup init db was ok" "Postgress setup init db was failed"
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    sudo -su postgres psql -c "create user sonar;"
    sudo -su postgres psql -c "alter role sonar with createdb;"
    sudo -su postgres psql -c "alter user sonar with password 'sonar';"
    sudo -su postgres psql -c "\du"
    sudo -su postgres psql -c "create database sonar WITH ENCODING 'UTF8' owner sonar TEMPLATE=template0;"
    sudo -su postgres psql -c "grant all privileges on database sonar to sonar;"
    sudo -su postgres psql -c "\l"
    sudo sed -i '82s/ident/md5/' /var/lib/pgsql/data/pg_hba.conf
    #sudo sed -i '80s/peer/md5/' /var/lib/pgsql/data/pg_hba.conf
    sudo systemctl enable postgresql
    sudo systemctl restart postgresql 
else
    positive "Postgres database is already provisioned"
fi

if [ -a sonarqube-6.7.6.zip ]; then
    positive "Skipping SONAR step"
else
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-6.7.6.zip
    sudo yum -y install unzip
    sudo unzip sonarqube-6.7.6.zip -d /opt
    sudo mkdir -p /opt/sonarqube
    sudo mv /opt/sonarqube-6.7.6/* /opt/sonarqube
    
    positive "Creating group sonar"
    getent group sonar
    rtrnCd="$?"
    if [[ "$rtrnCd" -eq 0 ]]; then
        positive "Group sonar already exist. Skipping step"
    else
        positive "Creating group sonar"
        sudo groupadd sonar
        rtrnCd_paranoia "$?" "Group add was ok" "Group add failed"
    fi
    
    positive "Creating user sonar"
    id sonar
    rtrnCd="$?"
    if [[ "$rtrnCd" -eq 0 ]]; then
        positive "User sonar already exist. Skipping step"
    else
        positive "Creating user sonar"
        sudo useradd -M -s /bin/nologin -g sonar -d /opt/sonarqube/ sonar
        rtrnCd_paranoia "$?" "User sonar add was ok" "User add sonar failed"
    fi
    
    sudo chown -R sonar:sonar /opt/sonarqube/ 
    sudo sed -i 's:^#sonar.jdbc.username=:sonar.jdbc.username=sonar:' /opt/sonarqube/conf/sonar.properties;
    sudo sed -i 's:^#sonar.jdbc.password=:sonar.jdbc.password=sonar:' /opt/sonarqube/conf/sonar.properties;
    sudo sed -i 's/^#sonar.jdbc.url=jdbc:postgresql/sonar.jdbc.url=jdbc:postgresql/' /opt/sonarqube/conf/sonar.properties;
    sudo sed -i 's/^#sonar.web.port=9000/sonar.web.port=9000/' /opt/sonarqube/conf/sonar.properties;
    
    sudo touch /etc/systemd/system/sonar.service
    
    sudo sysctl -w vm.max_map_count=262144
    sudo sysctl -w fs.file-max=65536
    
    SONAR_CONFIG='
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=2048

[Install]
WantedBy=multi-user.target
'
    sudo echo "$SONAR_CONFIG" | sudo tee /etc/systemd/system/sonar.service
    sudo systemctl enable sonar
    sudo systemctl start sonar
    sudo systemctl status sonar
fi

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
upstream sonar {
  keepalive 32; # keepalive connections
  server 127.0.0.1:9000;
}

server {
  listen          80;       # Listen on port 80 for IPv4 requests

  server_name     sonar.example.com;

  #this is the jenkins web root directory (mentioned in the /etc/default/jenkins file)
  root            /opt/sonarqube/web/;

  ignore_invalid_headers off; #pass through headers from Jenkins which are considered invalid by Nginx server.

  location ~ "^/static/[0-9a-fA-F]{8}\/(.*)$" {
    #rewrite all static files into requests to the root
    #E.g /static/12345678/css/something.css will become /css/something.css
    rewrite "^/static/[0-9a-fA-F]{8}\/(.*)" /$1 last;
  }

  location /userContent {
    #have nginx handle all the static requests to the userContent folder files
    root /opt/sonarqube/web/;
    if (!-f $request_filename){
      #this file does not exist, might be a directory or a /**view** url
      rewrite (.*) /$1 last;
     break;
    }
    sendfile on;
  }

  location / {
      sendfile off;
      proxy_pass         http://sonar;
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

