# Sample IoT Streaming Data Solution

This repository contains code showing how to build a simple streaming IoT temperature sensor data solution using Microsoft Azure. Components include:

* [Azure IoT Hub](https://azure.microsoft.com/en-us/services/iot-hub/), for receiving data sent from IoT devices.
* [Azure Stream Analytics](https://azure.microsoft.com/en-us/services/stream-analytics/), for processing data sent to the IoT Hub and detecting anomalies.
* [Azure Event Hub](https://azure.microsoft.com/en-us/services/event-hubs/), for receiving messages from Stream Analytics when anomalies are detected, for downstream processing.
* [Azure Data Lake Storage](https://azure.microsoft.com/en-us/services/storage/data-lake-storage/), for storing raw data sent to the IoT Hub for possible later analysis.

## Pre-Requisites for Deployment

* You must have [Terraform](https://terraform.io) installed. These directions assume a basic understanding of how to edit [Terraform variable (.tfvars) files](https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files).
* You must have an Azure subscription.
* You must be logged in to the Azure subscription using the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli) in a command prompt session where you'll run the remaining steps.

To use the provided IoT Simulator application, you must also have Docker installed.

## Deploying the Solution

* On a command prompt, navigate to the `terraform` directory in the repository folder.
* Make a copy of the `default.tfvars` file, and edit the following values:
  * **resourceGroupName:** This should be set to a unique value, as it will be used for creating the resource group and for constructing the name of other components. Suggestions would include `<your initials>iotlab<your birthday in yyyy-MM-dd format>`. For example: for someone named "Joe A Schmo" with a birthday of January 1, 1990, the name would be `jasiotlab19900101`.
  * **location:** This should be set to the Azure region closest to you. A list of Azure regions can be found [here](https://azure.microsoft.com/en-us/global-infrastructure/regions/).
* Execute the following command to create all resources:
  
  ```bash
  terraform apply -var-file=<.tfvars file path> -auto-approve
  ```

  >**NOTE: Generally speaking the use of the `-auto-approve` flag is a BAD idea; here it's okay as we're just creating lab resources from scratch.**

This should create all the resources.
