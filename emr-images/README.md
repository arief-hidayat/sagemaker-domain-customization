## Context

In this section, we would like to create custom image that we will use in EMR Serverless

For [Dockerfile.emr-serverless-7.2.0](./Dockerfile.emr-serverless-7.2.0): 
* extend `public.ecr.aws/emr-serverless/spark/emr-7.2.0:latest`
* add `spark-snowflake` and `snowflake-jdbc`. 

For [Dockerfile.emr-serverless-7.9.0](./Dockerfile.emr-serverless-7.9.0):
* extend `public.ecr.aws/emr-serverless/spark/emr-7.9.0:20250425`
* upgrade python to 3.11

This is just illustration, might not be best practices.

## Setup

The following steps are for [Dockerfile.emr-serverless-7.9.0](./Dockerfile.emr-serverless-7.9.0). However, you can change the env var to build [Dockerfile.emr-serverless-7.2.0](./Dockerfile.emr-serverless-7.2.0) accordingly.

### Prerequisite

* x86-based or arm-based machine with the following installed
    * `docker` with multi-architecture docker build capability.
    * `AWS CLI` (configured properly)
    * `jq` for json manipulation

### Create ECR repo with policy to allow EMR Serverless
```bash
export REPO_NAME=emr-serverless-7.9.0/spark
export AWS_REGION=ap-southeast-3
aws --region $AWS_REGION ecr create-repository --repository-name $REPO_NAME --image-scanning-configuration scanOnPush=true
aws --region $AWS_REGION ecr set-repository-policy \
    --repository-name $REPO_NAME \
    --policy-text '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EmrServerlessCustomImageSupport",
            "Effect": "Allow",
            "Principal": {
                "Service": "emr-serverless.amazonaws.com"
            },
            "Action": [
                "ecr:BatchGetImage",
                "ecr:DescribeImages",
                "ecr:GetDownloadUrlForLayer"
            ]
        }
    ]
}'

export REPO_URI=$(aws --region $AWS_REGION ecr describe-repositories --repository-name $REPO_NAME | jq -r '.repositories[0].repositoryUri')
echo $REPO_URI
```
### Preparing your Container image
Ref: https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/application-custom-image.html

### Push container image
login to ECR
```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URI
```
multi-arch container build and push
```bash
image_uri="${REPO_URI}:0.0.1"
docker buildx build --push --platform linux/arm64/v8,linux/amd64 -f Dockerfile.emr-serverless-7.9.0 -t $image_uri .
```

### Use in your Sagemaker Studio

* Create EMR Serverless Cluster from Sagemaker Studio. ![create-emr](../imgs/create-emr-cluster-01.jpg)
* Set custom image ![set-custom-image](../imgs/create-emr-cluster-02-set-image.jpg)
* Start EMR cluster and use it ![start-it](../imgs/create-emr-cluster-03-start.jpg)

**Note**: As of June 2025, creation of EMR serverless from Sagemaker Studio UI only support up to EMR version 7.2.0. So, I recommend creating from CLI or IaC.

