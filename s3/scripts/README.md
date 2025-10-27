<!--
Copyright 2025 Ameenah Burhan (aburhan)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# AWS S3 to Google Cloud Storage Migration Demo

## AWS S3 Inventory and Athena Automation Setup

Automated scripts to set up an AWS environment with S3 buckets, inventory reporting, and Athena querying capabilities for testing and demonstration purposes.

1. Set up a demo AWS environment with S3 buckets, test files, and inventory reporting.

2. Generate credentials for an existing AWS IAM user.

3. Configure a Google Cloud Storage Transfer Service job using Google Cloud Shell, securely storing the AWS credentials in Secret Manager.

## Prerequisites

- AWS:

  - An AWS admin user account with permissions to create S3 buckets and manage IAM.

  - An AWS Access Key ID and AWS Secret AccessKey for your admin user to run the AWS CLI.

  - An existing IAM user named storage-transfer-user with the AmazonS3ReadOnlyAccess policy attached.

- Google Cloud:

  - A Google Cloud project.

  - The Google Cloud SDK (gcloud) or access to the Google Cloud Shell.

## Steps

### Part 1: Create the AWS Demo Environment

1. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

1. Verify AWS CLI version

    ```sh
    aws --version
    ```

1. Configure AWS Credentials

    ```sh
    aws configure
    ```

    Provide:

    - AWS Access Key ID [None]: [YOUR `AWS Access Key ID`]
    - AWS Secret Access Key [None]: [YOUR `AWS Secret Access Key`]
    - Default region name [None]: ex. us-east-1
    - Default output format [None]: [Select default]

1. create the S3 buckets and generate test data

    ```sh
    export BUCKET_NAME="mmb-$(date +%s)"
    export AWS_REGION="us-east-2"
    export PROJECT_TAG="mmb"
    export COST_CENTER_TAG="1234"

    ./setup-s3-demo.sh
    ./get-s3-object-details.sh $BUCKET_NAME csv > migration-inventory.csv
    ```

    **note:** When prompted "This script will create AWS resources that may incur costs". Enter `yes`

    This script will create an inventory file of S3 objects from the AWS bucket in a local file called `migration-inventory.csv`

1. Setup federated service account

    ```sh
    export PROJECT_ID="YOUR GCP PROJECT ID"

    gcloud config set project $PROJECT_ID
    export ACCESS_TOKEN=$(gcloud auth print-access-token)
    curl -X GET "https://storagetransfer.googleapis.com/v1/googleServiceAccounts/$PROJECT_ID" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Content-Type: application/json"
    ```

    example output:

    ```json
    {
    "accountEmail": "project-123456789012@storage-transfer-service.iam.gserviceaccount.com",
    "subjectId": "112233445566778899001"
    }
    ```

    copy the the value of the subjectId example 112233445566778899001

1. navigate back to the AWS console and navigate to the AWS Console > IAM >Roles >Create role

1. Select 'Custom trust policy

1. In the custom trust policy paste the following:

    ```json
    {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Federated": "accounts.google.com"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
            "StringEquals": {
            "accounts.google.com:sub": "[SUBJECT_ID]"
            }
        }
        }
    ]
    }
    ```

    replace `SUBJECT_ID` with your subject id

1. Click Next

1. In the Add permissions section, search and select attach the permissions
    `AmazonS3ReadOnlyAccess` and click Next

1. Create a role name and description 
mmb-migration-gcp-role, Role to grant read acces to stroage transfer and click `Create role`.

1. On the main page click on the role just created and copy the ARN

### Part 2: Configure Google Cloud Storage Transfer