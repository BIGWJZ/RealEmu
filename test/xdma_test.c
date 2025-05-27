#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>
#include <errno.h>

// 定义与Bluespec结构体对齐的数据结构
#pragma pack(push, 1) // 禁用内存对齐，确保与FPGA侧严格匹配

//typedef struct {
//    uint32 x1;
//    uint32 x2;
//}
typedef struct {
    uint16_t srcMacId;  //16位
    uint16_t dstMacId;  //16位
    struct {
        uint16_t power:12;   //12位
        uint16_t mcs:4;     //4位
    } rfParam;
    struct {
        uint8_t frametype:4;  // 4位
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
    printf("open success!\n");
    // 修改缓冲区分配和初始化
    size_t buf_size = 64; // 固定512字节
    MacEvent *rx_buf = (MacEvent*)aligned_alloc(4096, buf_size); // 使用更大的对齐
    uint8_t *tx_buf = (uint8_t*)aligned_alloc(4096, buf_size); // 改为uint8_t类型
    if (!rx_buf || !tx_buf) {
        perror("Memory allocation failed");
        close(h2c_fd);
        close(c2h_fd);
        return -1;
    }
    memset(tx_buf, 0, buf_size);

    // 直接填充数据0 80 00 00 00 20 3e 00 04 00
    uint8_t data[20] = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x10, 0x28, 0x00, 0x40, 0x00, 0x7c, 0x02,
        0x00, 0x00, 0x00, 0x00
    };

    memcpy(tx_buf, data, sizeof(data)); // 将数据复制到tx_buf

    // 确保结构体大小与传输大小匹配
    if (sizeof(MacEvent) > buf_size) {
        printf("MacEvent size %zu exceeds buffer size %zu\n", sizeof(MacEvent), buf_size);
        close(h2c_fd);
        close(c2h_fd);
        free(tx_buf);
        free(rx_buf);
        return -1;
    }

        // 通过 C2H 通道接收数据

	if (fork() == 0) {
                ssize_t read_bytes = read(c2h_fd, rx_buf, buf_size);
                printf("Received %zd bytes from FPGA\n", read_bytes);
                MacEvent *event = (MacEvent*)rx_buf;
                printf("MacEvent data:\n");
                printf("  srcMacId: 0x%x\n", event->srcMacId);
                printf("  dstMacId: 0x%x\n", event->dstMacId);
                printf("  rfParam.power: %u\n", event->rfParam.power);
                printf("  rfParam.mcs: %u\n", event->rfParam.mcs);
                printf("  mpduDigest.frametype: %u\n", event->mpduDigest.frametype);
                printf("  mpduDigest.mpducacheaddr: 0x%lx\n", event->mpduDigest.mpducacheaddr);
                return 0;
        }
    else {
        ssize_t written = write(h2c_fd, tx_buf, buf_size);
        if (written < 0) {
            perror("H2C write failed");
            printf("Error details: %s\n", strerror(errno));
        } else {
            printf("Sent %zd bytes to FPGA\n", written);
        }
        sleep(2);
    }
    /*
    if (read_bytes != buf_size) {
        perror("C2H read failed");
        return -1;
    }*/


        // 验证数据一致性
    close(h2c_fd);
    close(c2h_fd);
    free(tx_buf);
    free(rx_buf);
    return 0;
}
