#!/bin/bash

echo "Starting docker containers ..."
docker-compose -f docker-compose.yml up -d

max_no_of_attempts=4
no_of_attempts=0

validate_output() {
    local component_name="$1"
    local err_output="$2"

    local lower_output=$(echo "$err_output" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower_output" == *"error"* || "$lower_output" == *"err"* ]]; then 
        echo "$component_name failed with error:" 
        echo "$err_output"
        exit 1
    fi
}

echo "Polling Vault container readiness ..."
until docker exec vault-spii vault status > /dev/null 2>&1; do 
    sleep 2
    ((no_of_attempts++))


    if (( no_of_attempts > max_no_of_attempts )); then
        echo "Vault container unresponsive. Quitting ..."
        no_of_attempts=0
        exit 1
    fi
done 

echo "Initializing Vault Transit Engine for SPII Data (CNP/SSN)..."
# Setup vault: https://developer.hashicorp.com/vault/docs/secrets/transit#setup
OUTPUT=$(docker exec -e VAULT_TOKEN="root-token" vault-spii vault secrets enable transit)
validate_output "Vault", "$OUTPUT"

OUTPUT=$(docker exec -e VAULT_TOKEN="root-token" vault-spii vault write -f transit/keys/cnp-encryption-key)
validate_output "Vault", "$OUTPUT"

echo "Vault transit engine initialized. Key: cnp-encryption-key"

echo "Polling for Kafka broker readiness ..."
# TODO: Potential pain point (path may differ between containers)
until docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list > /dev/null 2>&1; do
    sleep 2
    ((no_of_attempts++))


    if (( no_of_attempts > max_no_of_attempts )); then
        echo "Kafka container unresponsive. Quitting ..."
        no_of_attempts=0
        exit 1  
    fi
done

echo "Creating Event-Driven Architecture topics ..."
# TODO: Potential pain point (path may differ between containers)
OUTPUT=$(docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --create \
    --topic payment-requested-events \
    --bootstrap-server localhost:9092 \
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists)
validate_output "Kafka", "$OUTPUT"
# TODO: Potential pain point (path may differ between containers)        
OUTPUT=$(docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --create \
    --topic payment-completed-events \
    --bootstrap-server localhost:9092 \
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists)
validate_output "Kafka", "$OUTPUT"
echo "Kafka topics created."

echo "Polling for MinIO readiness..."
until curl -s -o /dev/null http://localhost:9000/minio/health/live; do
    sleep 2
    ((no_of_attempts++))


    if (( no_of_attempts > max_no_of_attempts )); then
        echo "Vault container unresponsive. Quitting ..."
        no_of_attempts=0
        exit 1
    fi
done

echo "Configuring MinIO Batch Payment Bucket..."
# Setup a temp container
# TODO: potential pain point: infrastructure_data-tier, <infrastructure> is the name of curr dir 
OUTPUT=$(docker run --rm --network infrastructure_data-tier \
            -e MINIO_ROOT_USER="admin" -e MINIO_ROOT_PASSWORD="password" \
            --entrypoint /bin/sh minio/mc \
            -c "mc alias set myminio http://minio-s3:9000 admin password && mc mb myminio/batch-payments && mc anonymous set public myminio/batch-payments")
validate_output "MinIO", "$OUTPUT"

echo "MinIO S3 bucket 'batch-payments' configured."

echo "Docker containers started."

