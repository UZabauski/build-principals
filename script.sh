sudo yum install -y java
wget https://pkg.jenkins.io/redhat-stable/jenkins-2.138.3-1.1.noarch.rpm
sudo rpm -i jenkins-2.138.3-1.1.noarch.rpm
sudo systemctl start jenkins
