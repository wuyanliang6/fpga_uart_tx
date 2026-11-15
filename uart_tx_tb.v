//=============================================================================
// 文件名   : uart_tx_tb.v
// 功能     : 自检式测试平台 —— 不光"跑起来"，还要"自己判对错"
// 用法     : 把 uart_tx.v 和本文件加进仿真工程，本文件设为 top
//
// 【v2 修改记录】
//   1) 修 bug：原来用 wait(Tx_Done===1) 等"发完了"，但 Tx_Done 只宽 1 拍，
//      采样循环走完时它早就过去了 → 仿真死等，永远不出 PASS。
//      改法：用一个触发器 done_seen 把脉冲【记住】，再 wait(done_seen)。
//   2) 加 500us 超时保护：万一又卡住，会直接打印 TIMEOUT 而不是无限等待。
//   3) 加了 8'h3C 这一帧（练习要求的），它首尾两个 0，专抓"起始位/停止位"问题。
//
// 为什么要把参数改小：
//   真实参数下一位 = 5208 拍，发一帧要 5 万多拍，仿真慢、波形也看不全。
//   这里用 CLOCK_FREQ=1000, BAUD=100  →  一位 = 10 拍，一帧 = 100 拍，
//   逻辑完全一样，但一眼就能看完。
//   ★ 这叫"参数化带来的好处"：第 2 讲那位为什么要把 -1 写成参数，就是这个原因。
//=============================================================================
`timescale 1ns/1ns

module uart_tx_tb;

    reg        Clk     = 1'b0;
    reg        Rst_n   = 1'b0;
    reg        Send_Go = 1'b0;
    reg  [7:0] Data    = 8'h00;

    wire Uart_Tx;
    wire Tx_Done;

    integer err_cnt = 0;

    // 50MHz → 20ns 周期（仿真里自己造一个晶振）
    always #10 Clk = ~Clk;

    //------------------------------------------------------------------
    // 例化：故意把参数改小（1000/100 = 一位 10 拍）
    //------------------------------------------------------------------
    uart_tx #(
        .CLOCK_FREQ (1000),
        .BAUD       (100)
    ) u_dut (
        .Clk     (Clk),
        .Rst_n   (Rst_n),
        .Send_Go (Send_Go),
        .Data    (Data),
        .Uart_Tx (Uart_Tx),
        .Tx_Done (Tx_Done)
    );

    // 一位 = 10 拍，这里存着方便改
    localparam CLK_PER_BIT = 10;

    //------------------------------------------------------------------
    // ★ 关键：把"只宽 1 拍"的 Tx_Done 锁存下来
    //
    //   脉冲只存在 20ns，而我们要在几百 ns 之后才回头看它。
    //   如果不锁存，就会像 v1 那样永远等不到。
    //   做法：来一下就置 1，用完由调用方手动清 0。
    //------------------------------------------------------------------
    reg done_seen = 1'b0;

    always @(posedge Clk) begin
        if (Tx_Done)
            done_seen <= 1'b1;
    end

    //------------------------------------------------------------------
    // 超时保护：500us 还没跑完 = 出事了
    //------------------------------------------------------------------
    initial begin
        #500_000;
        $display("===== TIMEOUT : simulation hung (500us) =====");
        $stop;
    end

    //------------------------------------------------------------------
    // 发一个字节，并且在每一位的【中点】采样，逐位比对
    //
    // 为什么要采中点：位的边沿附近信号刚翻转，采到的是"正在变"的值；
    // 采中点最稳。这就是第 5 讲接收端"中点采样"的伏笔。
    //------------------------------------------------------------------
    task send_and_check(input [7:0] d);
        integer   i;
        reg [9:0] got;              // got[0]=起始位, got[1..8]=d[0..7], got[9]=停止位
        reg       ok;
        begin
            done_seen = 1'b0;       // 清掉上一次的"发完了"标记

            @(posedge Clk); #1;
            Data    = d;
            Send_Go = 1'b1;
            @(posedge Clk); #1;
            Send_Go = 1'b0;

            // 等起始位到来
            wait (Uart_Tx === 1'b0);

            // 跳到起始位中点
            repeat (CLK_PER_BIT/2) @(posedge Clk);

            // 每 10 拍采一次，采 10 次
            for (i = 0; i < 10; i = i + 1) begin
                got[i] = Uart_Tx;
                repeat (CLK_PER_BIT) @(posedge Clk);
            end

            // 等这一帧的完成标记（已锁存，不会漏）
            wait (done_seen);
            @(posedge Clk); #1;

            //------------------------------ 判分
            ok = 1'b1;

            if (got[0] !== 1'b0) begin
                err_cnt = err_cnt + 1;
                ok = 1'b0;
                $display("[!] %h : start bit is %b, expected 0", d, got[0]);
            end
            if (got[9] !== 1'b1) begin
                err_cnt = err_cnt + 1;
                ok = 1'b0;
                $display("[!] %h : stop bit is %b, expected 1", d, got[9]);
            end
            if (got[8:1] !== d) begin
                err_cnt = err_cnt + 1;
                ok = 1'b0;
                $display("[!] %h : data bits = %b, expected %b (LSB first!)",
                         d, got[8:1], d);
            end

            $display("  sent %h  ->  start=%b  data=%b  stop=%b  %s",
                     d, got[0], got[8:1], got[9], ok ? "OK" : "FAIL");
        end
    endtask

    //------------------------------------------------------------------
    // 主流程
    //------------------------------------------------------------------
    initial begin
        $display("===== UART TX test start (1 bit = %0d clk) =====", CLK_PER_BIT);

        repeat (5) @(posedge Clk);
        #1 Rst_n = 1'b1;
        repeat (5) @(posedge Clk);

        send_and_check(8'h55);      // 0101_0101  交替，最容易看出方向对不对
        send_and_check(8'hA5);      // 1010_0101  和上一字节互补
        send_and_check(8'h0F);      // 0000_1111  低位全是 1，考 LSB first
        send_and_check(8'h00);      // 全 0
        send_and_check(8'hFF);      // 全 1
        send_and_check(8'h3C);      // 0011_1100  首尾是 0，专抓起始位/停止位

        #200;
        if (err_cnt == 0)
            $display("===== PASS : all bytes sent correctly =====");
        else
            $display("===== FAIL : %0d error(s) =====", err_cnt);

        $stop;
    end

endmodule
