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
#JENKINS_LINK="http://mirrors.jenkins.io/war-stable/latest/jenkins.war"
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
    sudo useradd -M -s /bin/bash -g jenkins -d "$JENKINS_HOME" jenkins
    rtrnCd_paranoia "$?" "User jenkins add was ok" "User add jenkins failed"
fi

positive "Creating /opt/jenkins folder"
sudo mkdir -p "$JENKINS_HOME"
rtrnCd_paranoia "$?" "Creating /opt/jenkins folder was OK" "Creating /opt/jenkins folder failed" 

