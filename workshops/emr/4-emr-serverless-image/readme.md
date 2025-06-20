# EMR Serverless Image Guide


This guide will help you to create an EMR Serverless Image to be used interactively in notebook in an EMR Application.

Sagemaker notebook connect to EMR serverless using Apache Livy REST API and SageMaker Studio Analytics Extension.


## Create EMR Image

1. Refer to this documentation to see the steps and permissions required: https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/application-custom-image.html
2. Create a custom image from EMR Serverless base image.
    

Use the same EMR Version that you want to use, example in this image is EMR 7.5. 
In this sample we also install a new python version which is 3.11 in EMR. There are some fix required for Livy to perform correctly in Python 3.10 so we also edit the Livy jar to fix it. 
Packages to be installed is also listed below.

**Docker base file example:**

```
# Dockerfile
FROM public.ecr.aws/emr-serverless/spark/emr-6.9.0:latest

USER root
# MODIFICATIONS GO HERE

# EMRS will run the image as hadoop
USER hadoop:hadoop
```


**Sample:** `emr-s-75-image.dockerfile`

```
# Dockerfile
FROM public.ecr.aws/emr-serverless/spark/emr-7.5.0:latest

USER root
# MODIFICATIONS GO HERE

# UPGRADING PYTHON
RUN dnf install python3.11 python3.11-pip

# FIX LIVY ISSUE FOR PYTHON 3.10 OR NEWER
WORKDIR /tmp
RUN jar xf /usr/lib/livy/repl_2.12-jars/livy-repl_2.12-0.7.1-incubating.jar fake_shell.py && \
    sed -ie 's/version < \"3\.8\"/version_info < \(3,8\)/' fake_shell.py && \
    jar uvf /usr/lib/livy/repl_2.12-jars/livy-repl_2.12-0.7.1-incubating.jar fake_shell.py
WORKDIR /home/hadoop

ENV PYSPARK_PYTHON=/usr/bin/python3.11


# INSTALL PACKAGES
RUN python3.11 -m pip install cython numpy matplotlib requests boto3 pandas great_expectations plotly dash scipy

# EMRS will run the image as hadoop
USER hadoop:hadoop
```




1. Build the docker image

```
docker build -f emr-s-75-image.dockerfile -t 11701913xxxx.dkr.ecr.ap-southeast-3.amazonaws.com/cgk_nico_ecr_repo:[emrs-7.5-mylib](https://ap-southeast-3.console.aws.amazon.com/ecr/repositories/private/11701913xxxx/cgk_nico_ecr_repo/_/image/sha256:9dfc08d797a2d049f040f8b8737ce6368c0975a7f708e056ec8e034941892964/details?region=ap-southeast-3)
```

2. Upload the image to your Amazon ECR repository

```
# login to ECR repo
aws ecr get-login-password --region ap-southeast-3 | docker login --username AWS --password-stdin 11701913xxxx.dkr.ecr.ap-southeast-3.amazonaws.com

# push the docker image
docker push 11701913xxxx.dkr.ecr.ap-southeast-3.amazonaws.com/cgk_nico_ecr_repo:emrs-7.5-mylib
```

3. Allow EMR Serverless to access the custom image repository
    Go to ECR > Repositories > Select the Repository radio button > Permissions.
    Add the following permission:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Emr Serverless Custom Image Support",
      "Effect": "Allow",
      "Principal": {
        "Service": "emr-serverless.amazonaws.com"
      },
      "Action": [
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Condition":{
        "StringEquals":{
          "aws:SourceArn": "arn:aws:emr-serverless:region:aws-account-id:/applications/application-id"
        }
      }
    }
  ]
}
```

## Create EMR Serverless Application



1. Select EMR Serverless > Create new application
2. Choose the EMR version, and choose ‘Custom configuration’
3. **Preinitialized capacity**
    Configure preinitialized capacity for a interactive notebook session. Note that pricing will start when application starts.
    Personal note: interactive session require at least 1 driver+2 workers, with 4 vcpu each.
4. **Application configuration**.
    Configure the spark configuration here to specify application-wide configuration such as spark driver core and disks.

```
{
  "runtimeConfiguration": [
    {
      "classification": "spark-defaults",
      "configurations": null,
      "properties": {
        "spark.executor.memory": "8G",
        "spark.driver.memory": "8G",
        "spark.emr-serverless.driver.disk": "30G",
        "spark.emr-serverless.executor.disk": "25G",
        "spark.driver.cores": "4",
        "spark.executor.cores": "2"
      }
    }
  ]
}
```

Spark configuration guide: https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/jobs-spark.html


5. **Custom image settings**
    Specify the custom image URL, such as:

```
11701913xxxx.dkr.ecr.ap-southeast-3.amazonaws.com/cgk_nico_ecr_repo:emrs-7.5-mylib
```

6. Start the application
