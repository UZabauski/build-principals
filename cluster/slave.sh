sudo yum install -y java
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.191.b12-0.el7_5.x86_64" | sudo tee -a ~/.bash_profile
echo "export JRE_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.191.b12-0.el7_5.x86_64/jre" | sudo tee -a ~/.bash_profile
source ~/.bash_profile
