#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>

// 定义与Bluespec结构体对齐的数据结构
#pragma pack(push, 1) // 禁用内存对齐，确保与FPGA侧严格匹配

//typedef struct {
//    uint32 x1;
//    uint32 x2;
//}
typedef struct {
    uint16_t srcMacId:10;  //10位
    uint16_t dstMacId:10;  //10位
    struct {
        uint16_t power:12;   //12位
        uint16_t mcs:4;     //4位
    } rfParam;
    struct {
        uint8_t frametype:4;  // 2位
        uint8_t  framesubtype:4;  //4位
        uint16_t duration;  //16位
        uint16_t mpdulen;   //16位
        uint64_t mpducacheaddr; //64位
    } mpduDigest;
    uint8_t status:1;       //1位
} MacEvent;
#pragma pack(pop) // 恢复默认对齐

#define DEVICE_H2C "/dev/xdma0_h2c_0" // Host-to-Card 通道设备文件
#define DEVICE_C2H "/dev/xdma0_c2h_0" // Card-to-Host 通道设备文件
#define BURST_SIZE 1

//x1 = id1 | (id2 << 10);
int main() {
    int h2c_fd = open(DEVICE_H2C, O_RDWR); // 打开 H2C 设备
    int c2h_fd = open(DEVICE_C2H, O_RDWR); // 打开 C2H 设备

    if (h2c_fd < 0 || c2h_fd < 0) {
        perror("Failed to open XDMA device");
        return -1;
    }

    // 分配对齐的内存缓冲区（DMA 要求）
    size_t buf_size = sizeof(MacEvent) * BURST_SIZE;
    MacEvent *rx_buf = (MacEvent*)aligned_alloc(512, buf_size);
    MacEvent *tx_buf = (MacEvent*)aligned_alloc(512, buf_size);

    // 初始化测试数据（示例：递增序列）
    for (int i = 0; i < BURST_SIZE; i++) {
        tx_buf[i].srcMacId = 0x0;                 
        tx_buf[i].dstMacId = 0x1;                
        tx_buf[i].rfParam.power = 31*32;          
        tx_buf[i].rfParam.mcs = 0;       
        tx_buf[i].mpduDigest.frametype = 2; 
        tx_buf[i].mpduDigest.framesubtype = 0;
        tx_buf[i].mpduDigest.duration = 0;
        tx_buf[i].mpduDigest.mpdulen = 2048;            
        tx_buf[i].mpduDigest.mpducacheaddr = 0;       
        //tx_buf[i].status = 0;
    }
    memset(rx_buf, 0, BUFFER_SIZE);


        // 通过 H2C 通道发送数据
    ssize_t written = write(h2c_fd, tx_buf, BUFFER_SIZE);
    if (written != BUFFER_SIZE) {
        perror("H2C write failed");
        return -1;
    }
    printf("Sent %zd bytes to FPGA\n", written);

        // 通过 C2H 通道接收数据
    ssize_t read_bytes = read(c2h_fd, rx_buf, BUFFER_SIZE);
    if (read_bytes != BUFFER_SIZE) {
        perror("C2H read failed");
        return -1;
    }
    printf("Received %zd bytes from FPGA\n", read_bytes);

        // 验证数据一致性
    int errors = 0;
    for (int i = 0; i < BUFFER_SIZE / sizeof(int); i++) {
        int expected = i; // 根据您的 CSMA 逻辑调整预期值
        if (((int*)rx_buf)[i] != expected) {
            printf("Error at index %d: Expected %d, Got %d\n", 
                   i, expected, ((int*)rx_buf)[i]);
            errors++;
        }
    }

    if (errors == 0) {
        printf("Test passed!\n");
    } else {
        printf("Test failed with %d errors\n", errors);
    }

    // 清理资源
    close(h2c_fd);
    close(c2h_fd);
    free(tx_buf);
    free(rx_buf);
    return 0;
}