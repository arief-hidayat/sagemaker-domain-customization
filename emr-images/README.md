### Create ECR repo with policy to allow EMR Serverless
```bash
export REPO_NAME=emr-serverless-7.2.0/spark
aws ecr create-repository --repository-name $REPO_NAME --image-scanning-configuration scanOnPush=true
aws ecr set-repository-policy \
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
```
### Preparing your Container image
Ref: https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/application-custom-image.html

### Push container image
```bash
image_uri=your-aws-account-id.dkr.ecr.ap-southeast-3.amazonaws.com/emr-serverless-7.2.0/spark:0.0.1
docker tag ariefhidayat/emr-serverless-spark:7.2.0 $image_uri
docker push $image_uri
```

### Use in your Sagemaker Studio

* Create EMR Serverless Cluster from Sagemaker Studio. ![create-emr](../imgs/create-emr-cluster-01.jpg)
* Set custom image ![set-custom-image](../imgs/create-emr-cluster-02-set-image.jpg)
* Start EMR cluster and use it ![start-it](../imgs/create-emr-cluster-03-start.jpg)