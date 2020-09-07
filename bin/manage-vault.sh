#! /usr/bin/env bash

original_options="$(set +o); set -$-"
set -o nounset
set -o pipefail
set -o errexit
export VAULT_FORMAT="json"

# Intercept Return Code and reset flags after script is finished
trap 'rc=$?; eval "${original_options}"; unset VAULT_FORMAT; trap - EXIT; exit $rc' EXIT

# Check for input
while [[ $# -gt 0 ]]; do
	input_arg="$1"
	case $input_arg in
	-p | --file-path)
	file_path=$2
	shift
	shift
	;;
	-h | --help)
		echo "Commmand: manage-vault-api.sh --path=path to json file or directories of json files"
		echo "Pass VAULT_ADDR, VAULT_TOKEN prior to running this script"
	;;
	*)
		echo "Unexpected input with: ${input_arg}"
		exit 1
		;;
	esac
done

# Verify VAULT_ADDR and VAULT_TOKEN are set
if [[ -z $VAULT_ADDR || -z $VAULT_TOKEN ]]; then
  echo "Please set VAULT_ADDR or VAULT_TOKEN prior to running this script"
  exit 1;
fi

file_names=$(find $file_path -type f -name "*.json" | sort);
for file_name in $file_names; do
	echo "Processing file $file_name"
	api_objects=$(jq -c '.["api_objects"][]' $file_name)
	
	# Set Vault Namespace if neccesary from file
	vault_namespace=$(echo "$api_objects" | jq 'has("vault_namespace")')
	if [[ "$vault_namespace" == "true" ]]; then
		export VAULT_NAMESPACE=$vault_namespace
	fi

	# Process each API Object in file
	jq -c '.["api_objects"][]' $file_name |
  	while IFS= read -r api_object; do
		api_path=$(echo $api_object | jq -r .api_path)
		api_method=$(echo "$api_object" | jq -r .api_method)
		
		# Check if we retrieve payload from wrapped token
		wrapped_token=$(echo "$api_object" | jq 'has("wrapped_token")')
		if [[ "$wrapped_token" == "true" ]]; then
			wrapped_token=$(echo "$api_object" | jq -r .wrapped_token)
			api_payload=$(vault unwrap $wrapped_token | jq -r '.data')
		else
			api_payload=$(echo "$api_object" | jq -cr .api_payload)
		fi
		
		transit_engine=$(echo "$api_object" | jq 'has("transit_engine")')
		transit_key=$(echo "$api_object" | jq 'has("transit_key")')
		if [[ "$transit_engine" == "true" && "$transit_key" == "true" ]]; then
			transit_engine=$(echo "$api_object" | jq -r .transit_engine)
			transit_key=$(echo "$api_object" | jq -r .transit_key)
			api_payload_keys=$(echo "$api_payload" | jq -r 'keys[]')
				for api_payload_key in $api_payload_keys; do
					api_payload_value=$(echo "$api_payload" | jq -r .$api_payload_key)
					if [[ $api_payload_value =~ ^vault:.* ]]; then
						unencrypted_value=$(vault write $transit_engine/decrypt/$transit_key ciphertext=$api_payload_value | jq -r .data.plaintext | base64 -d)
						api_payload=$(echo $api_payload | jq ".${api_payload_key} |= \"${unencrypted_value}\"")
					fi
				done
		fi
		
		# Policy API calls are handled differently and not friendly unless using vault policy write"
		if [[ $api_path =~ ^sys/policy.* ]]; then
			policy_definitions=$(echo $api_payload | jq '@json')
			api_payload='{"policy":'"${policy_definitions}"'}'
		fi
		
		# Use Vault Command to perform pass thru of json
		echo "Perform $api_method against API Path $VAULT_ADDR/v1/$api_path"
		case "$api_method" in
			"get")
				api_response=$(vault read_action $api_path)
				echo "API Response:\n$api_response"
			;;
			"list"|"delete")
				api_response=$(vault $api_method $api_path)
				echo "API Response:\n$api_response"
			;;
			"post"|"put")
				set +e
				# echo "API Payload:$api_payload"
				api_response=$(echo "$api_payload" | vault write $api_path - 2>&1)
				if [ $? -eq 0 ] || [[ $api_response =~ .*already[[:space:]]in[[:space:]]use.* ]]; then
					continue
				else
					echo "API Error:\n$api_response"
					exit 1
				fi
				echo "API Response:\n$api_response"
				set -e
			;;
		esac
	done
	# Unset Vault Namespace
	unset VAULT_NAMESPACE
done
