#!/bin/python3

# Required ENV Variables
# SENDER_EMAIL, RECEIVER_EMAIL, PASS
# CLUSTER_NAME(arg1), SSL_CERT_NAME(arg2)

import smtplib
import os, sys

sender = os.getenv('SENDER_EMAIL')
receiver = os.getenv('RECEIVER_EMAIL')
password = os.getenv('PASS')

CLUSTER_NAME = sys.argv[1]
SSL_CERT_NAME = sys.argv[2]

subject = f'SSL Certificate autorenewed for {CLUSTER_NAME}'

marker = "AUNIQUEMARKER"

body = f"{CLUSTER_NAME} has been renewed with SSL certificate {SSL_CERT_NAME}"

message = f"""From: <{sender}>
To: <{receiver}>
Subject: {subject}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary={marker}
--{marker}
""" + f"""Content-Type: text/plain
Content-Transfer-Encoding:8bit

{body}
--{marker}--
"""

try:
    server = smtplib.SMTP('smtp.gmail.com',587)
    server.starttls()
    server.login(sender,password)
    server.sendmail(sender,receiver,message)    
    print ("Successfully sent email")
except Exception as e:
    print ("Error: unable to send email, following error occured:\n", e)
