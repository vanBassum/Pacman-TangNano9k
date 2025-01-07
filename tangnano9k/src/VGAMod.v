module VGAMod
(
    input                   CLK,
    input                   nRST,

    input                   PixelClk,

    output                  LCD_DE,
    output                  LCD_HSYNC,
    output                  LCD_VSYNC,

    output          [4:0]   LCD_B,  // RGB for the pins to display
    output          [5:0]   LCD_G,
    output          [4:0]   LCD_R,

    input [23:0] rgb,                // RGB color from the top level

    output reg      [11:0]  x_pos,   // Output for x position
    output reg      [10:0]   y_pos    // Output for y position
);

    reg         [15:0]  pixel_count;
    reg         [15:0]  line_count;

    reg         [15:0] x;
    reg         [15:0] y;


    localparam      V_BACK_PORCH = 16'd0;
    localparam      V_PULSE      = 16'd5; 
    localparam      HEIGHT_PIXEL = 16'd480;
    localparam      V_FRONT_PORCH= 16'd45;

    localparam      H_BACK_PORCH = 16'd182;
    localparam      H_PULSE      = 16'd1; 
    localparam      WIDTH_PIXEL  = 16'd800; 
    localparam      H_FRONT_PORCH= 16'd210;

    parameter       BAR_COUNT    = 16; // RGB565
    localparam      WIDTH_BAR    = WIDTH_PIXEL / 16;
     
    localparam      PIXELS_FOR_HSYNC =   WIDTH_PIXEL + H_BACK_PORCH + H_FRONT_PORCH;  	
    localparam      LINES_FOR_VSYNC  =   HEIGHT_PIXEL + V_BACK_PORCH + V_FRONT_PORCH;

    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
            line_count   <= 16'b0;    
            pixel_count  <= 16'b0;
        end else if (pixel_count == PIXELS_FOR_HSYNC) begin
            pixel_count  <= 16'b0;
            line_count   <= line_count + 1'b1;
        end else if (line_count == LINES_FOR_VSYNC) begin
            line_count   <= 16'b0;
            pixel_count  <= 16'b0;
        end else begin
            pixel_count  <= pixel_count + 1'b1;
        end
    end

    reg [9:0] data_r;
    reg [9:0] data_g;
    reg [9:0] data_b;

    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
            data_r <= 9'b0;
            data_g <= 9'b0;
            data_b <= 9'b0;
        end
    end

    // HSYNC and VSYNC signals (negative polarity)
    assign LCD_HSYNC = ((pixel_count >= H_PULSE) && (pixel_count <= (PIXELS_FOR_HSYNC - H_FRONT_PORCH))) ? 1'b0 : 1'b1;
    assign LCD_VSYNC = ((line_count >= V_PULSE) && (line_count <= (LINES_FOR_VSYNC - 1))) ? 1'b0 : 1'b1;

    assign LCD_DE = ((pixel_count >= H_BACK_PORCH) &&
                     (pixel_count <= PIXELS_FOR_HSYNC - H_FRONT_PORCH) &&
                     (line_count >= V_BACK_PORCH) &&
                     (line_count <= LINES_FOR_VSYNC - V_FRONT_PORCH - 1)) ? 1'b1 : 1'b0;


    

    // Update x and y positions in a single always block
    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
            x_pos <= 11'b0;
            y_pos <= 10'b0;
        end else begin
            x_pos <= (pixel_count - H_BACK_PORCH);
            y_pos <= (line_count - V_BACK_PORCH) * 2;
        end
    end


    // Assign RGB values to LCD outputs using conditional ternary operator
    assign LCD_R = rgb[23:16] >> 3;  // 8-bit to 5-bit
    assign LCD_G = rgb[15:8]  >> 2; // 8-bit to 6-bit
    assign LCD_B = rgb[7:0]   >> 3;  // 8-bit to 5-bit




endmodule
