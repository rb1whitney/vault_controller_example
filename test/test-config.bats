#! /usr/bin/env bats

# Spin up a test Vault Cluster on non-standard Vault port
# Set a root token we expect for the automation
setup() {
    export VAULT_DEV_LISTEN_ADDRESS=localhost:8200
    export VAULT_DEV_ROOT_TOKEN_ID="ePTlEeggAGoYE1OMGiUas8du"
    export VAULT_TOKEN=$VAULT_DEV_ROOT_TOKEN_ID
    export VAULT_ADDR="http://${VAULT_DEV_LISTEN_ADDRESS}"
    vault server -dev -dev-no-store-token > /dev/null 2>&1 &
    export VAULT_PID=$!
}

# Uses PID to stop Vault Process
teardown() {
    kill $VAULT_PID
}

@test "Spinning up cluster admin config" {
    run bin/manage-vault.sh  --file-path ./config/admin
    echo "Cluster Config setup results are: ${output}"
    [ "$status" -eq 0 ]
}

@test "Spinning up cluster app1 config" {
    run bin/manage-vault.sh  --file-path ./config/admin
    run find ./config/app1/*.json -exec  bin/manage-vault.sh --file-path {} \;
    run vault write /transit/restore/app1-transit-key backup=`cat test/fixtures/app1-transit-key` force=true
    run bin/manage-vault.sh  --file-path ./config/app1/kv/
    echo "App1 setup results are: ${output}"
    [ "$status" -eq 0 ]
}

@test "Spinning up improperly written json" {
    run manage-vault.sh  --file-path ./test/test-fixtures/invalid-file.json
    echo "Error output: ${output}"
    [ "${status}" != "0" ]
}

@test "Spinning up invalid json file" {
    run manage-vault.sh  --file-path ./test/test-fixtures/invalid-payload.json
    echo "Error output: ${output}"
    [ "${status}" != "0" ]
}
