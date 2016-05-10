#!/usr/bin/env bash

# valiabls
AWS_DEFAULT_REGION=us-east-1
AWS_ECS_TASKDEF_NAME=nginx-sample-webapp
AWS_ECS_CLUSTER_NAME=sample-webapp-cluster
AWS_ECS_SERVICE_NAME=sample-webapp-service
AWS_ECR_REP_NAME=nginx-sample-webapp

# Create Task Definition
make_task_def(){
	task_template='[
		{
			\"name\": "${AWS_ECS_TASKDEF_NAME}",
			\"image\": "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${AWS_ECR_REP_NAME}:${CIRCLE_SHA1}",
			\"essential\": true,
			\"memory\": 200,
			\"cpu\": 10,
			\"portMappings\": [
				{
					\"containerPort\": 80,
					\"hostPort\": 80
				}
			]
		}
	]'

	task_def=$(printf "$task_template" $AWS_ACCOUNT_ID $CIRCLE_SHA1)
	task_def=`eval echo $task_def`
}

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
	aws --version
	aws configure set default.region ${AWS_DEFAULT_REGION}
	aws configure set default.output json
}

deploy_cluster() {

    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster ${AWS_ECS_CLUSTER_NAME} --service ${AWS_ECS_SERVICE_NAME} --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster ${AWS_ECS_CLUSTER_NAME} --services ${AWS_ECS_SERVICE_NAME} | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployments:"
            echo "$stale"
            sleep 5
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long."
    return 1
}


push_ecr_image(){
	eval $(aws ecr get-login --region ${AWS_DEFAULT_REGION})
	docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/${AWS_ECR_REP_NAME}:$CIRCLE_SHA1
}

register_definition() {

echo "aaa"
echo "aws ecs register-task-definition --container-definitions "$task_def" --family ${AWS_ECS_TASKDEF_NAME}"

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family ${AWS_ECS_TASKDEF_NAME} | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

configure_aws_cli
push_ecr_image
deploy_cluster
