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

@test "Test Logging into cluster" {
    run bin/manage-vault.sh  --file-path ./config/admin
    export username=vaultdeveloper1
    export password=$(grep -A3 "^uid: $username" test/fixtures/ldap.ldif | grep userpassword | awk -F' ' '{print $2}')
    run vault login -method=ldap username=$username password=$password
    echo "User is able to log into cluster: ${output}"
    [ "$status" -eq 0 ]
}

@test "Test incorrect Password" {
    run bin/manage-vault.sh  --file-path ./config/admin
    export username=vaultdeveloper1
    export password=thisisnotright
    run vault login -method=ldap username=$username password=$password
    echo "User is unable to log into cluster: ${output}"
    [ "$status" -eq 2 ]
}
