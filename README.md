# HashiCorp Vault State Controller Example
This repository contains basic automation logic wrapping the Vault CLI to maintain state for any given Vault Cluster. The basic manage data script performs writes against the Vault Cluster with the desired state found in the included config folder. The script can take transit engine encrypted data within the repository and decrypt these secret values prior to running the required API command to the cluster. This functionality allows you to secure sensitive secrets in Vault while practicing complete Infrastructure as Code (IaC) patterns. This repository is intended to be used from your CI/CD orchestrator against any target Vault Cluster. The script will ignore Vault API error warnings such as those thrown with secret engines (you can only enable a secret engine once) and perform subsequent writes to all other resources.

[<img src="images/interacting_with_vault.png?raw=true" width="70%"/>](iimages/interacting_with_vault.png?raw=true)


## Requirements
* Bash
* Docker (if using automated BATS testing)
* JQ
* Vault Binary

## How to use script
To use interact with the vault cluster, you will want to log into vault using an opinionated login vault script. You can then run the manage data script to apply changes from a target configuration folder using the VAULT_TOKEN environment variable. I highly suggest using a trap function to revoke the token issues by Vault after processing is done as seen below in a possible variation of logging into Vault

```bash
# Log in with what you need
VAULT_TOKEN=$(VAULT_FORMAT=json vault login -no-store -method=userpass username=$(gopass ldap/username) password=$(gopass ldap/password)| jq -r .auth.client_token)
VAULT_TOKEN=$(VAULT_FORMAT=json vault login -no-store -method=ldap username=$(gopass ldap/username) password=$(gopass ldap/password) | jq -r .auth.client_token)
VAULT_TOKEN=$(VAULT_FORMAT=json vault login -no-store -method=aws header_value=corp.com role=corp-role-iam | jq -r .auth.client_token)
VAULT_TOKEN=$(VAULT_FORMAT=json vault login -no-store -method=cert -method=cert -ca-cert=ca.pem -client-cert=cert.pem -client-key=key.pem name=server-role | jq -r .auth.client_token)

# Revoke token no matter status of job
trap 'rc=$?; vault token revoke -self; unset VAULT_TOKEN; trap - EXIT; exit $rc' EXIT

# Run Automation Script
sh manage_vault.sh --file-path <<./config/admin>> or <<./config/app1/kv/app1-team-secrets/external-vendor.json>>
```

## How to test this repository's code
The easiest way to test changes using IaC patterns is run vault in dev mode within a container. By leveraging this feature, teams can perform repeated testing against a re-usable sandboxed cluster to validate the Vault configuration. The example test-vault script invokes the required example containers to create a mock LDAP that supports testing the Vault cluster. This setup allows the Vault server to behave in a similar manner as a live environment. The configuration being used are leveraging the exported transit key from a test cluster. In general, a backup of the transit used to encrypt secrets. The Vault CLI command to do that is:

```bash
VAULT_FORMAT=json vault read transit/export/encryption-key/vault-auditor-transit-key
```

The test data should be different from the live data, so secrets are never leaked from source control to Vault. The purpose of the configs is to allow you to test changes prior to deploy the real data. You can do that by invoking the following:

Non-Interactive Mode:
```bash
sudo bin/test-vault.sh 
Cleaning up existing containers...
test-vault
vault-openldap

Building Vault Testing Container
sha256:c54873b7d880a2da937b21eda3c63e9dca95090459e853355cde080608b34418

Spinning up OpenLDAP Container
3b7a4a0083e14a8f3fd5900d5487463b4f584216f0553da43c264988f10c6397

Spinning up Vault Testing Container and running test suite...
1..2
ok 1 Test Logging into cluster
ok 2 Test incorrect Password
1..1
ok 1 Write Wrapped Token 
1..4
ok 1 Spinning up cluster admin config
ok 2 Spinning up cluster app1 config
ok 3 Spinning up improperly written json
ok 4 Spinning up invalid json file
```

Interactive Mode inside container:
```bash
rwhitney@rb1whitney-ubuntu20:~/vault_controller_example$ sudo bin/test-vault.sh -i
...

Spinning up Vault Testing Container and running test suite...
Running in interactive mode
bash-5.0# bats test/test-ldap.bats 
1..2
ok 1 Test Logging into cluster
ok 2 Test incorrect Password
```