#### Create EMR Application using CLI
Using CLI to [create EMR serverless application](https://docs.aws.amazon.com/cli/latest/reference/emr-serverless/create-application.html).

```bash
DOMAIN_ID=d-xxx
AWS_REGION=ap-southeast-3
USER_PROFILE_NAME=$(aws sagemaker list-user-profiles \
--domain-id "$DOMAIN_ID" \
--region "$AWS_REGION" \
--query "UserProfiles[0].UserProfileName" \
--output text)
user_profile_arn=$(aws sagemaker describe-user-profile \
--domain-id "$DOMAIN_ID" \
--user-profile-name "$USER_PROFILE_NAME" \
--region "$AWS_REGION" \
--query "UserProfileArn" \
--output text)
echo $user_profile_arn
domain_arn=$(aws sagemaker describe-domain \
    --domain-id "$DOMAIN_ID" \
    --region "$AWS_REGION" \
    --query "DomainArn" \
    --output text)
echo $domain_arn
space_arn=

EMR_APP_NAME=my-emr-graviton2
# assumed you want to connect to VPC
SUBNET_IDS='["subnet-xx","subnet-yy"]'
SECURITY_GROUP_IDS=["sg-xx"]

cat << EOF > emr-serverless-app.json
{
  "name": "$EMR_APP_NAME",
  "releaseLabel": "emr-7.9.0",
  "type": "SPARK",
  "architecture": "ARM64",
  "interactiveConfiguration": {
    "studioEnabled": false,
    "livyEndpointEnabled": true
  },
  "initialCapacity": {
      "DRIVER": {
          "workerCount": 1,
          "workerConfiguration": {
              "cpu": "4vCPU",
              "memory": "16GB",
              "disk": "20GB",
              "diskType": "STANDARD"
          }
      },
      "EXECUTOR": {
          "workerCount": 3,
          "workerConfiguration": {
              "cpu": "4vCPU",
              "memory": "8GB",
              "disk": "20GB",
              "diskType": "STANDARD"
          }
      }
  },
  "maximumCapacity": {
      "cpu": "400vCPU",
      "memory": "3000GB",
      "disk": "20000GB"
  },
  "runtimeConfiguration": [
      {
          "classification": "spark-defaults",
          "properties": {
              "spark.hadoop.hive.metastore.client.factory.class": "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
          }
      }
  ],
  "tags": {
      "sagemaker:user-profile-arn": "$user_profile_arn",
      "sagemaker:domain-arn": "$domain_arn",
      "sagemaker:space-arn": "$space_arn"
  },
  "workerTypeSpecifications": {
    "Driver": {
      "imageConfiguration": {
        "imageUri": "$image_uri"
      }
    },
    "Executor": {
      "imageConfiguration": {
        "imageUri": "$image_uri"
      }
    }
  },
  "autoStartConfiguration": {
    "enabled": true
  },
  "autoStopConfiguration": {
    "enabled": true,
    "idleTimeoutMinutes": 15
  },
  "networkConfiguration": {
      "subnetIds": $SUBNET_IDS,
      "securityGroupIds": $SECURITY_GROUP_IDS
  },
  "monitoringConfiguration": {
      "managedPersistenceMonitoringConfiguration": {
          "enabled": true
      },
      "cloudWatchLoggingConfiguration": {
          "enabled": true,
          "logGroupName": "sagemaker-emr",
          "logStreamNamePrefix": "/$DOMAIN_ID/$EMR_APP_NAME"
      }
  }
}
EOF
```

Read following docs and modify `emr-serverless-app.json` according to your need.
* [Configuring an application when working with EMR Serverless](https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/application-capacity.html)
* [EMR Serverless default configs](https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/default-configs.html)
* [Running interactive EMR serverless - considerations](https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/interactive-workloads-livy-endpoints.html#interactive-workloads-livy-endpoints-considerations)

```bash
# make sure you review the emr-serverless-app.json before creating EMR application
aws emr-serverless create-application \
 --cli-input-json file://emr-serverless-app.json \
 --region $AWS_REGION
 ```

### Test your image

You can use an [example notebook](https://github.com/aws-samples/run-interactive-workloads-on-amazon-emr-serverless-from-amazon-emr-studio/blob/main/livy-endpoint/Getting-started-emr-serverless-livy-endpoint.ipynb) to test on SparkMagic Pyspark kernel

Just need to add one cell on top to connect to EMR, e.g.
```
%load_ext sagemaker_studio_analytics_extension.magics
%sm_analytics emr-serverless connect --application-id $EMR_APP_ID --language python --emr-execution-role-arn $EMR_EXECUTION_ROLE_ARN
```

In case needed, you can configure sparkmagic configuration, e.g.
```
echo '{"livy_session_startup_timeout_seconds": 180}' > ~/.sparkmagic/config.json
```
