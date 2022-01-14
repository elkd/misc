#!/bin/bash -xe
# These are the list of commands on how to deploy a web app on a fresh Ubuntu 18/20 OS running on AWS.
# Some command requires raw password input and they can't be automated
# Examples are creating linux user, and github keys. In such cases raw values can be passed when script is started by someone
# Or sudo vim /etc/redis/redis.conf #Then change line 147 from 'supervised no' to 'supervised systemd' On old Ubuntu versions
# Also check for safe ways to inject .env in the middle of this script

#It is possible to store all passwords in a separate script that will echo them when runnning specific commands.
#https://serverfault.com/questions/815043/how-to-give-username-password-to-git-clone-in-a-script-but-not-store-credential

#ALSO NGINX GUNICORN FILES NEEDS SOME UPDATES BEFORE CALLING THIS SCRIPT  

# CALL IT LIKE THIS: bash deploy.sh github-token user-or-org-name repo-name domain-name-without-TLD TLD

#Assume it is started on the misc file
cd ~/

sudo apt-get -y update

echo 'alias python="python3"' >> ~/.bashrc
source ~/.bashrc

sudo apt install python3-venv gcc python3-pip python3-dev libpq-dev python3-wheel gettext nginx curl postgresql postgresql-contrib -y


sudo update-alternatives --set editor /usr/bin/vim.basic
#Beware of the space btn file name and -q to mean quiet
#Make sure the key is created as id_rsa the default name
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N "" -C "$1"

eval "$(ssh-agent -s)"
ssh-add -k ~/.ssh/id_rsa

RSA_KEY=$(cat ~/.ssh/id_rsa.pub)

#More https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token

#Sometimes pasting these lines to other editors destroy the spacing encoding and the bash will fail to parse spaces
curl -H "Authorization: token $1" --data '{"title":"EC2-instance-'"$3"'-ID'"$RANDOM"'","key":"'"$RSA_KEY"'"}' https://api.github.com/user/keys

git clone --depth 1 git@github.com:$2/$3.git

#Create them here so that they are out of git VCS
mkdir ./logs ./run ./.pip
cp ~/misc/pip.conf ~/.pip/pip.conf

chmod 764 -R ./logs ./run ./.pip

touch ./logs/gunicorn-access.log ./logs/gunicorn-error.log ./logs/nginx-access.log ./logs/nginx-error.log ./logs/celery-access.log ./logs/celery-error.log
mkdir ./run/gunicorn ./run/celery

cd $3

mkdir staticfiles

python3 -m venv .venv && source .venv/bin/activate

#It is not a guarantee that this process will pass smoothly
#Always when there is a failure update the req files and rerun the command.
pip install --upgrade pip wheel setuptools gunicorn[gevent] psycogreen requests django-db-geventpool
pip install -r requirements.txt --retries 20 --timeout 300

sudo cp ~/misc/gunicorn.socket /etc/systemd/system
sudo cp ~/misc/gunicorn.service /etc/systemd/system

sudo systemctl start gunicorn.socket
sudo systemctl enable gunicorn.socket
sudo cp ~/misc/nginx.conf /etc/nginx/sites-available/$4

#MUST open this file and update the server_name with IP addresses
sudo ln -s /etc/nginx/sites-available/$4 /etc/nginx/sites-enabled
sudo nginx -t && sudo systemctl restart nginx

sudo ufw allow 'Nginx Full'
sudo ufw allow 22
#sudo ufw enable -y


# ================================= SECRETS =================================
# This step onwards needs the env variables loaded
#vim .env #Add all the settings parameters.

#THE SERVERS SHARE DB AND S3 STORAGE THIS SHOULDN'T BE RUN ON EVERY SERVER
#python manage.py migrate

#python manage.py collectstatic --noinput
# ================================= SECRETS =================================
echo "DONE INSTALLING!"

#These steps aren't used when you don't need HTTPS certificate
sudo apt-get update
sudo apt-get install python3-certbot-nginx -y
sudo certbot --noninteractive --agree-tos -d $4.$5 -d www.$4.$5 --register-unsafely-without-email --nginx

#RENEWING CERTS SHOULD BE AUTOMATICALLY, INCASE OF ISSUES RUN THESE;
#sudo systemctl status certbot.timer
#sudo certbot renew --dry-run
# TO MANUALLY RENEW: sudo certbot renew

#If you want to change the IP of the server to a static one for quick provision
#then you have to logout the ssh mode before performing the next step.
#only after having the right IP for domain.com the following can be valid
#When the IP of instance is changed reset the ssh by 
#ssh-keygen -R <the-ip-address> 
#sudo certbot --nginx  #interactive step

echo "DONE SUCCESSFULLY!"


#DONE!
#In case of errors check below commands 
#sudo systemctl status <service-name.service>
#journalctl -u <service-name.service>
#sudo systemctl daemon-reload
#sudo systemctl restart gunicorn.service
#-------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------



#To copy data from one db instance to another.
#pg_dump -C -h localhost -U user -P db_name | psql -h remote-psql-host -U password local_db

#If you want to create a separate Linux User
#sudo useradd -m -p "$(python -c "import crypt; print crypt.crypt(\"REPLACE-WITH-RAW-PS\", \"\$6\$$(</dev/urandom tr -dc 'a-zA-Z0-9' | head -c 32)\$\")")" -s /bin/bash user
#sudo gpasswd -a user sudo
#sudo su - postres-user
