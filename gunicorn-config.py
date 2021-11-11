#This file will be called when the systemd is starting gunicorn
#It is called by a command argument -c in the gunicorn.service file

#Full example can be found here
#https://github.com/benoitc/gunicorn/blob/29f0394cdd381df176a3df3c25bb3fdd2486a173/examples/example_config.py

#This is default. Strict but the best, let users retry on dead request connections
timeout = 30

#Depending on the number of cpu, also remember uvicorn is running so requests are split
#This number is for 2 vCPU instance. I have to deploy same instances for easy managing.
workers = 6

pidfile = '/home/ubuntu/run/gunicorn/pid'

#logs
#If trying to catch some errors and warnings then it is info
#if everything settle down then change to critical
loglevel = 'info'
errorlog = '/home/ubuntu/logs/gunicorn-error.log'
accesslog = '/home/ubuntu/logs/gunicorn-access.log'
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

bind = 'unix:/run/gunicorn.sock'

#This worker class needs patching for some libraries
#Can't use gevent with celery or other libraries in this same configuration
worker_class = 'gevent'
worker_connections = 1000

#This is to patch psycogreen so it can be run with gevent
from psycogreen.gevent import patch_psycopg

def post_fork(server, worker):
    patch_psycopg()
    worker.log.info("Made Psycopg2 Green")
