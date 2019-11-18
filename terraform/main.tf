provider azurerm {
  version = "=1.36.0"
}

locals {
  iotHubName = "${var.resourceGroupName}iothub"
  storageAccountName = lower(replace(var.resourceGroupName,"-",""))
  storageContainerName = "iothub"
  eventHubName = "${lower(replace(var.resourceGroupName,"-",""))}eventhub"
}

resource azurerm_resource_group "group" {
  location = var.location
  name = var.resourceGroupName
}

resource azurerm_storage_account "storageAccount" {
  resource_group_name = azurerm_resource_group.group.name
  location = azurerm_resource_group.group.location
  name = local.storageAccountName

  account_kind = "StorageV2"
  account_replication_type = "LRS"
  account_tier = "Standard"
  is_hns_enabled = true
}

resource azurerm_storage_container "container" {
  name = local.storageContainerName
  storage_account_name = azurerm_storage_account.storageAccount.name
}

resource azurerm_app_service_plan "appPlan" {
  resource_group_name = azurerm_resource_group.group.name
  location = azurerm_resource_group.group.location
  name = azurerm_resource_group.group.name

  kind = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource azurerm_function_app "functionApp" {
  name = "alerter"
  location = azurerm_app_service_plan.appPlan.location
  resource_group_name = azurerm_resource_group.group.name
  app_service_plan_id = azurerm_app_service_plan.appPlan.id
  storage_connection_string = azurerm_storage_account.storageAccount.primary_connection_string
  version = "2"
}

resource azurerm_iothub "iotHub" {
  resource_group_name = azurerm_resource_group.group.name
  location = azurerm_resource_group.group.location
  name = local.iotHubName

  sku {
    capacity = 1
    name = "F1"
    tier = "Free"
  }

  endpoint {
    type = "AzureIotHub.StorageContainer"
    name = "storage"
    connection_string = azurerm_storage_account.storageAccount.primary_blob_connection_string
    container_name = azurerm_storage_container.container.name
    file_name_format = "{iothub}/{YYYY}-{MM}-{DD}/{HH}-{mm}-{partition}"
    encoding = "avro"
    batch_frequency_in_seconds = 60
    max_chunk_size_in_bytes = 314572800
  }

  route {
    enabled = true
    name = "device2events"
    source = "DeviceMessages"
    endpoint_names = ["events"]
  }

  route {
    enabled = true
    name = "device2storage"
    source = "DeviceMessages"
    endpoint_names = ["storage"]
  }
}

resource azurerm_iothub_consumer_group "consumerGroup" {
  eventhub_endpoint_name = "events"
  iothub_name = local.iotHubName
  name = "streamanalytics"
  resource_group_name = azurerm_iothub.iotHub.resource_group_name
}

resource azurerm_iothub_shared_access_policy "accessPolicy" {
  iothub_name = local.iotHubName
  resource_group_name = azurerm_iothub.iotHub.resource_group_name
  service_connect = true
  name = "streamanalytics"
}

resource azurerm_stream_analytics_job "streamAnalytics" {
  resource_group_name = azurerm_resource_group.group.name
  location = azurerm_resource_group.group.location
  name = azurerm_resource_group.group.name

  compatibility_level = "1.1"
  data_locale = "en-US"
  streaming_units = 1

  transformation_query = <<QUERY
WITH AnomalyDetection AS (
SELECT device
       ,datetime
       ,temp
       ,AnomalyDetection_ChangePoint(temp,80,12) OVER(PARTITION BY device LIMIT DURATION(minute,30)) as ChangePointScore
  FROM [IotHub]
  TIMESTAMP BY datetime
),
Results AS (
  SELECT datetime
        ,device
        ,temp
        ,CAST(GetRecordPropertyValue(ChangePointScore,'Score') as float) as AnomalyScore
        ,CAST(GetRecordPropertyValue(ChangePointScore,'IsAnomaly') as bigint) as IsAnomaly
    FROM AnomalyDetection
)
SELECT datetime, device, temp, AnomalyScore
  INTO Anomalies
  FROM Results
 WHERE IsAnomaly = 1
QUERY
}

resource azurerm_stream_analytics_stream_input_iothub "streamInput" {
  resource_group_name = azurerm_resource_group.group.name
  name = "IotHub"
  eventhub_consumer_group_name = "streamanalytics"
  iothub_namespace = azurerm_iothub.iotHub.name
  endpoint = "messages/events"
  stream_analytics_job_name = azurerm_stream_analytics_job.streamAnalytics.name
  shared_access_policy_key = azurerm_iothub_shared_access_policy.accessPolicy.primary_key
  shared_access_policy_name = azurerm_iothub_shared_access_policy.accessPolicy.name

  serialization {
    encoding = "UTF8"
    type = "Json"
  }
}

resource azurerm_eventhub_namespace "eventHubNamespace" {
  name = local.eventHubName
  resource_group_name = azurerm_resource_group.group.name
  location = azurerm_resource_group.group.location
  sku = "Basic"
  capacity = 1
}

resource azurerm_eventhub "eventHub" {
  name = "anomalies"
  namespace_name = azurerm_eventhub_namespace.eventHubNamespace.name
  resource_group_name = azurerm_eventhub_namespace.eventHubNamespace.resource_group_name

  partition_count = 1
  message_retention = 1
}

resource azurerm_eventhub_authorization_rule "authRule" {
  eventhub_name = azurerm_eventhub.eventHub.name
  send = true
  namespace_name = azurerm_eventhub_namespace.eventHubNamespace.name
  resource_group_name = azurerm_eventhub_namespace.eventHubNamespace.resource_group_name
  name = "StreamAnalytics"
}

resource azurerm_stream_analytics_output_eventhub "eventHubOutput" {
  name = "Anomalies"
  servicebus_namespace = azurerm_eventhub_namespace.eventHubNamespace.name
  eventhub_name = azurerm_eventhub.eventHub.name
  shared_access_policy_key = azurerm_eventhub_authorization_rule.authRule.primary_key
  shared_access_policy_name = azurerm_eventhub_authorization_rule.authRule.name
  stream_analytics_job_name = azurerm_stream_analytics_job.streamAnalytics.name
  resource_group_name = azurerm_eventhub.eventHub.resource_group_name
  serialization {
    type = "Json"
    encoding = "UTF8"
    format = "Array"
  }
}

