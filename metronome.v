module metronome(
    input wire clk,         // FPGA clock, pin 23
    input wire reset_n,     // Active low reset, pin 25
    input wire key_inc_n,   // KEY1, active low, pin 88
    input wire key_dec_n,   // KEY2, active low, pin 89
    output reg beep_n,      // Buzzer, active low, pin 110
    output reg [6:0] seg,   // 7-segment segments (active low)
    output reg [3:0] dig    // Digit selection (active low)
);

    parameter CLK_FREQ = 50000000; // 50 MHz
    parameter MIN_BPM = 40;
    parameter MAX_BPM = 240;

    // BPM and tick
    reg [7:0] bpm = 120;
    reg [31:0] tick_counter = 0;
    reg [31:0] tick_threshold = 0;

    // Buzzer pulse width (~5 ms)
    reg [18:0] buzz_counter = 0;
    reg buzz_active = 0;

    // Button debouncing
    reg [15:0] key_inc_db = 16'hFFFF;
    reg [15:0] key_dec_db = 16'hFFFF;
    
    // Display refresh
    reg [19:0] refresh_counter = 0;
    reg [1:0] digit_sel = 0;
    
    // BCD digits
    reg [3:0] hundreds;
    reg [3:0] tens;
    reg [3:0] ones;
    
    // 7-segment patterns (active low: 0=ON, 1=OFF)
    // Format: g f e d c b a
    parameter SEG_0 = 7'b1000000;
    parameter SEG_1 = 7'b1111001;
    parameter SEG_2 = 7'b0100100;
    parameter SEG_3 = 7'b0110000;
    parameter SEG_4 = 7'b0011001;
    parameter SEG_5 = 7'b0010010;
    parameter SEG_6 = 7'b0000010;
    parameter SEG_7 = 7'b1111000;
    parameter SEG_8 = 7'b0000000;
    parameter SEG_9 = 7'b0010000;
    parameter SEG_BLANK = 7'b1111111;

    // Convert binary to BCD
    always @(*) begin
        hundreds = bpm / 100;
        tens = (bpm % 100) / 10;
        ones = bpm % 10;
    end

    // Display multiplexing
    always @(posedge clk) begin
        if (!reset_n) begin
            refresh_counter <= 0;
            digit_sel <= 0;
            seg <= SEG_BLANK;
            dig <= 4'b1111;
        end else begin
            refresh_counter <= refresh_counter + 1;
            
            // Refresh at ~1kHz (50MHz/50000)
            if (refresh_counter == 50000) begin
                refresh_counter <= 0;
                
                // Turn off current digit
                dig <= 4'b1111;
                
                // Select next digit
                digit_sel <= digit_sel + 1;
                
                case (digit_sel)
                    2'b00: begin // Hundreds digit
                        if (hundreds == 0)
                            seg <= SEG_BLANK; // Blank leading zero
                        else
                            seg <= get_segment_pattern(hundreds);
                        dig <= 4'b1110;
                    end
                    2'b01: begin // Tens digit
                        seg <= get_segment_pattern(tens);
                        dig <= 4'b1101;
                    end
                    2'b10: begin // Ones digit
                        seg <= get_segment_pattern(ones);
                        dig <= 4'b1011;
                    end
                    2'b11: begin // Blank or could show "BPM"
                        seg <= SEG_BLANK;
                        dig <= 4'b0111;
                    end
                endcase
            end
        end
    end
    
    // Function to get segment pattern
    function [6:0] get_segment_pattern;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: get_segment_pattern = SEG_0;
                4'd1: get_segment_pattern = SEG_1;
                4'd2: get_segment_pattern = SEG_2;
                4'd3: get_segment_pattern = SEG_3;
                4'd4: get_segment_pattern = SEG_4;
                4'd5: get_segment_pattern = SEG_5;
                4'd6: get_segment_pattern = SEG_6;
                4'd7: get_segment_pattern = SEG_7;
                4'd8: get_segment_pattern = SEG_8;
                4'd9: get_segment_pattern = SEG_9;
                default: get_segment_pattern = SEG_BLANK;
            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bpm <= 120;
            tick_counter <= 0;
            tick_threshold <= CLK_FREQ * 60 / 120;
            beep_n <= 1;
            buzz_counter <= 0;
            buzz_active <= 0;
            key_inc_db <= 16'hFFFF;
            key_dec_db <= 16'hFFFF;
        end else begin
            // --------------------------
            // Simple debounce for buttons
            // --------------------------
            key_inc_db <= {key_inc_db[14:0], key_inc_n};
            key_dec_db <= {key_dec_db[14:0], key_dec_n};

            // Rising edge detection for increment
            if (key_inc_db == 16'b0000000000000001 && bpm < MAX_BPM) begin
                bpm <= bpm + 1;
            end
            
            // Rising edge detection for decrement
            if (key_dec_db == 16'b0000000000000001 && bpm > MIN_BPM) begin
                bpm <= bpm - 1;
            end

            // --------------------------
            // Update tick threshold
            // --------------------------
            tick_threshold <= CLK_FREQ * 60 / bpm;

            // --------------------------
            // Tick counter
            // --------------------------
            if (tick_counter >= tick_threshold) begin
                tick_counter <= 0;
                buzz_active <= 1;
                buzz_counter <= 0;
            end else begin
                tick_counter <= tick_counter + 1;
            end

            // --------------------------
            // Buzzer pulse generation (~5ms)
            // --------------------------
            if (buzz_active) begin
                if (buzz_counter < 250000) begin  // 50MHz * 5ms = 250k cycles
                    beep_n <= 0;                 // active low
                    buzz_counter <= buzz_counter + 1;
                end else begin
                    beep_n <= 1;
                    buzz_active <= 0;
                end
            end else begin
                beep_n <= 1;
            end
        end
    end

endmodule