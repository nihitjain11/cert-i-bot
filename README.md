# Set Project
gcloud config set project gcp-project

gcloud container clusters get-credentials gcp-project-k8s-cluster --region us-east1

gcloud auth configure-docker

# if errors then run docker builder prune

docker build -t gcr.io/gcp-project/certibot . && docker push gcr.io/gcp-project/certibot

# bucket creation in same project
# update env vars in certibot-job.yaml
# comment Line 25 command: ["python3", "bashcmd.py", "certbot_ssl_mtls_script.sh"]  and update cron timing to run in next 2-3 mins
kubectl apply -f certibot-job.yml
watch kubectl get cronjob

# exec onto pod and run python3 bashcmd.py certbot_ssl_mtls_script.sh
# once run, it will create the cert and upload it on bucket
# validate files in bucket and set cron back to initial value and uncomment command
# re-apply certbot-job.yaml
kubectl apply -f certibot-job.yml
watch kubectl get cronjob

# TROUBLESHOOTING
kubectl create job --from=cronjob/certibot certibot -n certibot