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
# docker tag  ariefhidayat/sagemaker-distribution:2.1.0-cpu your-aws-account-id.dkr.ecr.ap-southeast-3.amazonaws.com/sagemaker/sagemaker-distribution:2.1.0-cpu
```

### Manually Test image
```bash
docker run --rm -it --entrypoint /bin/bash ariefhidayat/sagemaker-distribution:2.1.0-cpu
```