# Misc

Misc contains the simplest scripts to deploy Simple Python Web Servers on Linux servers. This is best for projects that tools like Docker, Terraform, Chef, Ansible look overkill.

Note that these simple scripts don't manage any secret files. The scripts assume the secret files are stored somewhere unknown and they should be added to the server by other automation tools or manually. 

Adding secret files manually is just okay for a 1-time installation of small sites. For that, you can use something like [secure copy](https://linux.die.net/man/1/scp)


## Installation

In a fresh Linux server, pull this repo directly

```bash
git clone https://github.com/elkd/misc.git
```

## Usage

```bash
#For a new site
#Installing dependencies, pulling your repo & setup Gunicorn and Nginx
bash deploy.sh Github-personal-access-token GitHub-account-name Github-repo-name domain-name-without-TLD TLD

#For example
bash deploy.sh chatupa12308bx876136xxxlength40hexstring elkd cool-ecommerce-shop shopingsite com

#The Github account and repo name should be of the Python project you are deploying.
#It can be hosted on a private or public repo, both are okay.
#Make sure your domain name is pointed to the server's Ip address that this script will run
#In this case the example domain name is shopinsite.com
#Note .com has no "." when calling the script   


#You can customize the deploy.sh script and other files to fit your needs, they are very simple.
#They are written in an opinionated way of setting up Small Python Web Applications

#Note the script also assumes you're using other config files present in this repo as well. 
#Otherwise, you can edit or comment line ~43-70 to fit your needs
```
Personal access tokens (PATs) are an alternative to using passwords for authentication to GitHub. Deploy.sh uses PAT to generate an SSH key, which will be used to avoid being prompted for password and username on every pull/fetch to the server. The deploy.sh script uses OpenSSH (ssh-keygen utility), which is used to generate a 2048-bit RSA key pair.

To learn how to obtain a Github Personal access token for your account please visit [this Github article](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)

To learn more about SSH keys [read this github article](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)

The deploy.sh script installs the Postgres Database, Nginx and Python3 build tools to the server. You can edit line 23 to only install the software you want.

The Gunicorn configuration files use Gevent. For that to work well with Postgres DB. In this case, psycogreen is called on all gunicorn processes to monkey patch psycopg (Python Postgres driver that I assume most Postgres users prefer). See the last lines of gunicorn-config.py file to see how this is implemented.

For Django users, django-db-geventpool package is also installed to aid the DB connection pool using gevent. If you are using a framework other than Django you can install a similar DB pool package if you need it eg for Database connections reuse.

If you don't want to use monkey patch with Psycogreen you can edit gunicorn-config.py last function. Eg in a flask app, you can monkey patch using patch_all gevent function.

pip.conf file contains examples of Pypi (pip) url mirrors that you can use to speed up the pip installation.
The default source url of python pip is:https://files.pythonhosted.org/. This site may be very slow and may cause you to fail to install python packages.
You can find the one closer to your server's location, there are plenty of them

```python

from gevent import monkey; monkey.patch_all()

# If you don't want to monkey patch everything
# you can simply patch the standard library thread module
#from gevent import monkey; monkey.patch_thread()

```
 

## Contributing
Pull requests are warmly welcomed. 
For major changes, please open an issue first to discuss what you would like to change.



## License
This repo is available under the [MIT](https://choosealicense.com/licenses/mit/) License
