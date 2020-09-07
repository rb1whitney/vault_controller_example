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

@test "Write Wrapped Token " {
    run bin/manage-vault.sh  --file-path ./config/admin
    run tee wrapped-token-test.json  <<EOF
{
    "api_objects": [
        {
            "api_method": "post",
            "api_path": "vault-admin/wrapped-token-test",
            "wrapped_token": "$(vault write sys/wrapping/wrap blah=blah| grep wrapping_token: | awk '{ print $2}')"
        }
    ]
}
EOF
    run bin/manage-vault.sh  --file-path ./wrapped-token-test.json
    echo "User is unable to write wrapped token into cluster: ${output}"
    [ "$status" -eq 0 ]
}
