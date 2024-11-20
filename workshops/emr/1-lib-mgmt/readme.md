# Sagemaker-EMR Integration Guide

### 1. Notebook-scoped Libraries.

#### Load python libraries to notebook (notebook-scope libraries). 

* Use sc.install_pypi_package to load the python packages to the EMR cluster. Ensure that the EMR cluster can connect to the python repository.
* Enable virtualenv in the notebook to install packages.
* Note:
    * Notebook-scoped libraries are intended to be used only with the PySpark kernel.
    * Any user can install additional notebook-scoped libraries from within a notebook cell. These libraries are only available to that notebook user during a single notebook session. If other users need the same libraries, or the same user needs the same libraries in a different session, the library must be re-installed.
    * If the same libraries with different versions are installed on the cluster and as notebook-scoped libraries, the notebook-scoped library version overrides the cluster library version.
* Examples:

    ```
    sc.install_pypi_package("celery")
    sc.install_pypi_package("arrow==0.14.0", "https://pypi.org/simple")
    ```

    Then, list the packages using this command.

    ```
    sc.list_packages()
    ```

* Main reference:
    *  https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-managed-notebooks-installing-libraries-and-kernels.html#emr-managed-notebooks-custom-libraries-limitations

#### Import Jars and Maven packages to notebook

* Use spark configuration using spark.jars and spark.jars.packages to load external jars and Maven packages.
    ```
    %%configure -f{
        "conf": {
        "spark.jars.packages": "com.jsuereth:scala-arm_2.11:2.0,ml.combust.bundle:bundle-ml_2.11:0.13.0,com.databricks:dbutils-api_2.11:0.0.3",
        "spark.jars": "s3://amzn-s3-demo-bucket/my-jar.jar"
        }
    }        
    ```
* Main reference: https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-studio-magics.html#using-configure-sparkmagic

### 2. Packaged Libraries.

Create a tar.gz archives for packaged libraries, that can be used in the notebook, EMR on EC2, and EMR Serverless.

**Option 1:** Use **virtualenv** to create packages, then upload the archive to S3.

Example using venv:

```
# initialize a python virtual environment
python3 -m venv pyspark_venvsource
source pyspark_venvsource/bin/activate

# optionally, ensure pip is up-to-date
pip3 install --upgrade pip

# install the python packages
pip3 install scipy
pip3 install matplotlib

# package the virtual environment into an archive
pip3 install venv-pack
venv-pack -f -o pyspark_venv.tar.gz

# copy the archive to an S3 location
aws s3 cp pyspark_venv.tar.gz s3://amzn-s3-demo-bucket/EXAMPLE-PREFIX/

# optionally, remove the virtual environment directory
rm -fr pyspark_venvsource
```

**Option 2:** Using **conda**, while specifying Python 3.9 as specific python version.
    
Example using conda:

```
#!/bin/bash

conda create --name myenv python=3.9

conda activate myenv

conda install scipy matplotlib pandas==2.2.3

conda install -c conda-forge conda-pack

conda pack -n myenv -o /path/to/output/myenv.tar.gz
 ```
* Option 1 and 2 references:
    * Main reference https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/using-python-libraries.html
    * EMR serverless specific sample: https://github.com/aws-samples/emr-serverless-samples/tree/main/examples/pyspark/dependencies
* Option 1 and 2 compatibility notes: 
    * Use the same python version with the EMR cluster, as  detailed below.
        ```
        | Python version | EMR version   
        | Python 3.7.    | EMR 6.x       
        | Python 3.9.    | EMR 7.x    
        ```  
**Option 3:** Use **dockerfile** to create packages. 

Example:

```
FROM --platform=linux/amd64 amazonlinux:2 AS base

RUN yum install -y python3

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install \
    great_expectations==0.15.6 \
    venv-pack==0.2.0

RUN mkdir /output && venv-pack -o /output/pyspark_ge.tar.gz

FROM scratch AS export
COPY --from=base /output/pyspark_ge.tar.gz /
```
* Then run the docker command with buildkit enabled, and upload to s3
```
$ DOCKER_BUILDKIT=1 docker build --output . .
$ aws s3 cp pyspark_ge.tar.gz s3://${S3_BUCKET}/artifacts/pyspark/
```
* Option 3 references:
    * EMR Serverless dependencies: https://github.com/aws-samples/emr-serverless-samples/tree/main/examples/pyspark/dependencies
    * Amazon Linux: https://github.com/aws-samples/emr-serverless-samples/blob/main/examples/pyspark/dependencies/Dockerfile
    * Amazon Linux 2023: https://github.com/aws-samples/emr-serverless-samples/blob/main/examples/pyspark/dependencies/Dockerfile.al2023 
* Compatibility notes:
    * Run the virtual env commands in a similar Amazon Linux environment with the same version of Python as you use in EMR Serverless. If using EMR 7.x, you must use Amazon Linux 2023 as the base image instead of Amazon Linux 2.
        ```
        | Python version | EMR version   | Base Image         |
        | Python 3.7.    | EMR 6.x       | Amazon Linux 2     |
        | Python 3.9.    | EMR 7.x       | Amazon Linux 2023  |
        ```

### Use tar.gz archive as imported library in notebook

* Sample notebook: [notebook-import-archive.ipynb](./script/notebook-import-archive.ipynb)
* If you want to package multiple Python libraries within a PySpark kernel, you can also create an isolated Python virtual environment.
* Use spark conf to import tar.gz to the notebook:
```
%%configure -f
{
    "conf":{
        "spark.yarn.appMasterEnv.PYSPARK_PYTHON": "./environment/bin/python",
        "spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON": "./environment/bin/python",
        "spark.executorEnv.PYSPARK_PYTHON": "./environment/bin/python",
        "spark.yarn.dist.archives":"s3://emr-test-xxxxxxxxxx/xldemo/archives/pyspark_ge.tar.gz#environment"
    }
}
```
* Verify whether the environment has been picked up by pyspark. See the example below to show the python location where it already uses the `/environment/bin/python` of the archive.
    ```
        import sys
        print(sys.version)
        print(sys.executable)
    ```
* References:
    * https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-managed-notebooks-installing-libraries-and-kernels.html#emr-managed-notebooks-work-with-libraries

### Use tar.gz archive as spark conf to run an EMR on EC2 job

* Submit the Spark job with your properties set to use the Python virtual environment
```
--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=./environment/bin/python
--conf spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON=./environment/bin/python
--conf spark.yarn.dist.archives=s3://amzn-s3-demo-bucket/prefix/my_pyspark_venv.tar.gz#environment
--conf spark.submit.deployMode=cluster
```


### Use tar.gz archive as spark conf to run an EMR Serverless app

* Submit the Spark job with your properties set to use the Python virtual environment
```
--conf spark.archives=s3://amzn-s3-demo-bucket/EXAMPLE-PREFIX/pyspark_venv.tar.gz#environment 
--conf spark.emr-serverless.driverEnv.PYSPARK_DRIVER_PYTHON=./environment/bin/python
--conf spark.emr-serverless.driverEnv.PYSPARK_PYTHON=./environment/bin/python 
--conf spark.executorEnv.PYSPARK_PYTHON=./environment/bin/python
```
* Reference: https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/using-python-libraries.html

