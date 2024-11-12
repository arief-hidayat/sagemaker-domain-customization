## About this image
What I would like to achieve here:
* extend the latest sagemaker jupyterlab image
* update libraries `jupyter-collaboration==3.0.0 jupyter_ydoc==3.0.0` in attempt to fix [this issue](https://github.com/jupyterlab/jupyter-collaboration/issues/351#issuecomment-2378986168) 
* add [script to modify livy client code](./hack-livyclient.sh)
* add [script to package requirements.txt into tar file and upload to S3](./tar-pip.sh)


### Build image

```bash
docker build -f Dockerfile.jupyterlab -t ariefhidayat/sagemaker-distribution:2.1.0-cpu .
docker push ariefhidayat/sagemaker-distribution:2.1.0-cpu
```

### Manually Test image
```bash
docker run --rm -it --entrypoint /bin/bash ariefhidayat/sagemaker-distribution:2.1.0-cpu
```

### Using the image in Sagemaker

Please refer to
* [this docs](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-updated-jl-provide-users-with-images.html) to use custom image in Sagemaker domain
* [this cli command](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/sagemaker/update-domain.html) to update Sagemaker domain via CLI

Make sure to add IAM permissions to list the sagemaker images to the role.
```bash
# push image to your ECR
image_uri=your-aws-account-id.dkr.ecr.ap-southeast-3.amazonaws.com/sagemaker/sagemaker-distribution:2.1.0-cpu
docker tag ariefhidayat/sagemaker-distribution:2.1.0-cpu $image_uri
docker push $image_uri

# create Sagemaker app image config
aws sagemaker create-app-image-config --app-image-config-name default-jupyterlab --jupyter-lab-app-image-config {}
app_image_config_arn=$(aws sagemaker describe-app-image-config --app-image-config-name default-jupyterlab | jq -r .AppImageConfigArn)
echo $app_image_config_arn

# create Sagemaker image
domain_id=d-xxx
role_arn=$(aws sagemaker describe-domain --domain-id $domain_id | jq -r .DefaultSpaceSettings.ExecutionRole)
aws --profile cgk-sso sagemaker create-image --image-name aht-sagemaker-dist-2.1.0 --role-arn $role_arn
# create Sagemaker image version
aws --profile cgk-sso sagemaker create-image-version --image-name aht-sagemaker-dist-2.1.0 \
  --base-image $image_uri

# update domain. set custom image for JupyterLabApp.
aws --profile cgk-sso sagemaker update-domain \
    --domain-id $domain_id \
    --default-user-settings '{
        "JupyterLabAppSettings": {
            "CustomImages": [
                {
                    "ImageName": "aht-sagemaker-dist-2.1.0",
                    "AppImageConfigName": "default-jupyterlab"
                }
            ]
        }
    }'
```

With above setup, you should be able to see this custom image in drop down selection in your JupyterLab Space.

You can then use the [tar-pip.sh](./tar-pip.sh) from terminal or kernel.

Example of generating tar file from `test.txt` which contains python requirements.
![tar-pip](../imgs/tar-pip-01.jpg)
