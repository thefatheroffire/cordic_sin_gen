// 模块名称: sin_gen
// 设计要求: 利用CORDIC算法产生指定频率正弦波 [cite: 2]
// 接口说明: 100MHz时钟, 16位补码输出 [cite: 6]
module sin_gen (
    input               clk,       // 时钟接口: 100MHz, 占空比50% [cite: 6]
    input               rst_n,     // 复位信号: 低电平有效 [cite: 6]
    input               en,        // 使能信号: 1产生, 0停止 [cite: 6]
    input      [7:0]    freq_word, // 频率控制字 n, 频率 = n/2^8 * 100MHz [cite: 6]
    output reg [15:0]   sin_out    // 输出正弦波: 16bit 补码, 1=0x7FFF, -1=0x8000 [cite: 6]
);

    // --- 1. 相位累加器 (DDS 核心) ---
    // 8位相位累加器，对应题目要求的 n/2^8 频率控制 [cite: 6]
    reg [7:0] phase_acc;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 8'd0;
        end else if (en) begin
            phase_acc <= phase_acc + freq_word;
        end
    end

    // --- 2. CORDIC 31位精度查找表 (索引 0:30) ---
    // 采用 Binary Angular Measurement (BAM) 表示法，32'hFFFF_FFFF 对应 360度
    wire signed [31:0] atan_table [0:30];
    assign atan_table[00] = 32'h20000000; // atan(2^-0) = 45.000 deg
    assign atan_table[01] = 32'h12E4051E; // atan(2^-1) = 26.565 deg
    assign atan_table[02] = 32'h09FB385B; // atan(2^-2) = 14.036 deg
    assign atan_table[03] = 32'h051111D4; // atan(2^-3)
    assign atan_table[04] = 32'h028B0D43; // atan(2^-4)
    assign atan_table[05] = 32'h0145D7E1; // atan(2^-5)
    assign atan_table[06] = 32'h00A2F61E; // atan(2^-6)
    assign atan_table[07] = 32'h00517C55; // atan(2^-7)
    assign atan_table[08] = 32'h0028BE53; // atan(2^-8)
    assign atan_table[09] = 32'h00145F2F; // atan(2^-9)
    assign atan_table[10] = 32'h000A2F98; // atan(2^-10)
    assign atan_table[11] = 32'h000517CC; // atan(2^-11)
    assign atan_table[12] = 32'h00028BE6; // atan(2^-12)
    assign atan_table[13] = 32'h000145F3; // atan(2^-13)
    assign atan_table[14] = 32'h0000A2FA; // atan(2^-14)
    assign atan_table[15] = 32'h0000517D; // atan(2^-15)
    assign atan_table[16] = 32'h000028BE; // atan(2^-16)
    assign atan_table[17] = 32'h0000145F; // atan(2^-17)
    assign atan_table[18] = 32'h00000A30; // atan(2^-18)
    assign atan_table[19] = 32'h00000518; // atan(2^-19)
    assign atan_table[20] = 32'h0000028C; // atan(2^-20)
    assign atan_table[21] = 32'h00000146; // atan(2^-21)
    assign atan_table[22] = 32'h000000A3; // atan(2^-22)
    assign atan_table[23] = 32'h00000051; // atan(2^-23)
    assign atan_table[24] = 32'h00000029; // atan(2^-24)
    assign atan_table[25] = 32'h00000014; // atan(2^-25)
    assign atan_table[26] = 32'h0000000A; // atan(2^-26)
    assign atan_table[27] = 32'h00000005; // atan(2^-27)
    assign atan_table[28] = 32'h00000003; // atan(2^-28)
    assign atan_table[29] = 32'h00000001; // atan(2^-29)
    assign atan_table[30] = 32'h00000000; // atan(2^-30)

    // --- 3. 流水线寄存器定义 ---
    // x, y 采用18位有符号位宽防止增益溢出；z 采用32位精度
    reg signed [17:0] x [0:31];
    reg signed [17:0] y [0:31];
    reg signed [31:0] z [0:31];

    // --- 4. 初始级：象限映射 (Stage 0) ---
    wire [31:0] angle_init = {phase_acc, 24'b0};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x[0] <= 18'd0;
            y[0] <= 18'd0;
            z[0] <= 32'd0;
        end else if (en) begin
            // 初始模长校正：x0 = 0.60725 * 32767 = 19896 (0x4DB8)
            if (angle_init[31:30] == 2'b00 || angle_init[31:30] == 2'b11) begin
                x[0] <= 18'sd19896; 
                y[0] <= 18'sd0;
                z[0] <= angle_init;
            end else if(angle_init == 32'h40000000)begin
                x[0] <= 18'sd19896; 
                y[0] <= 18'sd0;
                z[0] <= angle_init;
            end else begin
                x[0] <= -18'sd19896;
                y[0] <= 18'sd0;
                z[0] <= angle_init - 32'h80000000;
            end
        end
    end

    // --- 5. 流水线迭代逻辑 (31级迭代) ---
    genvar i;
    generate
        for (i = 0; i < 31; i = i + 1) begin : cordic_pipe
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x[i+1] <= 18'd0;
                    y[i+1] <= 18'd0;
                    z[i+1] <= 32'd0;
                end else if (en) begin
                    if (z[i][31] == 1'b0) begin // 目标角在顺时针方向
                        x[i+1] <= x[i] - (y[i] >>> i);
                        y[i+1] <= y[i] + (x[i] >>> i);
                        z[i+1] <= z[i] - atan_table[i];
                    end else begin // 目标角在逆时针方向
                        x[i+1] <= x[i] + (y[i] >>> i);
                        y[i+1] <= y[i] - (x[i] >>> i);
                        z[i+1] <= z[i] + atan_table[i];
                    end
                end
            end
        end
    endgenerate

    // --- 6. 输出赋值 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sin_out <= 16'd0;
        end else if (en) begin
            // 最终输出 y 寄存器的低 16 位即为正弦值补码 [cite: 6]
            sin_out <= y[31][15:0];
        end else begin
            sin_out <= 16'd0;
        end
    end

endmodule
