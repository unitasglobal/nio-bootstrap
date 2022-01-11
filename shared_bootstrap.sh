#!/bin/bash

# Ensure AWSCLIv2 is installed and accessible
AWS_VERSION=$(aws --version | awk '{ print $1 }' | awk -F'/' '{ print $NF }')
if [[ "$AWS_VERSION" == 2* ]]; then
    echo "AWSCLI v2 already installed"
else
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
fi

# Check if logged in, and if not, start login prompt
aws configure list >/dev/null 2>&1 || aws sso login

# Setup private PyPI repository
poetry config repositories.nio "$(aws ssm get-parameter --name '/nio/production/pypi/url' --with-decryption | jq -r '.Parameter.Value')"
poetry config http-basic.nio \
    "$(aws ssm get-parameter --name '/nio/default/pypi/username' --with-decryption | jq -r '.Parameter.Value')" \
    "$(aws ssm get-parameter --name '/nio/default/pypi/password' --with-decryption | jq -r '.Parameter.Value')"

# Setup private development PyPI repository
poetry config repositories.nio-dev "$(aws ssm get-parameter --name '/nio/development/pypi/url' --with-decryption | jq -r '.Parameter.Value')"
poetry config http-basic.nio-dev \
    "$(aws ssm get-parameter --name '/nio/default/pypi/username' --with-decryption | jq -r '.Parameter.Value')" \
    "$(aws ssm get-parameter --name '/nio/default/pypi/password' --with-decryption | jq -r '.Parameter.Value')"

# Allow the Python setup to be bypassed
if [ ! -z "${NO_JGT_SETUP+x}" ]; then
    echo "Bypassing JGT setup"
    exit 0
fi
curl -L https://github.com/jolly-good-toolbelt/jgt_tools/raw/master/env_setup.py | python3

# Several libraries have not been creating their distros correctly and causing a `tests`
# folder to be added to the root folder of `site-packages`, breaking `run test`. While
# we make a best effort to submit PRs to help those libraries follow best packaging
# practices, we don't want them to break out test suite, thus the `rm -rf`.
SITE_PACKAGES=$(poetry run python -c "import site; print(site.getsitepackages()[0])")
rm -rf "$SITE_PACKAGES"/tests
