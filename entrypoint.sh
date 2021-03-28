#!/bin/bash
set -e

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "Publishing dependencies as a layer..."
	local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code for directory: ${1::-1}"
	zip -r -j ${1::-1}.zip $1* -x \*.git\*

	if [ "${1:0:1}" = "z" ]; then

		for i in {0..499}
		do
			function_number="00$i"
			function_number=${function_number:(-3)}
			function_name=${1::-1}_$function_number
			echo "Deploying dynamic code itself for function: $function_name"
			aws lambda update-function-code --function-name "$function_name" --zip-file fileb://${1::-1}.zip
			aws lambda update-function-configuration --function-name "$function_name" --handler "${1::-1}.lambda_handler" 	
		done
	else
		aws lambda update-function-code --function-name "${1::-1}" --zip-file fileb://${1::-1}.zip
		aws lambda update-function-configuration --function-name "${1::-1}" --handler "${1::-1}.lambda_handler" 
	fi;
}

update_function_layers(){
	echo "Using the layer in the function..."
	if [ "${1:0:1}" = "z" ]; then
		for i in {0..499}
		do
			function_number="00$i"
			function_number=${function_number:(-3)}
			function_name=${1::-1}_$function_number
			echo "Deploying dynamic layer for function: $function_name"
			aws lambda update-function-configuration --function-name "$function_name" --handler "${1::-1}.lambda_handler" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
		done
	else
		aws lambda update-function-configuration --function-name "${1::-1}" --handler "${1::-1}.lambda_handler" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
	fi;
}


deploy_lambda_function
echo "Done."
