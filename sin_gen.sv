module sin_gen (
    input               clk,       // 100MHz
    input               rst_n,     // 低电平有效
    input               en,        // 使能
    input      [7:0]    freq_word, // 频率控制字
    output reg [15:0]   sin_out    // 16bit 补码
);

    // --- 1. 相位累加器 ---
    reg [7:0] phase_acc;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) phase_acc <= 8'd0;
        else if (en) phase_acc <= phase_acc + freq_word;
    end

    // --- 2. 31级 atan 查找表 (BAM格式) ---
    wire signed [31:0] atan_table [0:30];
    assign atan_table[00] = 32'h20000000; assign atan_table[01] = 32'h12E4051E;
    assign atan_table[02] = 32'h09FB385B; assign atan_table[03] = 32'h051111D4;
    assign atan_table[04] = 32'h028B0D43; assign atan_table[05] = 32'h0145D7E1;
    assign atan_table[06] = 32'h00A2F61E; assign atan_table[07] = 32'h00517C55;
    assign atan_table[08] = 32'h0028BE53; assign atan_table[09] = 32'h00145F2F;
    assign atan_table[10] = 32'h000A2F98; assign atan_table[11] = 32'h000517CC;
    assign atan_table[12] = 32'h00028BE6; assign atan_table[13] = 32'h000145F3;
    assign atan_table[14] = 32'h0000A2FA; assign atan_table[15] = 32'h0000517D;
    assign atan_table[16] = 32'h000028BE; assign atan_table[17] = 32'h0000145F;
    assign atan_table[18] = 32'h00000A30; assign atan_table[19] = 32'h00000518;
    assign atan_table[20] = 32'h0000028C; assign atan_table[21] = 32'h00000146;
    assign atan_table[22] = 32'h000000A3; assign atan_table[23] = 32'h00000051;
    assign atan_table[24] = 32'h00000029; assign atan_table[25] = 32'h00000014;
    assign atan_table[26] = 32'h0000000A; assign atan_table[27] = 32'h00000005;
    assign atan_table[28] = 32'h00000003; assign atan_table[29] = 32'h00000001;
    assign atan_table[30] = 32'h00000000;

    // --- 3. 流水线定义 ---
    reg signed [17:0] x [0:31];
    reg signed [17:0] y [0:31];
    reg signed [31:0] z [0:31];
    reg [1:0] quad_pipe [0:31]; // 必须覆盖31级延迟

    // --- 4. 初始级 (Stage 0): 象限映射 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x[0] <= 18'd0; y[0] <= 18'd0; z[0] <= 32'd0; quad_pipe[0] <= 2'b00;
        end else if (en) begin
            quad_pipe[0] <= phase_acc[7:6];
            x[0] <= 18'sd19896; // 0.60725 * 32767
            y[0] <= 18'sd0;
            case(phase_acc[7:6])
                2'b00, 2'b11: z[0] <= {phase_acc, 24'b0};
                2'b01:        z[0] <= {phase_acc, 24'b0} - 32'h4000_0000; // -90度
                2'b10:        z[0] <= {phase_acc, 24'b0} + 32'h4000_0000; // +90度
            endcase
        end
    end

    // --- 5. 31级迭代逻辑 ---
    genvar i;
    generate
        for (i = 0; i < 31; i = i + 1) begin : cordic_steps
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x[i+1] <= 18'd0; y[i+1] <= 18'd0; z[i+1] <= 32'd0;
                    quad_pipe[i+1] <= 2'b00;
                end else if (en) begin
                    quad_pipe[i+1] <= quad_pipe[i]; // 严格同步
                    if (z[i][31] == 1'b0) begin
                        x[i+1] <= x[i] - (y[i] >>> i);
                        y[i+1] <= y[i] + (x[i] >>> i);
                        z[i+1] <= z[i] - atan_table[i];
                    end else begin
                        x[i+1] <= x[i] + (y[i] >>> i);
                        y[i+1] <= y[i] - (x[i] >>> i);
                        z[i+1] <= z[i] + atan_table[i];
                    end
                end
            end
        end
    endgenerate

    // --- 6. 输出级 (Stage 31) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sin_out <= 16'd0;
        else if (en) begin
            case(quad_pipe[31])
                2'b00, 2'b11: sin_out <= y[31][15:0];   // sin(theta) = y
                2'b01:        sin_out <= x[31][15:0];   // sin(theta) = cos(theta-90)
                2'b10:        sin_out <= -x[31][15:0];  // sin(theta) = -cos(theta+90)
                default:      sin_out <= 16'd0;
            endcase
        end
    end
endmodule
