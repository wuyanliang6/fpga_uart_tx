// 串口回环：电脑发什么，板子收下来再发回去
module uart_rx_top #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD       = 9600
)(
    input               Clk,        // Y18
    input               Rst_n,      // B21
    input               Uart_Rx,    // J21
    output              Uart_Tx,    // M15
    output reg  [3:0]   Led
);

    wire [7:0] rx_data;
    wire       rx_done;

    reg  [7:0] tx_data;
    reg        tx_go;
    wire       tx_done;

    uart_rx #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD       (BAUD)
    ) u_uart_rx (
        .Clk        (Clk),
        .Rst_n      (Rst_n),
        .uart_rx    (Uart_Rx),
        .Data       (rx_data),
        .Rx_Done    (rx_done)
    );

    uart_tx #(
        .CLOCK_FREQ (CLOCK_FREQ),
        .BAUD       (BAUD)
    ) u_uart_tx (
        .Clk        (Clk),
        .Rst_n      (Rst_n),
        .Send_Go    (tx_go),
        .Data       (tx_data),
        .Uart_Tx    (Uart_Tx),
        .Tx_Done    (tx_done)
    );

    always @(posedge Clk or negedge Rst_n) begin
        if (!Rst_n) begin
            tx_data <= 8'd0;
            tx_go   <= 1'b0;
            Led     <= 4'd0;
        end
        else begin
            tx_go <= rx_done;          // 转一手，保证是单拍
            if (rx_done) begin
                tx_data <= rx_data;
                Led     <= Led + 1'b1;
            end
        end
    end

endmodule
