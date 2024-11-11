#!/bin/bash

Help()
{
   # Display Help
   echo "Create tar file from a given requirements.txt and copy to s3 bucket"
   echo
   echo "options:"
   echo "h  Print this Help."
   echo "r  Install from the given requirements file. default: ./requirements.txt"
   echo "v  Python version. default: 3.9.16"
   echo "s  s3 path. if not specified, not copying to s3 bucket."
   echo "n  Name of the tar file. default: venv_<date>_<time>"
   echo
}
# Variable to store requirement file
req_file="./requirements.txt"
s3_path=""
py_version="3.9.16"
curr_date=$(date +%Y-%m-%d_%H-%M-%S)
venv_name="venv_${curr_date}"
while getopts ":v:r:s:n:h" option; do
    case $option in
        h) # display Help
             Help
             exit 0;;
        v) # version of python
             py_version=$OPTARG;;
        r) # requirement file
             req_file=$OPTARG;;
        s) # s3 target path
             s3_path=$OPTARG;;
        n) # name of the tar file
             venv_name=$OPTARG;;
        *) # invalid option
             echo "Error: Invalid option"
             exit;;
    esac
done

if [[ ! -f "$req_file" ]]; then
    echo "Error: Requirement file not found"
    exit 1
fi
# Try to create and set up virtual environment
curr_dir=$(pwd)
mkdir -p $curr_dir/$venv_name
(
    cp $req_file $curr_dir/$venv_name/$req_file
    cd $curr_dir/$venv_name
    pyenv virtualenv $py_version $venv_name
    . ${PYENV_ROOT}/versions/$venv_name/bin/activate
    pip install --upgrade pip
    pip install -r $req_file
    pip install venv-pack
    venv-pack -f -o "${curr_dir}/${venv_name}.tar.gz"
    chmod 777 "${curr_dir}/${venv_name}.tar.gz"
    if [[ -n "$s3_path" ]]; then
        aws s3 cp "${curr_dir}/${venv_name}.tar.gz" "${s3_path}/${venv_name}.tar.gz"
    fi
    cd $curr_dir
    rm -rf $curr_dir/$venv_name
) || {
    echo "Error: Failed to create/setup virtual environment"
    cd $curr_dir
    rm -rf $curr_dir/$venv_name
    exit 1
}