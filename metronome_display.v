// Full-Featured Metronome with Display
// Modified interface: KEY3 cycles through modes, KEY4 toggles options
module metronome_display(
    input wire clk,           // FPGA clock, pin 23
    input wire reset_n,       // Active low reset, pin 25
    input wire key_inc_n,     // KEY1, increase BPM, pin 88
    input wire key_dec_n,     // KEY2, decrease BPM, pin 89
    input wire key_mode_n,    // KEY3, cycle mode, pin 90
    input wire key_opt_n,     // KEY4, toggle option, pin 91
    output wire beep_n,       // Buzzer, active low, pin 110
    output wire [3:0] led_n,  // LEDs, active low, pins 87-84
    output wire [3:0] dig,    // Digit select (active low)
    output wire [7:0] seg     // Segments (active low)
);

    // BPM value from metronome
    wire [8:0] bpm;
    wire [1:0] beat_position;
    wire running;
    wire [1:0] time_sig;
    wire accent_enable;
    wire visual_only;
    wire [1:0] current_mode;
    wire show_mode;
    
    // Instantiate metronome module
    metronome metro (
        .clk(clk),
        .reset_n(reset_n),
        .key_inc_n(key_inc_n),
        .key_dec_n(key_dec_n),
        .key_mode_n(key_mode_n),
        .key_opt_n(key_opt_n),
        .beep_n(beep_n),
        .bpm_out(bpm),
        .beat_pos(beat_position),
        .running_out(running),
        .time_sig_out(time_sig),
        .accent_out(accent_enable),
        .visual_out(visual_only),
        .mode_out(current_mode),
        .show_mode_out(show_mode)
    );
    
    // LED beat indicator (active low) - only when running
    assign led_n[0] = ~(running && beat_position == 2'd0);
    assign led_n[1] = ~(running && beat_position == 2'd1);
    assign led_n[2] = ~(running && beat_position == 2'd2);
    assign led_n[3] = ~(running && beat_position == 2'd3);
    
    // Display value selection: show mode or BPM
    wire [8:0] display_val;
    assign display_val = show_mode ? {7'd0, current_mode} : bpm;
    
    // Instantiate 7-segment display module
    seg7_display display (
        .clk(clk),
        .rst_n(reset_n),
        .display_value(display_val),
        .show_mode(show_mode),
        .mode_value(current_mode),
        .time_sig(time_sig),
        .accent(accent_enable),
        .visual(visual_only),
        .dig(dig),
        .seg(seg)
    );

endmodule

// Enhanced Metronome Module
// KEY3 cycles: RUN -> TIME_SIG -> ACCENT -> VISUAL -> RUN
// KEY4 in each mode: START/STOP, select 2/3/4/6, ON/OFF, ON/OFF
module metronome(
    input wire clk,
    input wire reset_n,
    input wire key_inc_n,
    input wire key_dec_n,
    input wire key_mode_n,
    input wire key_opt_n,
    output reg beep_n,
    output wire [8:0] bpm_out,
    output reg [1:0] beat_pos,
    output wire running_out,
    output wire [1:0] time_sig_out,
    output wire accent_out,
    output wire visual_out,
    output wire [1:0] mode_out,
    output wire show_mode_out
);
    parameter CLK_FREQ = 50000000;
    parameter MIN_BPM = 30;
    parameter MAX_BPM = 300;
    
    // Operating modes
    localparam MODE_RUN = 2'd0;
    localparam MODE_TIME_SIG = 2'd1;
    localparam MODE_ACCENT = 2'd2;
    localparam MODE_VISUAL = 2'd3;
    
    reg [1:0] current_mode = MODE_RUN;
    
    // BPM and running state
    reg [8:0] bpm = 9'd120;
    reg running = 1'b1;
    
    // Settings
    reg [1:0] time_sig_sel = 2'b10;  // Default 4/4
    reg accent_enable = 1'b1;
    reg visual_only = 1'b0;
    
    // Export values
    assign bpm_out = bpm;
    assign running_out = running;
    assign time_sig_out = time_sig_sel;
    assign accent_out = accent_enable;
    assign visual_out = visual_only;
    assign mode_out = current_mode;
    
    // Mode display timer (show mode for 2 seconds after changing)
    reg [26:0] mode_timer = 0;
    reg show_mode = 0;
    assign show_mode_out = show_mode;
    
    // Timing
    reg [31:0] tick_counter = 0;
    reg [31:0] tick_threshold = 0;
    
    // Time signature beats per measure
    reg [2:0] beats_per_measure;
    always @(*) begin
        case (time_sig_sel)
            2'b00: beats_per_measure = 3'd2;  // 2/4
            2'b01: beats_per_measure = 3'd3;  // 3/4
            2'b10: beats_per_measure = 3'd4;  // 4/4
            2'b11: beats_per_measure = 3'd6;  // 6/8
        endcase
    end
    
    // Beat counter
    reg [2:0] beat_count = 0;
    
    // Buzzer control
    reg [19:0] buzz_counter = 0;
    reg buzz_active = 0;
    reg accent_beat = 0;
    
    // Button debouncing (20 bits for better debouncing)
    reg [19:0] key_inc_db = 20'hFFFFF;
    reg [19:0] key_dec_db = 20'hFFFFF;
    reg [19:0] key_mode_db = 20'hFFFFF;
    reg [19:0] key_opt_db = 20'hFFFFF;
    
    // Edge detection
    reg key_mode_prev = 1;
    reg key_opt_prev = 1;
    wire key_mode_edge = key_mode_prev && !(|key_mode_db[19:10]);
    wire key_opt_edge = key_opt_prev && !(|key_opt_db[19:10]);
    
    // Fast increment for BPM buttons
    reg [23:0] fast_inc_counter = 0;
    reg fast_mode = 0;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bpm <= 9'd120;
            running <= 1'b1;
            current_mode <= MODE_RUN;
            time_sig_sel <= 2'b10;
            accent_enable <= 1'b1;
            visual_only <= 1'b0;
            tick_counter <= 0;
            tick_threshold <= CLK_FREQ * 60 / 120;
            beep_n <= 1;
            buzz_counter <= 0;
            buzz_active <= 0;
            beat_count <= 0;
            beat_pos <= 0;
            key_inc_db <= 20'hFFFFF;
            key_dec_db <= 20'hFFFFF;
            key_mode_db <= 20'hFFFFF;
            key_opt_db <= 20'hFFFFF;
            key_mode_prev <= 1;
            key_opt_prev <= 1;
            fast_mode <= 0;
            fast_inc_counter <= 0;
        end else begin
            // --------------------------
            // Button debouncing
            // --------------------------
            key_inc_db <= {key_inc_db[18:0], key_inc_n};
            key_dec_db <= {key_dec_db[18:0], key_dec_n};
            key_mode_db <= {key_mode_db[18:0], key_mode_n};
            key_opt_db <= {key_opt_db[18:0], key_opt_n};
            
            key_mode_prev <= |key_mode_db[19:10];
            key_opt_prev <= |key_opt_db[19:10];
            
            // --------------------------
            // Mode cycling (KEY3)
            // --------------------------
            if (key_mode_edge) begin
                if (current_mode == MODE_VISUAL)
                    current_mode <= MODE_RUN;
                else
                    current_mode <= current_mode + 1'b1;
                // Show mode for 2 seconds (100M cycles)
                show_mode <= 1'b1;
                mode_timer <= 27'd100000000;
            end
            
            // Mode display timer countdown
            if (show_mode) begin
                if (mode_timer > 0)
                    mode_timer <= mode_timer - 1'b1;
                else
                    show_mode <= 1'b0;
            end
            
            // --------------------------
            // Option toggle (KEY4) - function depends on mode
            // --------------------------
            if (key_opt_edge) begin
                case (current_mode)
                    MODE_RUN: begin
                        running <= ~running;
                        if (~running) begin
                            beat_count <= 0;
                            beat_pos <= 0;
                            tick_counter <= 0;
                        end
                    end
                    MODE_TIME_SIG: begin
                        time_sig_sel <= time_sig_sel + 1'b1;
                    end
                    MODE_ACCENT: begin
                        accent_enable <= ~accent_enable;
                    end
                    MODE_VISUAL: begin
                        visual_only <= ~visual_only;
                    end
                endcase
            end
            
            // --------------------------
            // BPM adjustment with fast increment
            // --------------------------
            if (&key_inc_db == 0 || &key_dec_db == 0) begin
                fast_inc_counter <= fast_inc_counter + 1'b1;
                if (fast_inc_counter > 32'd1000000000) // Hold for 5s
                    fast_mode <= 1;
            end else begin
                fast_inc_counter <= 0;
                fast_mode <= 0;
            end
            
            if (&key_inc_db == 0 && bpm < MAX_BPM) begin
                if (fast_inc_counter == 0 || (fast_mode && (tick_counter[16:0] == 0)))
                    bpm <= (bpm < MAX_BPM - 5 && fast_mode) ? bpm + 5 : bpm + 1'b1;
            end
            
            if (&key_dec_db == 0 && bpm > MIN_BPM) begin
                if (fast_inc_counter == 0 || (fast_mode && (tick_counter[16:0] == 0)))
                    bpm <= (bpm > MIN_BPM + 5 && fast_mode) ? bpm - 5 : bpm - 1'b1;
            end
            
            // --------------------------
            // Update tick threshold
            // --------------------------
            tick_threshold <= CLK_FREQ * 60 / bpm;
            
            // --------------------------
            // Tick counter (only when running)
            // --------------------------
            if (running) begin
                if (tick_counter >= tick_threshold) begin
                    tick_counter <= 0;
                    buzz_active <= 1;
                    buzz_counter <= 0;
                    
                    // Beat accent on first beat
                    accent_beat <= (beat_count == 0) && accent_enable;
                    
                    // Update beat counter
                    beat_pos <= beat_count[1:0];
                    if (beat_count >= beats_per_measure - 1)
                        beat_count <= 0;
                    else
                        beat_count <= beat_count + 1'b1;
                end else begin
                    tick_counter <= tick_counter + 1'b1;
                end
            end
            
            // --------------------------
            // Buzzer pulse generation
            // --------------------------
            if (buzz_active) begin
                // Accent beat: 10ms, normal beat: 5ms
                reg [19:0] pulse_length;
                pulse_length = accent_beat ? 20'd500000 : 20'd250000;
                
                if (buzz_counter < pulse_length) begin
                    beep_n <= visual_only ? 1'b1 : 1'b0;  // Mute if visual only
                    buzz_counter <= buzz_counter + 1'b1;
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

// 7-segment display module with mode display
module seg7_display (
    input wire clk,
    input wire rst_n,
    input wire [8:0] display_value,  // BPM value to display (0-511)
    input wire show_mode,            // Show mode instead of BPM
    input wire [1:0] mode_value,     // Current mode
    input wire [1:0] time_sig,       // Time signature setting
    input wire accent,               // Accent enable
    input wire visual,               // Visual only mode
    output reg [3:0] dig,
    output reg [7:0] seg
);
    
    // Mode display codes:
    // MODE_RUN (0): "run " or "Stop"
    // MODE_TIME_SIG (1): "2", "3", "4", or "6" (based on time_sig)
    // MODE_ACCENT (2): "Ac on" or "Ac oF"
    // MODE_VISUAL (3): "ui on" or "ui oF"
    
    // Digit separation for BPM
    wire [3:0] digit0, digit1, digit2, digit3;
    assign digit0 = display_value % 10;           // Ones
    assign digit1 = (display_value / 10) % 10;    // Tens
    assign digit2 = (display_value / 100) % 10;   // Hundreds
    assign digit3 = 4'd0;                         // Always 0
    
    // Multiplexing counter
    reg [15:0] refresh_counter;
    reg [1:0] digit_select;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 0;
            digit_select <= 0;
        end else begin
            refresh_counter <= refresh_counter + 1'b1;
            if (refresh_counter == 0) begin
                digit_select <= digit_select + 1'b1;
            end
        end
    end
    
    // Current digit value
    reg [3:0] current_digit;
    reg [7:0] mode_seg;
    
    // Select which digit/mode to display
    always @(*) begin
        if (show_mode) begin
            // Display mode information
            case (mode_value)
                2'd0: begin // RUN mode - show "P" for Play or "S" for Stop
                    case (digit_select)
                        2'b00: dig = 4'b1110; // Blank
                        2'b01: dig = 4'b1101; // Blank
                        2'b10: dig = 4'b1011; // Blank
                        2'b11: dig = 4'b0111; // Letter
                    endcase
                    current_digit = 4'd10; // Will show blank
                    // Show P or S on rightmost digit
                    if (digit_select == 2'b11)
                        mode_seg = 8'b10001100; // "P" 
                    else
                        mode_seg = 8'b11111111;
                end
                2'd1: begin // TIME_SIG mode - show time signature number
                    case (digit_select)
                        2'b00: dig = 4'b1110; // Blank
                        2'b01: dig = 4'b1101; // Blank
                        2'b10: dig = 4'b1011; // Blank
                        2'b11: dig = 4'b0111; // Number
                    endcase
                    if (digit_select == 2'b11) begin
                        case (time_sig)
                            2'b00: current_digit = 4'd2; // 2/4
                            2'b01: current_digit = 4'd3; // 3/4
                            2'b10: current_digit = 4'd4; // 4/4
                            2'b11: current_digit = 4'd6; // 6/8
                        endcase
                    end else begin
                        current_digit = 4'd10; // Blank
                    end
                    mode_seg = 8'b11111111;
                end
                2'd2: begin // ACCENT mode - show "A" and "on"/"oF"
                    case (digit_select)
                        2'b00: dig = 4'b1110; // "n" or "F"
                        2'b01: dig = 4'b1101; // "o"
                        2'b10: dig = 4'b1011; // Blank
                        2'b11: dig = 4'b0111; // "A"
                    endcase
                    current_digit = 4'd10;
                    case (digit_select)
                        2'b11: mode_seg = 8'b10001000; // "A"
                        2'b10: mode_seg = 8'b11111111; // Blank
                        2'b01: mode_seg = 8'b11000000; // "o"
                        2'b00: mode_seg = accent ? 8'b11001000 : 8'b10001110; // "n" or "F"
                    endcase
                end
                2'd3: begin // VISUAL mode - show "u" and "on"/"oF"
                    case (digit_select)
                        2'b00: dig = 4'b1110; // "n" or "F"
                        2'b01: dig = 4'b1101; // "o"
                        2'b10: dig = 4'b1011; // Blank
                        2'b11: dig = 4'b0111; // "U"
                    endcase
                    current_digit = 4'd10;
                    case (digit_select)
                        2'b11: mode_seg = 8'b11000001; // "U"
                        2'b10: mode_seg = 8'b11111111; // Blank
                        2'b01: mode_seg = 8'b11000000; // "o"
                        2'b00: mode_seg = visual ? 8'b11001000 : 8'b10001110; // "n" or "F"
                    endcase
                end
            endcase
        end else begin
            // Display BPM normally
            case (digit_select)
                2'b00: begin
                    dig = 4'b1110;
                    current_digit = digit0;
                end
                2'b01: begin
                    dig = 4'b1101;
                    current_digit = digit1;
                end
                2'b10: begin
                    dig = 4'b1011;
                    current_digit = digit2;
                end
                2'b11: begin
                    dig = 4'b0111;
                    current_digit = digit3;
                end
            endcase
            mode_seg = 8'b11111111;
        end
    end
    
    // 7-segment decoder (active low)
    always @(*) begin
        if (show_mode && mode_seg != 8'b11111111) begin
            seg = mode_seg;
        end else begin
            case (current_digit)
                4'd0: seg = 8'b11000000;
                4'd1: seg = 8'b11111001;
                4'd2: seg = 8'b10100100;
                4'd3: seg = 8'b10110000;
                4'd4: seg = 8'b10011001;
                4'd5: seg = 8'b10010010;
                4'd6: seg = 8'b10000010;
                4'd7: seg = 8'b11111000;
                4'd8: seg = 8'b10000000;
                4'd9: seg = 8'b10010000;
                default: seg = 8'b11111111; // Blank
            endcase
        end
    end

endmodule