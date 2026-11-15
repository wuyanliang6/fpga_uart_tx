//=============================================================================
// 文件名   : uart_tx.v
// 功能     : UART 发送一个字节（8 数据位 + 起始位 + 停止位 = 10 位帧）
// 说明     : 这是"线性序列机"的第 2 个例子，和第 3 讲的 TLV5618 驱动是同一个骨架
//            —— 时间切成 0~9 格，每格该给什么值就照着写。
// 与第3讲的区别:
//            1) TLV5618 是 MSB first（D15 先出）；UART 是 LSB first（D0 先出）
//            2) TLV5618 有自己的 SCLK 线；UART 没有时钟线，全靠双方约定波特率
//            3) TLV5618 一格 = DIV_PARAM 个时钟；UART 一格 = CLOCK_FREQ/BAUD 个时钟
//=============================================================================
`timescale 1ns/1ns

module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,   // 系统时钟频率（Hz）
    parameter BAUD       = 9600          // 波特率（bit/s）
)(
    input               Clk,
    input               Rst_n,
    input               Send_Go,         // 单拍脉冲：请求发送（忙时会被忽略）
    input       [7:0]   Data,            // 要发的字节
    output reg          Uart_Tx,         // 串行输出线（空闲为高）
    output reg          Tx_Done          // 单拍脉冲：这一帧发完了
);

    //-------------------------------------------------------------------------
    // 1. 两个常量：一位要数多少拍 / 一帧要发多少位
    //-------------------------------------------------------------------------
    localparam MCNT_BAUD = CLOCK_FREQ / BAUD - 1;   // 9600 时 = 5207
    localparam MCNT_BIT  = 10 - 1;                  // 0~9 共 10 位

    // 计数器位宽：能数到 MCNT_BAUD 就行，不许多也不许少
    localparam BW = $clog2(MCNT_BAUD + 1);          // 5208 → 13 位

    //-------------------------------------------------------------------------
    // 2. 内部信号
    //-------------------------------------------------------------------------
    reg [BW-1:0]  baud_cnt;     // 位内计数器：数满一位
    reg [3:0]     bit_cnt;      // 位计数器：现在是第几位（0~9）
    reg           sending;      // 在发吗
    reg [7:0]     r_data;       // 锁存进来的数据

    wire bit_end = (baud_cnt == MCNT_BAUD);         // 一位的最后一拍
    wire frame_end = sending && bit_end && (bit_cnt == MCNT_BIT);

    //-------------------------------------------------------------------------
    // 3. 块 1：sending —— 什么时候开始、什么时候结束
    //    这条就是第 3 讲的 en（在发吗），一模一样
    //-------------------------------------------------------------------------
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            sending <= 1'b0;
        else if (Send_Go && !sending)                   // 空闲时才接受请求
            sending <= 1'b1;
        else if (frame_end)
            sending <= 1'b0;
    end

    //-------------------------------------------------------------------------
    // 4. 块 2：baud_cnt —— 位内的小数数，0 ~ MCNT_BAUD
    //-------------------------------------------------------------------------
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            baud_cnt <= {BW{1'b0}};
        else if (!sending)                     // 没在发就清零
            baud_cnt <= {BW{1'b0}};
        else if (bit_end)                      // 数满一位，归零重数
            baud_cnt <= {BW{1'b0}};
        else
            baud_cnt <= baud_cnt + 1'b1;
    end

    //-------------------------------------------------------------------------
    // 5. 块 3：bit_cnt —— 位计数器，0 ~ 9
    //-------------------------------------------------------------------------
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            bit_cnt <= 4'd0;
        else if (!sending)
            bit_cnt <= 4'd0;
        else if (bit_end) begin
            if (bit_cnt == MCNT_BIT)           // 第 9 位发完，下一拍回 0
                bit_cnt <= 4'd0;
            else
                bit_cnt <= bit_cnt + 1'b1;
        end
    end

    //-------------------------------------------------------------------------
    // 6. 块 4：r_data —— 在起始那一刻把 Data 锁进寄存器
    //    为什么要锁：万一上层在发送途中改了 Data，这一帧就不会被改坏
    //-------------------------------------------------------------------------
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            r_data <= 8'd0;
        else if (Send_Go && !sending)
            r_data <= Data;
    end

    //-------------------------------------------------------------------------
    // 7. 块 5：Uart_Tx —— 照表赋值（这一块就是 10 格的时间表）
    //
    //    bit_cnt = 0      →  0        起始位
    //    bit_cnt = 1..8   →  r_data[0..7]   LSB first
    //    bit_cnt = 9      →  1        停止位
    //-------------------------------------------------------------------------
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            Uart_Tx <= 1'b1;                   // 空闲为高
        else if (!sending)
            Uart_Tx <= 1'b1;
        else begin
            case (bit_cnt)
                4'd0: Uart_Tx <= 1'b0;         // 起始位
                4'd1: Uart_Tx <= r_data[0];
                4'd2: Uart_Tx <= r_data[1];
                4'd3: Uart_Tx <= r_data[2];
                4'd4: Uart_Tx <= r_data[3];
                4'd5: Uart_Tx <= r_data[4];
                4'd6: Uart_Tx <= r_data[5];
                4'd7: Uart_Tx <= r_data[6];
                4'd8: Uart_Tx <= r_data[7];
                4'd9: Uart_Tx <= 1'b1;         // 停止位
                default: Uart_Tx <= 1'b1;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // 8. 块 6：Tx_Done —— 发完的那一拍给一个脉冲
    //    注意：这里打了寄存器，所以是干净的 1 拍脉冲
    //-------------------------------------------------------------------------
    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n)
            Tx_Done <= 1'b0;
        else
            Tx_Done <= frame_end;
    end

endmodule
