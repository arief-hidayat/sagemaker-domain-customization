# Notebook Configuration for EMR Serverless


An Amazon EMR notebook is a serverless Jupyter notebook. It uses the Sparkmagic kernel as a client to execute the code through an Apache Livy server. The Sparkmagic project includes a set of commands for interactively running Spark code in multiple languages, as well as some kernels that you can use to turn Jupyter into an integrated Spark environment. Use 
%%configure  to add the required configuration before you run your first spark-bound code cell and avoid trouble with the cluster-wide spark configurations


```
%%configure -f
{
  "executorMemory": "4G",
  "executorCores": 2,
  "driverMemory": "2G",
  "driverCores": 1,
  "conf": {
    "spark.dynamicAllocation.enabled": "true",
    "spark.sql.shuffle.partitions": "100"
  }
}
```

List of the configure can be viewed with `%%help` command, or in this link https://github.com/cloudera/livy#request-body.
If you want to add more specific configurations that goes with --conf command, use a nested JSON object:

```
%%configure -f
{
  "executorMemory": "4G",
  "executorCores": 2,
  "driverMemory": "2G",
  "driverCores": 1,
  "conf": {
    "spark.dynamicAllocation.enabled": "true",
    "spark.sql.shuffle.partitions": "100",
    "spark.archives": "s3://emr-test-11701913xxxx/xldemo/archives/pyspark_ge.tar.gz#environment",
    "spark.emr-serverless.driverEnv.PYSPARK_DRIVER_PYTHON": "./environment/bin/python",
    "spark.emr-serverless.driverEnv.PYSPARK_PYTHON": "./environment/bin/python",
    "spark.executorEnv.PYSPARK_PYTHON": "./environment/bin/python"
  }
}
```

