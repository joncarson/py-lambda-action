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
	echo "Deploying the code itself for directory: $1"
	zip -r ${$1::-1}.zip $1 -x \*.git\*
	aws lambda update-function-code --function-name "${$1::-1}" --zip-file fileb://${$1::-1}.zip
}

update_function_layers(){
	echo "Using the layer in the function..."
	aws lambda update-function-configuration --function-name "${$1::-1}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
	install_zip_dependencies
	publish_dependencies_as_layer
	for dir in */; do
		publish_function_code $dir
		update_function_layers $dir
	done
}

deploy_lambda_function
echo "Done."
