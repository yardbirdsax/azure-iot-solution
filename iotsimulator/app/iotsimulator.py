#!/usr/bin/env python
import re
import yaml
import time
import os
from datetime import datetime
import pytz
import iothub_client
# pylint: disable=E0611
from iothub_client import IoTHubClient, IoTHubClientError, IoTHubTransportProvider, IoTHubClientResult
from iothub_client import IoTHubMessage, IoTHubMessageDispositionResult, IoTHubError, DeviceMethodReturnValue
from socket import gethostname
import random

def iothub_client_init():
    client = IoTHubClient(connection_string,CONST_IOT_PROTOCOL)
    return client

def send_confirmation_callback(message, result, user_context):
    global SEND_ERRORS
    result_str = "%s" % result
    if result_str == "OK":
        SEND_ERRORS = 0
        log ( "IoT Hub responded to message with status: %s" % (result) ) 
    else:
        SEND_ERRORS += 1
        log("IoTHub responed with error status: %s. Current error count is %i." % (result,SEND_ERRORS))


    if (SEND_ERRORS > max_send_errors):
        log ("Maxium consecutive send error count (%i) exceeded. Program will now exit." % max_send_errors)
        exit(1)

def log(message):
    formatted_datetime = datetime.utcnow().replace(tzinfo=pytz.utc).strftime("%Y-%m-%dT%H:%m:%S%z")
    print("[%s]\t%s" % (formatted_datetime,message))

# Read configurations
connection_string = os.environ.get('iot_connection_string')
temp_max = int(os.environ.get('iot_temp_max',default=90))
temp_min = int(os.environ.get('iot_temp_min',default=95))
if (connection_string is None):
    log("Required environment variable 'iot_connection_string' is not set. Application will exit.")
    exit(1)
send_interval = os.getenv('send_interval',10)
max_send_errors = os.getenv('max_send_errors',100)

# Constants
CONST_HOST_NAME = gethostname()
CONST_MSG_TEXT = "{\"device\":\"%s\",\"temp\":%.2f,\"datetime\":\"%s\"}"
CONST_IOT_PROTOCOL = IoTHubTransportProvider.MQTT
CONST_STR_OK = "OK"

SEND_CALLBACKS = 0
SEND_ERRORS = 0

connection_string_redact = re.sub("AccessKey=.+","AccessKey=xxxxx",connection_string)
log("Connection string is %s" % connection_string_redact)

while True:
    client = iothub_client_init()
    temp = random.uniform(temp_min,temp_max)

    formatted_datetime = datetime.utcnow().replace(tzinfo=pytz.utc).strftime("%Y-%m-%dT%H:%m:%S%z")
    formatted_msg = CONST_MSG_TEXT % (CONST_HOST_NAME,temp,formatted_datetime)
    hub_msg = IoTHubMessage(formatted_msg)

    log("Sending message: %s" % hub_msg.get_string())
    client.send_event_async(hub_msg,send_confirmation_callback,None)

    time.sleep(send_interval)
