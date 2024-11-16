FROM --platform=linux/amd64 ubuntu:20.04 

#update and install dependencies
RUN apt-get update -y
RUN apt-get install -y zip vim nano expect
#install gcloud cli, kubectl
RUN apt-get install -y apt-transport-https ca-certificates gnupg curl
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN apt-get update -y 
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata
# RUN echo Etc/UTC >/etc/timezone && dpkg-reconfigure -f noninteractive tzdata
RUN apt-get install -y python3 python3-pip python3-venv libaugeas0 nginx
RUN apt-get install -y google-cloud-cli
RUN apt-get install -y google-cloud-cli-gke-gcloud-auth-plugin kubectl
#install certbot
RUN python3 -m venv /opt/certbot/
RUN /opt/certbot/bin/pip install --upgrade pip
RUN /opt/certbot/bin/pip install certbot certbot-nginx secure-smtplib 
RUN ln -s /opt/certbot/bin/certbot /usr/bin/certbot

#copy files
COPY creds /creds
COPY app /app

#set workdir
WORKDIR /app
RUN chmod +x ./*

#keep it running
CMD ["sh", "-c", "tail -f /dev/null"]
