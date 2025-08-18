#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

#All the secret are expected to be mounted under /var/run/secrets by the ci-operator

#$ASSISTED_CHAT_IMG is not in repo/image:tag format but rather in repo/<image name>@sha256:<digest>
#The template needs the tag, and it references the image by <image name>:<tag> so splitting the variable by ":" works for now

echo $ASSISTED_CHAT_IMG
IMAGE=$(echo $ASSISTED_CHAT_IMG | cut -d ":" -f1)
TAG=$(echo $ASSISTED_CHAT_IMG | cut -d ":" -f2)

oc create secret generic -n $NAMESPACE gemini-api-key --from-file=api_key=/var/run/secrets/gemini/api_key
oc create secret generic -n $NAMESPACE llama-stack-db --from-file=db.ca_cert=/var/run/secrets/llama-stack-db/db.ca_cert \
                                                     --from-file=db.host=/var/run/secrets/llama-stack-db/db.host \
                                                     --from-file=db.name=/var/run/secrets/llama-stack-db/db.name \
                                                     --from-file=db.password=/var/run/secrets/llama-stack-db/db.password \
                                                     --from-file=db.port=/var/run/secrets/llama-stack-db/db.port \
                                                     --from-file=db.user=/var/run/secrets/llama-stack-db/db.user

patch template.yaml -i test/prow/template_patch.diff
echo "GEMINI_API_KEY=$(cat /var/run/secrets/gemini/api_key)" > .env
make generate
sed -i 's/user_id_claim: sub/user_id_claim: client_id/g' config/lightspeed-stack.yaml
sed -i 's/username_claim: preferred_username/username_claim: clientHost/g' config/lightspeed-stack.yaml

# Check if Route CRD is available
if oc api-resources | grep -q route.openshift.io/v1; then
    echo "Route CRD found - applying template with Routes"
    oc process -p IMAGE=$IMAGE -p IMAGE_TAG=$TAG -p GEMINI_API_SECRET_NAME=gemini-api-key -p ASSISTED_CHAT_DB_SECRET_NAME=llama-stack-db -f template.yaml --local | oc apply -n $NAMESPACE -f -
else
    echo "Route CRD not found - applying template and ignoring Route errors"
    # Create temporary file with processed template
    TEMP_MANIFEST=$(mktemp)
    oc process -p IMAGE=$IMAGE -p IMAGE_TAG=$TAG -p GEMINI_API_SECRET_NAME=gemini-api-key -p ASSISTED_CHAT_DB_SECRET_NAME=llama-stack-db -f template.yaml --local > "$TEMP_MANIFEST"
    
    # Temporarily disable exit on error for the apply command
    set +e
    oc apply -n $NAMESPACE -f "$TEMP_MANIFEST" 2>&1 | tee /tmp/apply_output.log
    APPLY_EXIT_CODE=$?
    set -e
    
    # Check if critical resources were created even if some failed
    if oc get deployment assisted-chat -n $NAMESPACE >/dev/null 2>&1 && oc get service assisted-chat -n $NAMESPACE >/dev/null 2>&1; then
        echo "Critical resources (Deployment and Service) created successfully"
        if [ $APPLY_EXIT_CODE -ne 0 ]; then
            echo "Note: Some resources failed to apply (likely Routes due to missing CRD), but core application deployed successfully"
        fi
    else
        echo "Failed to create critical resources, check errors above"
        cat /tmp/apply_output.log
        rm -f "$TEMP_MANIFEST" /tmp/apply_output.log
        exit 1
    fi
    
    rm -f "$TEMP_MANIFEST" /tmp/apply_output.log
fi

sleep 5
POD_NAME=$(oc get pods -n $NAMESPACE | tr -s ' ' | cut -d ' ' -f1| grep assisted-chat)
oc wait --for=condition=Ready pod/$POD_NAME --timeout=300s
