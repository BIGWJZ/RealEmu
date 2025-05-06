#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#pragma pack(push, 1) // 禁用内存对齐，确保与FPGA侧严格匹配
typedef struct {
    uint16_t srcMacId:10;  //10位
    uint16_t dstMacId:10;  //10位
    struct {
        uint16_t power:12;   //12位
        uint16_t mcs:4;     //4位
    } rfParam;
    struct {
        uint8_t frametype:2;  // 2位
        uint8_t  framesubtype:4;  //4位
        uint16_t duration;  //16位
        uint16_t mpdulen;   //16位
        uint64_t mpducacheaddr; //64位
    } mpduDigest;
    uint8_t status:1;       //1位
} MacEvent;
#pragma pack(pop) // 恢复默认对齐

#define BURST_SIZE 1

void printMacEvent(const MacEvent *event) {
    printf("srcMacId: 0x%X\n", event->srcMacId);
    printf("dstMacId: 0x%X\n", event->dstMacId);
    printf("rfParam.power: 0x%X\n", event->rfParam.power);
    printf("rfParam.mcs: 0x%X\n", event->rfParam.mcs);
    printf("mpduDigest.frametype: 0x%X\n", event->mpduDigest.frametype);
    printf("mpduDigest.framesubtype: 0x%X\n", event->mpduDigest.framesubtype);
    printf("mpduDigest.duration: 0x%X\n", event->mpduDigest.duration);
    printf("mpduDigest.mpdulen: 0x%X\n", event->mpduDigest.mpdulen);
    printf("mpduDigest.mpducacheaddr: 0x%lX\n", event->mpduDigest.mpducacheaddr);
    printf("status: 0x%X\n", event->status);
}

// 打印整个结构体的内存内容（十六进制）
void printMacEventRaw8(const MacEvent *event) {
    const uint8_t *bytes = (const uint8_t *)event;  // 转换为字节指针
    size_t size = sizeof(MacEvent);

    printf("MacEvent Raw Data (%zu bytes):\n", size);
    for (size_t i = 0; i < size; i++) {
        printf("%02X ", bytes[i]);  // 按字节打印十六进制
        if ((i + 1) % 8 == 0) printf("\n");  // 每8字节换行
    }
    printf("\n");
}

int main() {
    size_t buf_size = sizeof(MacEvent) * BURST_SIZE;
    MacEvent *tx_buf = (MacEvent*)aligned_alloc(512, buf_size);

    // 初始化测试数据（示例：递增序列）
    for (int i = 0; i < BURST_SIZE; i++) {
        tx_buf[i].srcMacId = 0x1F1;                 
        tx_buf[i].dstMacId = 0x001;                
        tx_buf[i].rfParam.power = 31*32;          
        tx_buf[i].rfParam.mcs = 0;       
        tx_buf[i].mpduDigest.frametype = 2; 
        tx_buf[i].mpduDigest.framesubtype = 0;
        tx_buf[i].mpduDigest.duration = 0;
        tx_buf[i].mpduDigest.mpdulen = 2048;            
        tx_buf[i].mpduDigest.mpducacheaddr = 0;       
        //tx_buf[i].status = 0;
    }

    //printMacEvent(tx_buf);
    printMacEventRaw8(tx_buf);
    printf("MacEvent size: %zu bytes\n", sizeof(MacEvent));
    printf("MacEvent alignment: %zu bytes\n", _Alignof(MacEvent));

    return 0;
}