#! /usr/bin/env bash

# Set Script options and reset existing system options after script exits
orginal_options="$(set +o); set -$-"
set -o nounset
set -o pipefail
set -o errexit
trap 'rc=$?; eval "$orginal_options";trap - EXIT; exit $rc' EXIT

INTERACTIVE="false"

# Check for input
while [[ $# -gt 0 ]]; do
	input_arg="$1"
	case $input_arg in
	-i | --interactive)
	INTERACTIVE="true"
	shift
	;;
	-h | --help)
		echo "Commmand: test-vault.sh"
		echo "Will invoke bats test suite under test/"
	;;
	*)
		echo "Unexpected input with: ${input_arg}"
		exit 1
		;;
	esac
done

#Clean existing containers if they are in use
echo -e "Cleaning up existing containers..."
for container_name in test-vault vault-openldap; do
    set +e
    CMD_OUTPUT=$(docker ps -a | grep $container_name)
    if [[ -n "$CMD_OUTPUT" ]]; then
        docker rm -f $container_name 2> /dev/null
    fi
done

# Build Container
echo -e "\nBuilding Vault Testing Container"
docker build --quiet --tag test-vault:latest -f test/Dockerfile .

echo -e "\nSpinning up OpenLDAP Container"
# Spin Up OpenLDAP
docker run -p 389:389 -p 636:636 --hostname=localhost --env LDAP_ORGANISATION="Test Corp" --env LDAP_TLS_VERIFY_CLIENT="try" --env LDAP_DOMAIN="corp.org" --env LDAP_ADMIN_PASSWORD="Happy123" \
--volume "$(pwd)/test/fixtures/ldap.ldif:/container/service/slapd/assets/config/bootstrap/ldif/50-custom.ldif" \
--volume "$(pwd)/test/fixtures/security.ldif:/container/service/slapd/assets/config/bootstrap/ldif/02-security.ldif" \
--name vault-openldap --detach osixia/openldap:latest --copy-service --loglevel debug

echo -e "\nSpinning up Vault Testing Container and running test suite..."
if [[ "$INTERACTIVE" =~ "false" ]]; then
    docker run --name test-vault --network="host" test-vault:latest
else
	echo "Running in interactive mode"
    docker run -a stdin -a stdout -i -t --name test-vault --network="host" --entrypoint /bin/bash test-vault:latest
fi
