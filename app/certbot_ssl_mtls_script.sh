#!/bin/bash

set -e 

# Required ENV Variables
# DNS_PROJECT, DNS_PROJECT_CREDS, EMAIL, DOMAIN_NAME, DNS_ZONE_NAME, ROOT_DOMAIN, PROJECT_NAME, CREDS_FILE, CLUSTER_NAME, REGION, NAMESPACE, CERT_NAME, PUBLIC_INGRESS, PUBLIC_LB_TARGET_GROUP, INTERNAL_INGRESS, SLACK_ALERT_CHANNEL
# SENDER_EMAIL, RECEIVER_EMAIL, PASS (required by send_email.py)

# Creates local ENV Variables
# TIMESTAMP, ACME_KEY_1, ACME_KEY_2, CERT_FILE, KEY_FILE

export TIMESTAMP=$(python3 -c "import os; from datetime import datetime; print(datetime.now().strftime('%Y-%m%d-%H%M%S'))")

#* Activate access to $DNS_PROJECT
gcloud auth activate-service-account --project=${DNS_PROJECT} --key-file=${DNS_PROJECT_CREDS}
gcloud auth list

#* generate _acme-challenge TXT values
/usr/bin/expect -f ./acme_challenge_generator.sh $EMAIL $DOMAIN_NAME
echo "[INFO] Certbot acme_challenge generation script executed successfully! Capturing values"
grep -E '^[A-Za-z0-9_-]{43}$' certbot_prompts.txt > acme_values.txt
cat acme_values.txt
export ACME_KEY_1=$(awk 'NR==1' "acme_values.txt")
export ACME_KEY_2=$(awk 'NR==2' "acme_values.txt")
echo "[INFO] ACME_KEY_1: $ACME_KEY_1"
echo "[INFO] ACME_KEY_2: $ACME_KEY_2"

#* Check for _acme-challenge record in DNS
acme_exists=$(gcloud dns --project=$DNS_PROJECT record-sets list --zone="$DNS_ZONE_NAME" --name="_acme-challenge.$ROOT_DOMAIN" | grep _acme-challenge.$ROOT_DOMAIN | wc -l)
echo $acme_exists
if [[ $acme_exists -eq 0 ]]; then
    echo "[INFO] ACME record does not exist. Creating one"
    gcloud dns --project=$DNS_PROJECT record-sets create _acme-challenge.$ROOT_DOMAIN --zone="$DNS_ZONE_NAME" --type="TXT" --ttl="300" --rrdatas="$ACME_KEY_1,$ACME_KEY_2"
    echo "[INFO] ACME record created successfully"
else
    echo "[INFO] ACME record exists. Updating it"
    gcloud dns --project=$DNS_PROJECT record-sets update _acme-challenge.$ROOT_DOMAIN --zone="$DNS_ZONE_NAME" --type="TXT" --ttl="300" --rrdatas="$ACME_KEY_1,$ACME_KEY_2"
    echo "[INFO] ACME record updated successfully"
fi

#* Start
echo "[INFO] Starting Issuing of Certificates"
sleep 3

#* issue cert with DNS challenge
/usr/bin/expect -f ./cert_generator.sh $EMAIL $DOMAIN_NAME
# certbot certificates
echo "[INFO] Certificates are issued!"

#* move cert and key to workdir
export CERT_FILE=$(certbot certificates | grep "Certificate Path" | cut -d ':' -f 2 | cut -d ' ' -f 2); cp $CERT_FILE ./cert.key
export KEY_FILE=$(certbot certificates | grep "Private Key Path" | cut -d ':' -f 2 | cut -d ' ' -f 2); cp $KEY_FILE ./priv.key
ls -al
# sudo chown <usr>:<grp> $CERT_FILE $KEY_FILE
echo "[INFO] Cert copied to local file"

#* Upload certbot files
zip -r ${TIMESTAMP}.zip /etc/letsencrypt
gcloud storage cp ${TIMESTAMP}.zip gs://${PROJECT_NAME}-letsencrypt-certbot/
echo "[INFO] Successfully backed-up /etc/letsencrypt to gs://${PROJECT_NAME}-letsencrypt-certbot"

#* Activate access to $PROJECT_NAME
gcloud auth activate-service-account --project=${PROJECT_NAME} --key-file=${CREDS_FILE}
gcloud auth list

#* configure kubeconfig
gcloud config set project ${PROJECT_NAME} --quiet 
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION}
echo "[INFO] gcloud configured successfully!"

#* create/update k8s secret [for MTLS]
kubectl create -n ${NAMESPACE} secret tls ${CERT_NAME} --key=./priv.key --cert=./cert.key --save-config --dry-run=client -o yaml | kubectl apply -f -
# gcloud create -n ${NAMESPACE} secret generic ${CERT_NAME} --from-file=key="${KEY_FILE}" --from-file=cert="${CERT_FILE}"
echo "[INFO] mTLS cert updated successfully!"

#* create and replace ssl-cert [for ****** INTERNAL ****** HTTPS LB]
gcloud compute ssl-certificates create ${CERT_NAME}-${TIMESTAMP} --certificate=./cert.key --private-key=./priv.key --region=${REGION}
echo "pausing for a few sec..."
sleep 5
kubectl patch ingress ${INTERNAL_INGRESS} -n istio-system -p '{"metadata":{"annotations":{"ingress.gcp.kubernetes.io/pre-shared-cert":"'"${CERT_NAME}-${TIMESTAMP}"'"}}}'
# gcloud compute target-https-proxies update ${INTERNAL_LB_TARGET_GROUP} --global --ssl-certificates=${CERT_NAME}-${TIMESTAMP} --global-ssl-certificates 
echo "[INFO] INTERNAL HTTPS LB cert updated successfully!"

# #* create and replace ssl-cert [for ****** PUBLIC ****** HTTPS LB]
# gcloud compute ssl-certificates create ${CERT_NAME}-${TIMESTAMP} --certificate=./cert.key --private-key=./priv.key --global
# echo "pausing for a few sec..."
# sleep 5
# kubectl patch ingress ${PUBLIC_INGRESS} -n istio-system -p '{"metadata":{"annotations":{"ingress.gcp.kubernetes.io/pre-shared-cert":"'"${CERT_NAME}-${TIMESTAMP}"'"}}}'
# gcloud compute target-https-proxies update ${PUBLIC_LB_TARGET_GROUP} --global --ssl-certificates=${CERT_NAME}-${TIMESTAMP} --global-ssl-certificates 
# echo "[INFO] PUBLIC HTTPS LB cert updated successfully!"

#* Send Email alert 
python3 send_email.py ${CLUSTER_NAME} ${CERT_NAME}-${TIMESTAMP} # also requires SENDER_EMAIL, RECEIVER_EMAIL, PASS as set in ENV Variables
echo "[INFO] Team alerted via email about the cert-renewal"

#* Send slack alert
curl -X POST --data-urlencode "payload={\"channel\": \"${SLACK_ALERT_CHANNEL}\", \"username\": \"certbot-renew\", \"text\": \"${CLUSTER_NAME} has been renewed with SSL certificate ${CERT_NAME}-${TIMESTAMP}\"}" ${SLACK_WEBHOOK_URL}
echo "[INFO] Team alerted via slack about the cert-renewal"

#TODO: Cleanup unused certs on GCP Certificate Manager
# delete all starting with ${CERT_NAME} in both --global & --regional
# gcloud compute ssl-certificates delete ${CERT_NAME} --global
# print deleted each per line
echo "[INFO] Unused certificates cleaned-up successfully on GCP Certificate Manager"
