/*
 * 智慧路灯合并固件 — C3 传感器 + D5 MQTT，对接项目 smart-light/{deviceSn}/…
 * 阶段 D 使用；C3/D5 单独验收通过后再 sync + 烧录本 sample
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "ohos_init.h"
#include "cmsis_os2.h"
#include "wifi_connect.h"
#include "MQTTClient.h"
#include "E53_SC1.h"
#include "streetlight_config.h"

#define TASK_STACK_SIZE 10240

static unsigned char sendBuf[1200];
static unsigned char readBuf[1200];
static Network network;
static MQTTClient client;
static char topicLight[64];
static char topicStatus[64];
static char topicCommand[64];
static E53_SC1_Status_ENUM lampStatus = OFF;
static volatile int pendingCommand = 0;
static char pendingCmdName[16];

static void buildTopics(void)
{
    snprintf(topicLight, sizeof(topicLight), "smart-light/%s/light", DEVICE_SN);
    snprintf(topicStatus, sizeof(topicStatus), "smart-light/%s/status", DEVICE_SN);
    snprintf(topicCommand, sizeof(topicCommand), "smart-light/%s/command", DEVICE_SN);
}

static void publishStatus(void)
{
    MQTTMessage message;
    char payload[128];
    const char *st = (lampStatus == ON) ? "ON" : "OFF";

    snprintf(payload, sizeof(payload),
        "{\"deviceSn\":\"%s\",\"status\":\"%s\",\"timestamp\":\"live\"}", DEVICE_SN, st);
    message.qos = 0;
    message.retained = 0;
    message.payload = payload;
    message.payloadlen = strlen(payload);
    if (MQTTPublish(&client, topicStatus, &message) != 0) {
        printf("publish status failed\n");
    } else {
        printf("published status %s\n", st);
    }
}

static void applyCommand(const char *cmd)
{
    if (strstr(cmd, "ON") != NULL) {
        Light_StatusSet(ON);
        lampStatus = ON;
    } else if (strstr(cmd, "OFF") != NULL) {
        Light_StatusSet(OFF);
        lampStatus = OFF;
    } else {
        return;
    }
    publishStatus();
}

static void messageArrived(MessageData *data)
{
    char buf[160];
    int len = data->message->payloadlen;
    if (len >= (int)sizeof(buf)) {
        len = sizeof(buf) - 1;
    }
    memcpy(buf, data->message->payload, len);
    buf[len] = '\0';
    printf("command arrived: %s\n", buf);
    applyCommand(buf);
}

static int mqttConnectLoop(void)
{
    int rc;
    MQTTString clientId = MQTTString_initializer;
    char clientIdBuf[32];
    snprintf(clientIdBuf, sizeof(clientIdBuf), "bearpi-%s", DEVICE_SN);
    clientId.cstring = clientIdBuf;

    MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
    data.clientID = clientId;
    data.willFlag = 0;
    data.MQTTVersion = 3;
    data.keepAliveInterval = 60;
    data.cleansession = 1;

    NetworkInit(&network);
    NetworkConnect(&network, MQTT_BROKER_IP, MQTT_BROKER_PORT);
    MQTTClientInit(&client, &network, 2000, sendBuf, sizeof(sendBuf), readBuf, sizeof(readBuf));

    rc = MQTTConnect(&client, &data);
    if (rc != 0) {
        printf("MQTTConnect failed: %d\n", rc);
        return rc;
    }
    rc = MQTTSubscribe(&client, topicCommand, 1, messageArrived);
    if (rc != 0) {
        printf("MQTTSubscribe failed: %d\n", rc);
        return rc;
    }
    printf("MQTT connected, subscribed %s\n", topicCommand);
    return 0;
}

static void publishLight(float lux)
{
    MQTTMessage message;
    char payload[160];
    snprintf(payload, sizeof(payload),
        "{\"deviceSn\":\"%s\",\"lightIntensity\":%.2f,\"timestamp\":\"live\"}", DEVICE_SN, lux);
    message.qos = 0;
    message.retained = 0;
    message.payload = payload;
    message.payloadlen = strlen(payload);
    if (MQTTPublish(&client, topicLight, &message) != 0) {
        printf("publish light failed\n");
    } else {
        printf("published light %.2f\n", lux);
    }
}

static void StreetlightTask(void)
{
    float lux;
    int reportTicks = 0;

    buildTopics();
    E53_SC1_Init();

    if (WifiConnect(WIFI_SSID, WIFI_PSK) != 0) {
        printf("WiFi connect failed\n");
        return;
    }

    while (mqttConnectLoop() != 0) {
        osDelay(3000);
    }

    while (1) {
        MQTTYield(&client, 500);

        reportTicks++;
        if (reportTicks >= LIGHT_REPORT_SEC * 2) {
            reportTicks = 0;
            lux = E53_SC1_Read_Data();
            printf("Lux: %.2f\n", lux);
            publishLight(lux);
        }
        osDelay(500);
    }
}

static void StreetlightEntry(void)
{
    osThreadAttr_t attr = {0};
    attr.name = "StreetlightTask";
    attr.stack_size = TASK_STACK_SIZE;
    attr.priority = osPriorityNormal;
    if (osThreadNew((osThreadFunc_t)StreetlightTask, NULL, &attr) == NULL) {
        printf("Failed to create StreetlightTask\n");
    }
}

APP_FEATURE_INIT(StreetlightEntry);
