module TOP
(
    input			Reset_Button,
    input           User_Button,
    input           XTAL_IN,

    input btn_up,
    input btn_down,
    input btn_left,
    input btn_right,
    input btn_coin,
    input btn_start,

    output  [5:0]   LED,

    output			LCD_CLK,
    output			LCD_HYNC,
    output			LCD_SYNC,
    output			LCD_DEN,
    output	[4:0]	LCD_R,
    output	[5:0]	LCD_G,
    output	[4:0]	LCD_B,

    output          PWM_AUDIO_PIN  // PWM audio output pin
);



// 768x576p@60hz:  174.8 MHz HDMI clock, actual pixel clock = 34.8 MHz
// actual hdmi clock = 174 MHz
// actual pixel clock = 34.8 MHz
// 34800000 / 48000 / 2 - 1 = 361

//`define PLL pll_174m 
`define VIDEO_WIDE 0
`define AUDIO_DIVISOR 9'd346
`define PIXEL_CLOCK  33330000


	wire		CLK_SYS;
	wire		CLK_PIX;
    wire        oscout_o;

    Gowin_rPLL chip_pll
    (
        .clkout(CLK_SYS), //output clkout      //200M
        .clkoutd(CLK_PIX), //output clkoutd   //33.33M
        .clkin(XTAL_IN), //input clkin
        .lock(pll_lock)
    );


	VGAMod	D1
	(
		.CLK		(	CLK_SYS     ),
		.nRST		(	sys_resetn),

		.PixelClk	(	CLK_PIX		),
		.LCD_DE		(	LCD_DEN	 	),
		.LCD_HSYNC	(	LCD_HYNC 	),
    	.LCD_VSYNC	(	LCD_SYNC 	),

		.LCD_B		(	LCD_B		),
		.LCD_G		(	LCD_G		),
		.LCD_R		(	LCD_R		),
        .rgb        (rgb),
        .x_pos  (cx),   
        .y_pos  (cy)  
	);

	assign		LCD_CLK		=	CLK_PIX;

/* -------------------- Timing -------------------- */

assign clk_pixel = CLK_PIX;

wire [7:0] cpu_dout;
wire [15:0] addr;
wire rd_n, wr_n;
wire cpu_en, mem_en;

wire [23:0] rgb;                // rgb color signal
wire [11:0] cx;                 // horizontal pixel counter
wire [10:0] cy;                 // vertical pixel counter


timing timing_i (
    .clk(clk_pixel),
    .reset_n(sys_resetn),
    .cpu_en(cpu_en),
    .mem_en(mem_en)
);
/* -------------------- audio -------------------- */
reg [9:0] audio_out_register;         // Register holding the single Pacman audio channel

// Sigma-Delta Encoder Instance
dsa_single uut (
    .clk(clk_pixel),                   
    .rst_n(sys_resetn),            
    .din(audio_out_register), 
    .dout(PWM_AUDIO_PIN)      
);

/* -------------------- 4 * 4k main CPU ROM -------------------- */

wire [7:0] dout_rom_6e;
pacman_6e pacman_6e_inst (
    .clk(clk_pixel),
	.reset(!sys_resetn),
    .ce(mem_en),
    .oce(1'b1),
    .ad( addr[11:0] ),
    .dout(dout_rom_6e)
);

wire [7:0] dout_rom_6f;
pacman_6f pacman_6f_inst (
    .clk(clk_pixel),
	.reset(!sys_resetn),
    .ce(mem_en),
    .oce(1'b1),
    .ad( addr[11:0] ),
    .dout(dout_rom_6f)
);

wire [7:0] dout_rom_6h;
pacman_6h pacman_6h_inst (
    .clk(clk_pixel),
	.reset(!sys_resetn),
    .ce(mem_en),
    .oce(1'b1),
    .ad( addr[11:0] ),
    .dout(dout_rom_6h)
);

wire [7:0] dout_rom_6j;
pacman_6j pacman_6j_inst (
    .clk(clk_pixel),
	.reset(!sys_resetn),
    .ce(mem_en),
    .oce(1'b1),
    .ad( addr[11:0] ),
    .dout(dout_rom_6j)
);

/* -------------------- buttons and switches -------------------- */

//  credit, coin2, coin1, test_l, p1 down, p1 right, p1 left, p1 up
wire [7:0] buttons_a = { 2'b11, btn_coin, 1'b1, btn_down, btn_right, btn_left, btn_up };
// cocktail/upright, start2, start1, test, p2 down, p2 right, p2 left, p2 up
wire [7:0] buttons_b = { 2'b11, btn_start, 5'b11111 };   // bit 7 = 0: service

// dip switches and buttons
wire [7:0] dout_ports =  
    (addr[11:0] == 12'h000)?buttons_a:
    (addr[11:0] == 12'h040)?buttons_b:
    (addr[11:0] == 12'h080)?8'b11001001:  // DIP switches
    8'hff;
    
wire [7:0] cpu_din = 
    (!m1_n && !iorq_n)?irq_vector:
    (addr[14:12] == 3'h0)?dout_rom_6e:  // roms from 0x1000 ...
    (addr[14:12] == 3'h1)?dout_rom_6f:
    (addr[14:12] == 3'h2)?dout_rom_6h:
    (addr[14:12] == 3'h3)?dout_rom_6j:  // ... to 0x3fff
    (addr[14:12] == 3'h4)?dout_ram:     // ram from 0x4000 to 0x4fff
    (addr[14:12] == 3'h5)?dout_ports:   // ports at 0x5xxx
    8'hff;

/* -------------------- audio -------------------- */

// 32 * 4bit registers
reg [3:0] audio_regs [31:0];

always @(posedge clk_pixel) begin
    if (!sys_resetn) begin   
        // set all three volume registers to 0 to start silent
        audio_regs[5'h15 + 0 * 5] <= 4'd0;
        audio_regs[5'h15 + 1 * 5] <= 4'd0;
        audio_regs[5'h15 + 2 * 5] <= 4'd0;
    end else begin
        // CPU writes one of the 32 4-bit audio registers
        if(mem_en && (wr_n == 1'b0) && (mreq_n == 1'b0) && (addr[14:5] == 10'b101_0000_010))
            audio_regs[addr[4:0]] <= cpu_dout[3:0];
    end
end

// https://www.walkofmind.com/programming/pie/wsg3.htm

// extract audio register values for the current channel
wire [4:0] ch_offset = audio_ch * 5'd5;
wire [3:0] wave   = audio_regs[5'h05 + ch_offset];
wire [3:0] volume = audio_regs[5'h15 + ch_offset];
wire [19:0] freq  = {
    audio_regs[5'h14 + ch_offset],
    audio_regs[5'h13 + ch_offset],
    audio_regs[5'h12 + ch_offset],
    audio_regs[5'h11 + ch_offset],
    (audio_ch == 2'd0)?audio_regs[5'h10]:4'h0 };

// each of the two wave proms contains 8 wave forms with 32 samples each

// the wave table is addressed from 5 bits of the sample counters of the
// three channels and with 3 bits to select one of the eight waves
wire [7:0] wave_addr = { wave[2:0], audio_ch_cnt[audio_ch][17:13] };

// select the wave signal one of the two proms, mke it signed and scale by volume
wire [7:0] dout_wave = volume * ((wave[3]?dout_wave_b:dout_wave_a)-4'd7);

reg audio_rd;

wire [3:0] dout_wave_a;
prom_82s126_1m prom_82s126_1m_inst (
    .clk(clk_pixel),
	.reset(!sys_resetn),
    .ce(audio_rd),
    .oce(1'b1),
    .ad( wave_addr ),
    .dout(dout_wave_a)
);

wire [3:0] dout_wave_b;
prom_82s126_3m prom_82s126_3m_inst (
    .clk(clk_pixel),
	.reset(!sys_resetn),
    .ce(audio_rd),
    .oce(1'b1),
    .ad( wave_addr ),
    .dout(dout_wave_b)
);

reg [9:0] audio_cnt;  // counter to divide system clock down to audio clock
reg [1:0] audio_ch;   // audio channel counter 0, 1 &2

reg [19:0] audio_ch_cnt [2:0];  // 20 bit frequency counter for each channel
reg [9:0] audio_sum;            // register to add the three channels

always @(posedge clk_pixel) begin
    if (!sys_resetn) begin       
        audio_cnt <= 10'd0;
        audio_ch <= 2'd0;
        audio_sum <= 10'd0;
        audio_rd <= 1'b0;
    end else begin
        // audio runs at 24khz and the three channels are processed seperately,
        // so the base audio handling runs at 72kHz

        // trigger rom read half a cycle earlier
        audio_rd <= 1'b0;
        if(audio_cnt == `PIXEL_CLOCK/72000/2)
            audio_rd <= 1'b1;

        if(audio_cnt < `PIXEL_CLOCK/72000)
            audio_cnt <= audio_cnt + 10'd1;
        else begin         
            // 72kHz ...
            audio_cnt <= 10'd0;

            // run a seperate sample counter for each audio channel
            audio_ch_cnt[audio_ch] <= audio_ch_cnt[audio_ch] + freq;           

            // cycle at 24khz through all three channels
            if(audio_ch < 2'd2) begin
                audio_ch <= audio_ch + 2'd1;
    
                audio_sum <= audio_sum + { {2{dout_wave[7]}}, dout_wave };           
            end else begin              
                audio_ch <= 2'd0;
               
                audio_out_register <= audio_sum;
                audio_sum <= { {2{dout_wave[7]}}, dout_wave };
            end
        end
    end
end


assign LED = {volume, 2'b00};

/* -------------------- interrupt handling -------------------- */
wire vbi;
reg int_n, int_en;
wire mreq_n, iorq_n, m1_n;
reg [7:0] irq_vector;

always @(posedge clk_pixel) begin
    if (!sys_resetn) begin
        irq_vector <= 0;
        int_n <= 1'b1;
        int_en <= 0;
    end else begin
        if(mem_en) begin

            // CPU writes
            if((wr_n == 1'b0)) begin
                // cpu writes interrupt vector using OUT
                if((iorq_n == 1'b0) && (m1_n == 1'b1))
                    irq_vector <= cpu_dout; 

                // cpu writes interrupt enable
                if((mreq_n == 1'b0) && (addr[14:0] == 15'h5000))
                    int_en <= cpu_dout[0];
            end

            // interrupt acknowledge
            if(!m1_n && !iorq_n)
                int_n <= 1'b1;
        end

        // latch VBI
        if(vbi)
            int_n <= 1'b0;
    end
end


/* -------------------- Z80 CPU -------------------- */
T80sed t80sed (
    .CLK_n(clk_pixel),   
    .RESET_n(sys_resetn),
	.CLKEN(cpu_en),

	.WAIT_n(1'b1),
	.INT_n(int_n || !int_en),
	.NMI_n(1'b1),
	.BUSRQ_n(1'b1),

	.M1_n(m1_n),
	.MREQ_n(mreq_n),
	.IORQ_n(iorq_n),
	.RD_n(rd_n),
	.WR_n(wr_n),
	.A(addr),
	.DI(cpu_din),
	.DO(cpu_dout)
);

Reset_Sync u_Reset_Sync (
  .resetn(sys_resetn),
  .ext_reset(Reset_Button & pll_lock),
  .clk(clk_pixel)
);

/* -------------------- pacman video (incl. RAM) -------------------- */
wire [7:0] dout_ram;
video #(.VIDEO_WIDE(`VIDEO_WIDE)) video_inst (
	.clk(clk_pixel),
	.resetn(sys_resetn),

    // Z80 CPU interface to video memory
    .mem_en(mem_en && !mreq_n && addr[14:12] == 3'h4 ),          // 4k vram at 0x4xxx
    .mem_spr_en(mem_en && !mreq_n && (addr[14:4] == 11'h506)),   // 16 bytes spriteram at 0x506x
    .mem_addr(addr[11:0]),
    .mem_din(cpu_dout),
    .mem_dout(dout_ram),
    .mem_wr_n(wr_n),

    .vbi(vbi),

    // output rgb data
    .r(rgb[23:16]),
    .g(rgb[15:8]),
    .b(rgb[7:0]),

    // input video counters
    .x(cx),
    .y(cy)
);

endmodule

// timing generator
module timing (
    input clk,
    input reset_n,
    output reg cpu_en,
    output reg mem_en
);
    reg [31:0] clk_cnt = 0;
    wire [31:0] base = `PIXEL_CLOCK / 3000000;

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            clk_cnt <= 16'b0;
            cpu_en <= 1'b0;
            mem_en <= 1'b0;
        end else begin
            cpu_en <= 1'b0;
            mem_en <= 1'b0;
           
            if(clk_cnt == base/2)
                mem_en <= 1'b1;

            if(clk_cnt < base)
                clk_cnt <= clk_cnt + 1;
            else begin 
                clk_cnt <= 16'b0;
                cpu_en <= 1'b1;
            end
        end
    end
endmodule

module Reset_Sync (
 input clk,
 input ext_reset,
 output resetn
);

 reg [15:0] reset_cnt = 0;
 
 always @(posedge clk or negedge ext_reset) begin
     if (~ext_reset)
         reset_cnt <= 16'b0;
     else
         reset_cnt <= reset_cnt + !resetn;
 end
 
 assign resetn = &reset_cnt;

endmodule



module dsa_single #(
	parameter dac_bw = 10
)(

	input	wire				clk,
	input	wire				rst_n,
	input	wire	[9 : 0]	din,
	output	wire				dout
);
	
	localparam bw_ext = 2;
	localparam bw_tot = dac_bw + bw_ext;
	
	reg						dout_r;
	reg						dac_dout;
	
	reg signed		[bw_tot-1 : 0]	DAC_acc_1st;
	
	wire signed		[bw_tot-1 : 0]	max_val = (2**(dac_bw - 1) - 1);
	wire signed		[bw_tot-1 : 0]	min_val = -(2**(dac_bw - 1));
	wire signed		[bw_tot-1 : 0]	dac_val = (!dout_r) ? max_val : min_val;
	
	wire signed		[bw_tot-1 : 0]	in_ext = {{bw_ext{din[dac_bw - 1]}}, din};
	wire signed		[bw_tot-1 : 0]	delta_s0_c0 = in_ext + dac_val;
	wire signed		[bw_tot-1 : 0]	delta_s0_c1 = DAC_acc_1st + delta_s0_c0;

	always@(posedge clk)begin
		if(!rst_n)begin
			DAC_acc_1st <= 'd0;
		end else begin
			DAC_acc_1st <= delta_s0_c1;
		end
	end
	
	always@(posedge clk)begin
		if(!rst_n)begin
			dout_r		<= 1'b0;
			dac_dout	<= 1'b0;
		end else begin
			dout_r		<= delta_s0_c1[bw_tot-1];
			dac_dout	<= ~dout_r;
		end
	end
	
	assign dout = dout_r;
	
endmodule

















module SigmaDeltaEncoder (
    input wire clk,                    // Clock signal
    input wire reset,                  // Reset signal
    input wire [9:0] input_val,        // 10-bit input value
    output reg output_bit              // Single-bit output
);

    // Internal registers
    reg [10:0] integrator;             // Accumulator (11 bits to handle overflow)
    reg [10:0] feedback;               // Feedback value

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integrator <= 11'b0;
            feedback   <= 11'b0;
            output_bit <= 1'b0;
        end else begin
            // Update the integrator with input minus feedback
            integrator <= integrator + input_val - feedback;

            // Determine the output bit
            if (integrator >= 11'd512) begin
                output_bit <= 1'b1;
                feedback <= 11'd1023;  // Max value for 10-bit input
            end else begin
                output_bit <= 1'b0;
                feedback <= 11'd0;
            end
        end
    end

endmodule
